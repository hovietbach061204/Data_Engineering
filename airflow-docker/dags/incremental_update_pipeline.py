"""
Incremental Data Warehouse Update Pipeline
==========================================
- Watermark-based change detection from MSSQL
- Parallel per-dimension processing
- Conditional staging (only when changes exist)
- SCD2 merge into PostgreSQL DWH
- Atomic watermark updates post-merge
"""
from __future__ import annotations
import logging
from datetime import datetime, timedelta
from typing import Dict, List
import pandas as pd
from jinja2 import Template
from airflow.decorators import dag, task, task_group
from airflow.operators.empty import EmptyOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.operators.python import PythonOperator
from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.models.baseoperator import chain
from pathlib import Path

# ── Config import ─────────────────────────────────────────────────────────────
from config.incremental_config import (
    MSSQL_CONN_ID,
    PG_CONN_ID,
    STAGING_SCHEMA,
    DWH_SCHEMA,
    CONFIG,
    DIM_TABLES,
    FACT_TABLES,  # kept for parity with original file (facts section still commented)
)

logger = logging.getLogger(__name__)

# ── DAG defaults ──────────────────────────────────────────────────────────────
DEFAULT_ARGS = {
    "owner": "data_engineering",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    # "retries": 2,
    # "retry_delay": timedelta(minutes=5),
}

# ── Utilities ─────────────────────────────────────────────────────────────────

class WatermarkManager:
    """Manage watermarks via PostgreSQL metadata functions."""
    def __init__(self, postgres_conn_id: str = PG_CONN_ID):
        self.pg = PostgresHook(postgres_conn_id=postgres_conn_id)

    def get_watermarks(self, table_names: List[str]) -> Dict[str, str]:
        out: Dict[str, str] = {}
        for t in table_names:
            try:
                row = self.pg.get_first("SELECT metadata.get_watermark(%s)", parameters=[t])
                out[t] = row[0] if row else "1900-01-01 00:00:00"
            except Exception as e:
                logger.warning("Failed to get watermark for %s; defaulting. %s", t, e)
                out[t] = "1900-01-01 00:00:00"
        return out

    def update_watermarks(self, table_names: List[str], new_wm: str) -> None:
        for t in table_names:
            self.pg.run(
                "SELECT metadata.update_watermark(%s, %s::timestamp)",
                parameters=[t, new_wm],
            )
            logger.info("✓ Updated watermark for %s → %s", t, new_wm)


