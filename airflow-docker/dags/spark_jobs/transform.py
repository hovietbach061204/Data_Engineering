# airflow-docker/dags/spark_jobs/transform.py
import argparse
import os
from pyspark.sql import SparkSession

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--table", required=True)
    parser.add_argument("--staging", default="staging")
    parser.add_argument("--dwh", default="dwh")
    parser.add_argument("--mode", default="overwrite", choices=["overwrite", "append"])
    args = parser.parse_args()

    table   = args.table
    staging = args.staging
    dwh     = args.dwh
    mode    = args.mode

    pg_url  = "jdbc:postgresql://pg-dwh:5432/dwh"
    pg_user = os.getenv("PG_USER", "dwh")
    pg_pass = os.getenv("PG_PASS", "dwh")
    driver  = "org.postgresql.Driver"

    spark = (
        SparkSession.builder
        .appName(f"dwh-transform-{table}")
        .getOrCreate()
    )

    src = f"{staging}.{table}"
    dst = f"{dwh}.{table}"

    df = (
        spark.read.format("jdbc")
        .option("url", pg_url)
        .option("dbtable", src)
        .option("user", pg_user)
        .option("password", pg_pass)
        .option("driver", driver)
        .option("fetchsize", "10000")   # safer default
        .load()
    )

    print(f"[transform] Input schema for {src}:")
    df.printSchema()
    print(f"[transform] Input count for {src}: {df.count()}")

    # ---------- TRANSFORM HERE ----------
    from pyspark.sql.functions import trim
    for c, t in df.dtypes:
        if t.startswith("string"):
            df = df.withColumn(c, trim(c))
    # (Add per-table logic by branching on `table` if needed)
    # ------------------------------------

    writer = (
        df.write
        .mode(mode)
        .format("jdbc")
        .option("url", pg_url)
        .option("dbtable", dst)
        .option("user", pg_user)
        .option("password", pg_pass)
        .option("driver", driver)
    )
    if mode == "overwrite":
        writer = writer.option("truncate", "true")

    writer.save()

    spark.stop()


if __name__ == "__main__":
    main()