from __future__ import annotations
from datetime import datetime
from pathlib import Path
from airflow.decorators import dag, task
from airflow.models.baseoperator import chain

# ---- CONFIG ----
MSSQL_CONN_ID = "MSSQL_SRC"
PG_CONN_ID    = "PG_DWH"
STAGING_SCHEMA = "staging"
DWH_SCHEMA     = "dwh"
TABLES = ["DimCustomer","DimProduct","DimPromotion","DimSalesReason","DimShipMethod","DimStore","DimTerritory","DimDate","FactSales"]
DIMS = ["DimProduct", "DimPromotion", "DimSalesReason", "DimTerritory", "DimShipMethod", "DimStore", "DimCustomer", "DimDate"]
BASE_SQL = Path("/opt/airflow/dags/sql")
MSSQL_PRE_DIR = BASE_SQL / "mssql_pre"
POSTGRES_DIR = BASE_SQL / "postgres"

@dag(
    dag_id="mssql_to_postgres_dwh_pipeline",
    start_date=datetime(2025, 10, 1),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["mssql","postgres","spark","dwh"],
)
def dwh_pipeline():
    def run_sql_file(sql_path: Path):
        """Execute a SQL file with GO batch splitting"""
        import re
        from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
        from airflow.utils.log.logging_mixin import LoggingMixin

        log = LoggingMixin().log
        hook = MsSqlHook(mssql_conn_id=MSSQL_CONN_ID)

        GO_SPLIT = re.compile(r"(?im)^\s*go\s*;?\s*(?:--.*)?$", re.MULTILINE)

        txt = sql_path.read_text(encoding="utf-8-sig", errors="ignore")
        txt = txt.replace("\r\n", "\n").lstrip("\ufeff")
        batches = [p.strip() for p in GO_SPLIT.split(txt) if p.strip()]

        for i, batch in enumerate(batches, 1):
            hook.run(batch)
            log.info(f"Executed {sql_path.name} [batch {i}/{len(batches)}]")

    @task()
    def create_ddl():
        """Create all table schemas first"""
        run_sql_file(MSSQL_PRE_DIR / "DimCreateTable.sql")
        return "DDL created"

    @task()
    def create_indexes_and_fks():
        """Create indexes and foreign keys after data is loaded"""
        run_sql_file(MSSQL_PRE_DIR / "DimCreateIndexes.sql")
        return "Indexes and FKs created"

    @task()
    def create_incremental_indexes():
        """Create indexes for incremental loading watermark queries"""
        run_sql_file(MSSQL_PRE_DIR / "create_incremental_indexes.sql")
        return "Incremental indexes created"

    @task()
    def create_dwh_indexes():
        """Create indexes on PostgreSQL DWH tables after data load"""
        from airflow.providers.postgres.hooks.postgres import PostgresHook

        pg = PostgresHook(postgres_conn_id=PG_CONN_ID)
        sql_path = POSTGRES_DIR / "ddl" / "create_dwh_indexes.sql"

        sql = sql_path.read_text(encoding="utf-8")
        pg.run(sql)

        return "PostgreSQL DWH indexes created"

    @task()
    def create_watermark_metadata():
        """Create watermark tracking table in PostgreSQL"""
        from airflow.providers.postgres.hooks.postgres import PostgresHook

        pg = PostgresHook(postgres_conn_id=PG_CONN_ID)
        watermark_sql_path = POSTGRES_DIR / "ddl" / "create_watermark_tables.sql"

        sql = watermark_sql_path.read_text(encoding="utf-8")
        pg.run(sql)

        return "Watermark metadata created"


    @task()
    def auto_generate_key_column():
        from airflow.providers.postgres.hooks.postgres import PostgresHook
        pg = PostgresHook(postgres_conn_id=PG_CONN_ID)
        autokey_sql_path = POSTGRES_DIR / "ddl" / "auto_generate_key_column.sql"

        sql = autokey_sql_path.read_text(encoding="utf-8")
        pg.run(sql)

        return "Autokey column created"

    @task()
    def extract_dimension(table_name: str):
        """Extract a single dimension table from MSSQL"""
        from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
        from airflow.exceptions import AirflowException

        run_sql_file(MSSQL_PRE_DIR / f"{table_name}.sql")

        # Verify rows were loaded
        hook = MsSqlHook(mssql_conn_id=MSSQL_CONN_ID)
        count = int(hook.get_first(f"SELECT COUNT(*) FROM CompanyX.dbo.{table_name};")[0])

        if count == 0:
            raise AirflowException(f"{table_name} loaded 0 rows in MSSQL")

        return f"{table_name}: {count} rows"

    @task()
    def extract_fact():
        """Extract FactSales after all dimensions are loaded"""
        from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
        from airflow.exceptions import AirflowException

        run_sql_file(MSSQL_PRE_DIR / "FactSales.sql")

        # Strict validation for FactSales
        hook = MsSqlHook(mssql_conn_id=MSSQL_CONN_ID)
        count = int(hook.get_first("SELECT COUNT(*) FROM CompanyX.dbo.FactSales;")[0])

        if count == 0:
            raise AirflowException("FactSales loaded 0 rows - failing fast")

        return f"FactSales: {count} rows"

    @task()
    def load_to_staging(table_name: str):
        """
        Load table from MSSQL to Postgres staging schema with type mapping
        """
        import csv
        from math import ceil
        from tempfile import NamedTemporaryFile
        from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
        from airflow.providers.postgres.hooks.postgres import PostgresHook
        from airflow.exceptions import AirflowException

        mssql = MsSqlHook(mssql_conn_id=MSSQL_CONN_ID)
        pg = PostgresHook(postgres_conn_id=PG_CONN_ID)

        # Get column metadata from MSSQL
        meta_sql = f"""
        SELECT
            c.name                 AS col_name,
            t.name                 AS mssql_type,
            c.max_length           AS max_len_bytes,
            c.precision            AS numeric_precision,
            c.scale                AS numeric_scale,
            c.is_nullable          AS is_nullable,
            c.is_identity          AS is_identity
        FROM sys.columns c
        JOIN sys.types   t ON c.user_type_id = t.user_type_id
        WHERE c.object_id = OBJECT_ID(N'CompanyX.dbo.{table_name}')
        ORDER BY c.column_id;
        """

        with mssql.get_conn() as src_conn:
            cur = src_conn.cursor()
            cur.execute(meta_sql)
            cols_meta = cur.fetchall()
            if not cols_meta:
                raise AirflowException(f"Table CompanyX.dbo.{table_name} not found")
            colnames = [row[0] for row in cols_meta]

        def map_type(mssql_type: str, max_len_bytes: int, prec: int, scale: int) -> str:
            mt = mssql_type.lower()
            if mt in ("varchar", "char"):
                return "text" if max_len_bytes == -1 else f"varchar({max_len_bytes})"
            if mt in ("nvarchar", "nchar"):
                return "text" if max_len_bytes == -1 else f"varchar({ceil(max_len_bytes / 2)})"
            if mt in ("text", "ntext"):
                return "text"
            if mt in ("varbinary", "binary", "image"):
                return "bytea"
            if mt in ("decimal", "numeric"):
                return f"numeric({prec},{scale})" if prec and scale is not None else "numeric"
            if mt == "money":
                return "numeric(19,4)"
            if mt == "smallmoney":
                return "numeric(10,4)"
            if mt == "float":
                return "double precision"
            if mt == "real":
                return "real"
            if mt == "bigint":
                return "bigint"
            if mt == "int":
                return "integer"
            if mt == "smallint":
                return "smallint"
            if mt == "tinyint":
                return "smallint"
            if mt == "bit":
                return "boolean"
            if mt in ("datetime", "datetime2", "smalldatetime"):
                return "timestamp without time zone"
            if mt == "date":
                return "date"
            if mt == "time":
                return "time without time zone"
            if mt == "uniqueidentifier":
                return "uuid"
            if mt == "xml":
                return "xml"
            return "text"

        # Create staging table
        pg_cols = []
        for (col_name, mssql_type, max_len_bytes, prec, scale, is_nullable, _) in cols_meta:
            pg_type = map_type(mssql_type, max_len_bytes, prec, scale)
            null_sql = "" if is_nullable == 1 else " NOT NULL"
            pg_cols.append(f'"{col_name}" {pg_type}{null_sql}')

        create_cols_sql = ", ".join(pg_cols)
        cols_list_sql = ", ".join(f'"{c}"' for c in colnames)

        with pg.get_conn() as dest_conn:
            with dest_conn.cursor() as pc:
                pc.execute(f'CREATE SCHEMA IF NOT EXISTS "{STAGING_SCHEMA}";')
                pc.execute(f'DROP TABLE IF EXISTS "{STAGING_SCHEMA}"."{table_name}";')
                pc.execute(f'CREATE TABLE "{STAGING_SCHEMA}"."{table_name}" ({create_cols_sql});')
            dest_conn.commit()

        # Export from MSSQL and COPY to Postgres
        batch_size = 50_000
        rowcount = 0

        with mssql.get_conn() as src_conn:
            src_cur = src_conn.cursor()
            select_sql = "SELECT " + ", ".join(f"[{c}]" for c in colnames) + f" FROM CompanyX.dbo.{table_name};"
            src_cur.execute(select_sql)

            with NamedTemporaryFile(mode="w+", newline="", suffix=".csv") as tmp:
                writer = csv.writer(tmp)
                writer.writerow(colnames)

                while True:
                    rows = src_cur.fetchmany(batch_size)
                    if not rows:
                        break
                    writer.writerows(rows)
                    rowcount += len(rows)

                tmp.flush()

                if rowcount == 0:
                    return f"{table_name}: 0 rows"

                copy_sql = (
                    f'COPY "{STAGING_SCHEMA}"."{table_name}" ({cols_list_sql}) '
                    f"FROM STDIN WITH (FORMAT CSV, HEADER TRUE)"
                )
                pg.copy_expert(copy_sql, tmp.name)

        return f"{table_name}: {rowcount} rows"

    @task()
    def transform_staging_to_dwh(table_name: str, mode: str = "overwrite"):
        """
        Transform staging -> DWH.

        overwrite: TRUNCATE target CASCADE and INSERT (keeps PK/FKs/indexes).
        append:    INSERT only.

        NOTE: TRUNCATE CASCADE will also truncate any referencing tables
        (e.g., FactSales). Make sure your DAG reloads facts after dimensions.
        """
        from airflow.providers.postgres.hooks.postgres import PostgresHook

        q = lambda ident: '"' + ident.replace('"', '""') + '"'
        pg = PostgresHook(postgres_conn_id=PG_CONN_ID)

        # discover columns from STAGING
        cols = pg.get_records(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = %s
              AND table_name = %s
            ORDER BY ordinal_position;
            """,
            parameters=(STAGING_SCHEMA, table_name),
        )
        if not cols:
            raise ValueError(f"No columns found in {STAGING_SCHEMA}.{table_name}")

        char_types = {"character varying", "varchar", "character", "char", "text", "bpchar", "citext"}
        select_exprs = [
            f'TRIM("{c}") AS "{c}"' if t in char_types else f'"{c}"'
            for c, t in cols
        ]
        col_list = ", ".join(f'"{c}"' for c, _ in cols)
        select_sql = ", ".join(select_exprs)

        src = f'{q(STAGING_SCHEMA)}.{q(table_name)}'
        dst = f'{q(DWH_SCHEMA)}.{q(table_name)}'

        # ensure schema & table
        pg.run(f'CREATE SCHEMA IF NOT EXISTS {q(DWH_SCHEMA)};')
        exists = pg.get_first(
            """
            SELECT EXISTS (SELECT 1
                           FROM information_schema.tables
                           WHERE table_schema = %s
                             AND table_name = %s);
            """,
            parameters=(DWH_SCHEMA, table_name),
        )[0]
        if not exists:
            pg.run(f'CREATE TABLE {dst} (LIKE {src} INCLUDING ALL);')

        if mode == "overwrite":
            # The key change: CASCADE handles FK references (e.g., FactSales -> DimPromotion)
            pg.run(f"TRUNCATE TABLE {dst} CASCADE;")
            pg.run(f"INSERT INTO {dst} ({col_list}) SELECT {select_sql} FROM {src};")

        elif mode == "append":
            pg.run(f"INSERT INTO {dst} ({col_list}) SELECT {select_sql} FROM {src};")
        else:
            raise ValueError("mode must be 'overwrite' or 'append'")

        return f"Transformed {table_name} -> {DWH_SCHEMA} ({mode})"

    @task()
    def spark_transform_all():
        """Submit ONE Spark job to process all tables"""
        from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

        return SparkSubmitOperator(
            task_id="spark_transform_all_tables",
            application="/opt/airflow/jobs/spark/transform.py",
            conn_id="spark_default",
            application_args=[
                f"--tables={','.join(TABLES)}",
                "--staging=staging",
                "--dwh=dwh",
                "--mode=overwrite"
            ],
            packages="org.postgresql:postgresql:42.7.3",
            conf={
                "spark.master": "spark://spark:7077",    # <-- set master here
                "spark.submit.deployMode": "client",
                "spark.driver.memory": "2g",
                "spark.executor.memory": "2g",
                "spark.executor.cores": "2",
                "spark.sql.shuffle.partitions": "4",
            },
            verbose=True,
        ).execute({})

    # Stage 1: run setup tasks exactly once, in order
    ddl_task = create_ddl()
    indexes_task = create_indexes_and_fks()
    incremental_indexes_task = create_incremental_indexes()
    watermark_task = create_watermark_metadata()
    dwh_indexes_task = create_dwh_indexes()
    auto_generate_key_column = auto_generate_key_column()

    # Ensure DDL completes before watermark init
    chain(ddl_task, indexes_task, incremental_indexes_task, watermark_task)

    # Stage 2: per-dimension pipelines (extract → load → transform)
    dim_extracts = []
    for dim in DIMS:
        extract = extract_dimension.override(task_id=f"extract_{dim}")(dim)
        load = load_to_staging.override(task_id=f"load_{dim}")(dim)
        trans = transform_staging_to_dwh.override(task_id=f"transform_{dim}")(dim)

        # Gate every dimension on watermark_task (which itself waits on ddl_task)
        chain(watermark_task, extract, load, trans)

        dim_extracts.append(extract)

    # Stage 3: fact pipeline
    fact_extract = extract_fact()
    fact_load = load_to_staging.override(task_id="load_FactSales")("FactSales")
    fact_transform = transform_staging_to_dwh.override(task_id="transform_FactSales")("FactSales")

    # Fact extract waits for ALL dimension extracts to finish
    fact_extract.set_upstream(dim_extracts)

    # Then load & transform fact
    chain(fact_extract, fact_load, fact_transform)

    # Stage 4: Create PostgreSQL indexes AFTER all data is loaded
    fact_transform >> dwh_indexes_task >> auto_generate_key_column

_ = dwh_pipeline()