class PostgresBulkLoader:
    """Fast COPY-based loading to PostgreSQL staging tables, with SK cleanup and dtype coercion."""
    SURROGATE_KEYS = {
        "DimCustomer":    "CustomerKey",
        "DimProduct":     "ProductKey",
        "DimPromotion":   "PromotionKey",
        "DimSalesReason": "SalesReasonKey",
        "DimShipMethod":  "ShipMethodKey",
        "DimStore":       "StoreKey",
        "DimTerritory":   "TerritoryKey",
    }

    def __init__(self, postgres_conn_id: str = PG_CONN_ID):
        self.pg = PostgresHook(postgres_conn_id=postgres_conn_id)

    # ---------- helpers ----------
    def _drop_surrogate_key_if_exists(self, schema: str, table: str) -> None:
        """Drop the surrogate key column in staging if it exists (no-op if not)."""
        sk_col = self.SURROGATE_KEYS.get(table)
        if sk_col:
            self.pg.run(f'ALTER TABLE {schema}."{table}" DROP COLUMN IF EXISTS "{sk_col}";')

    def _get_target_types(self, schema: str, table: str) -> dict[str, str]:
        rows = self.pg.get_records(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            """,
            parameters=[schema, table],
        )
        return {name: dtype.lower() for name, dtype in rows}

    # ---------- main APIs ----------
    def truncate(self, schema: str, table: str) -> None:
        # Ensure staging table has no SK column that would collide with COPY, then truncate
        self._drop_surrogate_key_if_exists(schema, table)
        self.pg.run(f'TRUNCATE TABLE {schema}."{table}";')
        logger.info("✓ Truncated %s.%s", schema, table)

    def copy_from_df(self, df: pd.DataFrame, schema: str, table: str) -> None:
        if df.empty:
            logger.warning("DataFrame for %s.%s is empty; skipping load.", schema, table)
            return

        # Work on a copy, keep original DF column case, and prepare a case-insensitive index
        df_local = df.copy()
        df_local.columns = [str(c).strip().strip('"') for c in df_local.columns]
        df_lower_index = {c.lower(): c for c in df_local.columns}

        # Physical target column order (original case)
        cols = self.pg.get_records(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
            """,
            parameters=[schema, table],
        )
        table_cols = [c[0] for c in cols]

        # Intersection (ordered like the table)
        load_cols = [c for c in table_cols if c.lower() in df_lower_index]
        if not load_cols:
            raise ValueError(f"No overlapping columns between DataFrame and {schema}.{table}")

        # Reorder DF to table order using original DF column names
        ordered_df = df_local[[df_lower_index[c.lower()] for c in load_cols]]

        # ---- dtype coercion to avoid "2.0" → integer / bad timestamp etc. ----
        target_types = self._get_target_types(schema, table)
        for col in load_cols:
            tgt = target_types.get(col, "")
            s = ordered_df[col]

            if tgt in ("integer", "smallint", "bigint"):
                # 2.0 -> 2, preserve NULLs (Pandas nullable int)
                ordered_df[col] = (
                    pd.to_numeric(s, errors="coerce")
                      .round()
                      .astype("Int64")
                )
            elif tgt in ("double precision", "real", "numeric", "decimal"):
                ordered_df[col] = pd.to_numeric(s, errors="coerce")
            elif tgt == "boolean":
                ordered_df[col] = (
                    s.map({"t": True, "f": False, "true": True, "false": False, True: True, False: False})
                     .astype("boolean")
                )
            # text/char types can remain as-is

        # Stream as CSV with a NULL marker; COPY with explicit column list (original case)
        from io import StringIO
        buf = StringIO()
        ordered_df.to_csv(buf, index=False, header=True, na_rep='\\N')
        buf.seek(0)

        col_list = ", ".join(f'"{c}"' for c in load_cols)
        copy_sql = (
            f'COPY {schema}."{table}" ({col_list}) '
            f"FROM STDIN WITH (FORMAT CSV, HEADER TRUE, NULL '\\N')"
        )

        conn = self.pg.get_conn()
        cur = conn.cursor()
        try:
            cur.copy_expert(copy_sql, buf)
            conn.commit()
            logger.info("✓ Loaded %d rows into %s.%s", len(ordered_df), schema, table)
        except Exception as e:
            conn.rollback()
            logger.error("✗ COPY into %s.%s failed: %s", schema, table, e)
            raise
        finally:
            cur.close()

# ── TaskFlow primitives (reused per table) ────────────────────────────────────

@task
def check_updates_and_stage(table_name: str) -> str:
    """
    1) Read watermarks (PG) → 2) query MSSQL for changes → 3) stage to PG if any.
    Returns:
      'skip' or 'proceed|<new_watermark>'
    """
    cfg = CONFIG[table_name]
    wm_mgr = WatermarkManager()
    wms = wm_mgr.get_watermarks(cfg.sources)

    logger.info("=== %s: current watermarks ===", table_name)
    for src, wm in wms.items():
        logger.info("  • %s → %s", src, wm)

    # Render source SQL with watermarks
    with open(str(cfg.check_sql), "r") as f:
        sql_tmpl = f.read()
    sql = Template(sql_tmpl).render(watermark_dict=wms)

    # Pull changed rows from MSSQL
    mssql = MsSqlHook(mssql_conn_id=MSSQL_CONN_ID)
    df = mssql.get_pandas_df(sql)
    if df.empty:
        logger.info("✓ %s: no changes detected, skipping.", table_name)
        return "skip"

    logger.info("✓ %s: %d changed/new rows.", table_name, len(df))
    logger.info("df: %s", df.columns)
    logger.info("df head: %s", df.head())

    # Stage into PostgreSQL
    loader = PostgresBulkLoader()
    loader.truncate(STAGING_SCHEMA, table_name)
    loader.copy_from_df(df, STAGING_SCHEMA, table_name)
    logger.info("✓ %s: staged to %s.%s", table_name, STAGING_SCHEMA, table_name)

    # Compute new watermark
    wm_col = cfg.watermark_column
    if wm_col in df.columns:
        new_wm = df[wm_col].max()
        logger.info("New watermark: %s", new_wm)
        if pd.notna(new_wm):
            # normalize to 'YYYY-MM-DD HH:MM:SS' (no 'T', no micros)
            if isinstance(new_wm, pd.Timestamp):
                new_wm = new_wm.to_pydatetime()
            new_wm_str = new_wm.strftime('%Y-%m-%d %H:%M:%S')
            return f"proceed|{new_wm_str}"

    logger.info("wm_col: %s", wm_col)
    logger.warning("%s: unable to compute new watermark; proceeding without value.", table_name)
    return "proceed"

