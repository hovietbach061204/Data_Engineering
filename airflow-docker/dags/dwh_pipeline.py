# airflow-docker/dags/dwh_pipeline.py
from __future__ import annotations
from datetime import datetime
from pathlib import Path
import re

from airflow.decorators import dag, task
from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

# ---- CONFIG ----
MSSQL_CONN_ID   = "MSSQL_SRC"   # set via docker-compose env
PG_CONN_ID      = "PG_DWH"      # set via docker-compose env
STAGING_SCHEMA  = "staging"
DWH_SCHEMA      = "dwh"

# Tables your MSSQL scripts create/populate in CompanyX.dbo
TABLES = [
    "DimCustomer",
    "DimProduct",
    "DimPromotion",
    "DimSaleReason",
    "DimShipMethod",
    "DimStore",
    "DimTerritory",
    "FactSales",
]

BASE_SQL      = Path("/opt/airflow/dags/sql")
MSSQL_PRE_DIR = BASE_SQL / "mssql_pre"    # contains DimCreateTable.sql + Dim*.sql + Fact*.sql
# ---------------


def _run_tsql_file_with_go(path: Path):
    """Execute a .sql file against MSSQL, splitting on 'GO' batch separators."""
    hook = MsSqlHook(mssql_conn_id=MSSQL_CONN_ID)
    text = path.read_text(encoding="utf-8")
    batches = re.split(r"(?im)^\s*GO\s*;?\s*$", text)
    for stmt in batches:
        if stmt.strip():
            hook.run(stmt)


def _extract_table_to_postgres_staging(table_name: str):
    """Copy CompanyX.dbo.<table> from MSSQL → Postgres staging.<table> (lowercase)."""
    import pandas as pd  # local import so the task is self-contained
    mssql = MsSqlHook(mssql_conn_id=MSSQL_CONN_ID)
    pg    = PostgresHook(postgres_conn_id=PG_CONN_ID)

    df = mssql.get_pandas_df(f"SELECT * FROM CompanyX.dbo.{table_name};")

    dest_table = table_name.lower()
    dest_fq    = f"{STAGING_SCHEMA}.{dest_table}"

    engine = pg.get_sqlalchemy_engine()
    with engine.begin() as conn:
        conn.exec_driver_sql(f"CREATE SCHEMA IF NOT EXISTS {STAGING_SCHEMA};")
        conn.exec_driver_sql(f"DROP TABLE IF EXISTS {dest_fq};")
        df.head(0).to_sql(dest_table, conn, schema=STAGING_SCHEMA, if_exists="replace", index=False)
        if not df.empty:
            df.to_sql(dest_table, conn, schema=STAGING_SCHEMA, if_exists="append", index=False)


@dag(
    dag_id="wf_b_mssql_build_then_copy_to_pg",
    start_date=datetime(2025, 10, 1),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["taskflow", "mssql", "postgres", "staging", "spark"],
)
def wf_b_pipeline():

    @task
    def ensure_pg_schemas():
        pg = PostgresHook(postgres_conn_id=PG_CONN_ID)
        pg.run(f"CREATE SCHEMA IF NOT EXISTS {STAGING_SCHEMA};")
        pg.run(f"CREATE SCHEMA IF NOT EXISTS {DWH_SCHEMA};")

    @task
    def run_dim_create_in_mssql():
        # now located in mssql_pre/
        path = MSSQL_PRE_DIR / "DimCreateTable.sql"
        if not path.exists():
            raise FileNotFoundError(f"{path} not found")
        _run_tsql_file_with_go(path)

    @task
    def run_all_mssql_loaders():
        # execute every *.sql in mssql_pre except DimCreateTable.sql
        if not MSSQL_PRE_DIR.exists():
            return
        for sql_file in sorted(MSSQL_PRE_DIR.glob("*.sql")):
            if sql_file.name.lower() == "dimcreatetable.sql":
                continue
            _run_tsql_file_with_go(sql_file)

    # extract each table → staging
    extract_tasks = []
    for tbl in TABLES:
        @task(task_id=f"extract_{tbl}_to_pg_staging")
        def extract_one(tname=tbl):
            _extract_table_to_postgres_staging(tname)
            return tname.lower()
        extract_tasks.append(extract_one())

    # spark transforms (staging -> dwh)
    spark_tasks = []
    for tbl in TABLES:
        spark = SparkSubmitOperator(
            task_id=f"spark_transform_{tbl.lower()}",
            application="/opt/airflow/dags/spark_jobs/transform.py",
            name=f"spark-{tbl.lower()}",
            conn_id="spark_default",
            application_args=[
                f"--table={tbl.lower()}",
                f"--staging={STAGING_SCHEMA}",
                f"--dwh={DWH_SCHEMA}",
            ],
            packages="org.postgresql:postgresql:42.7.3",
            conf={"spark.master": "local[*]"},
            verbose=True,
        )
        spark_tasks.append(spark)

    # wiring
    schemas_ok  = ensure_pg_schemas()
    build_mssql = run_dim_create_in_mssql()
    load_mssql  = run_all_mssql_loaders()

    schemas_ok >> build_mssql >> load_mssql >> extract_tasks >> spark_tasks


wf_b_pipeline()