@task.branch
def decide_merge(check_result: str, table_name: str) -> str:
    """Branch to merge or skip for this table."""
    return (
        f"{table_name}__skip"
        if check_result.startswith("skip")
        else f"{table_name}__merge"
    )

@task
def run_merge(table: str):
    sql_text = Path(str(CONFIG[table].merge_sql)).read_text()
    rendered = Template(sql_text).render(
        DWH_SCHEMA=DWH_SCHEMA,
        STAGING_SCHEMA=STAGING_SCHEMA,
    )
    PostgresHook(postgres_conn_id=PG_CONN_ID).run(rendered, autocommit=True)

def update_watermarks_after_merge_py(table_name: str, check_result: str) -> None:
    if not (isinstance(check_result, str) and check_result.startswith("proceed|")):
        logger.info("%s: no watermark update (check_result=%r).", table_name, check_result)
        return

    _, raw_wm = check_result.split("|", 1)

    # Normalize: strip, replace 'T' with space, drop micros if present
    wm_clean = raw_wm.strip().replace("T", " ")
    if "." in wm_clean:
        wm_clean = wm_clean.split(".", 1)[0]  # 'YYYY-MM-DD HH:MM:SS'

    sources = CONFIG[table_name].sources
    logger.info("%s: updating %d watermarks → %s", table_name, len(sources), wm_clean)

    wm_mgr = WatermarkManager()
    for src in sources:
        try:
            wm_mgr.update_watermarks([src], wm_clean)
            logger.info("✓ %s watermark → %s", src, wm_clean)
        except Exception as e:
            logger.error("✗ Failed to update watermark for %s: %s", src, e)
            raise

@dag(
    dag_id='incremental_update_pipeline',
    default_args=DEFAULT_ARGS,
    description='Incremental updates for all dimension and fact tables with parallel processing',
    schedule='@daily',
    start_date=datetime(2025, 10, 1),
    catchup=False,
    tags=['dwh', 'incremental', 'scd2'],
    max_active_runs=1,
    template_searchpath=["/opt/airflow/dags/sql/postgres"]
)
def incremental_update_pipeline():

    start = EmptyOperator(task_id='start')
    dimensions_complete = EmptyOperator(
        task_id='dimensions_complete',
        trigger_rule='none_failed_min_one_success'
    )
    end = EmptyOperator(task_id='end', trigger_rule='none_failed_min_one_success')

    # -------- Visible, un-grouped per-dimension wiring --------
    for dim_name in DIM_TABLES:
        dim_cfg = CONFIG[dim_name]  # (kept for parity; not strictly needed)

        # 1) stage
        stage_task = check_updates_and_stage.override(task_id=f'{dim_name}__check_stage')(dim_name)

        # 2) branch
        branch = decide_merge.override(task_id=f'{dim_name}__decide')(stage_task, dim_name)

        # 3) merge path (switched to python @task that renders & executes via PostgresHook)
        merge = run_merge.override(task_id=f'{dim_name}__merge')(dim_name)

        # 4) skip path end
        skip = EmptyOperator(task_id=f'{dim_name}__skip')

        # 5) watermark update (same logic; reads stage result via XCom)
        update_wm = PythonOperator(
            task_id=f'{dim_name}__update_wm',
            python_callable=update_watermarks_after_merge_py,
            op_kwargs={
                'table_name': dim_name,
                'check_result': "{{ ti.xcom_pull(task_ids='" + f"{dim_name}__check_stage" + "') }}",
            },
        )

        # Wire (explicit so it’s crystal clear in the UI)
        chain(start, stage_task, branch)
        branch >> merge >> update_wm >> dimensions_complete
        branch >> skip >> dimensions_complete

    dimensions_complete >> end

incremental_dag = incremental_update_pipeline()




