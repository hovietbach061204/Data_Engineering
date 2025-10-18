import argparse
import os

def transform_table(spark, table: str, staging: str, dwh: str, mode: str, pg_url: str, pg_user: str, pg_pass: str):
    """Transform a single table"""
    from pyspark.sql.functions import trim, upper, col, when, to_date

    driver = "org.postgresql.Driver"
    src = f"{staging}.{table}"
    dst = f"{dwh}.{table}"

    # Read from staging
    df = (
        spark.read.format("jdbc")
        .option("url", pg_url)
        .option("dbtable", src)
        .option("user", pg_user)
        .option("password", pg_pass)
        .option("driver", driver)
        .option("fetchsize", "10000")
        .load()
    )

    print(f"\n=== Processing {table}: {df.count()} rows ===")

    # Apply transformations
    for c, t in df.dtypes:
        if t.startswith("string"):
            df = df.withColumn(c, trim(col(c)))
            if "name" in c.lower():
                df = df.withColumn(c, upper(col(c)))

    # Remove duplicates
    key_cols = [c for c in df.columns if "key" in c.lower() or "id" in c.lower()]
    if key_cols:
        df = df.dropDuplicates(key_cols)

    # Fill nulls
    fill_dict = {c: "UNKNOWN" if t.startswith("string") else 0 for c, t in df.dtypes}
    df = df.fillna(fill_dict)

    # Write to DWH
    (
        df.write.mode(mode)
        .format("jdbc")
        .option("url", pg_url)
        .option("dbtable", dst)
        .option("user", pg_user)
        .option("password", pg_pass)
        .option("driver", driver)
        .option("batchsize", "10000")
        .option("numPartitions", "4")
        .save()
    )

    print(f"Wrote {table} to {dst}")

def main():
    from pyspark.sql import SparkSession

    parser = argparse.ArgumentParser()
    parser.add_argument("--tables", required=True, help="Comma-separated table names")
    parser.add_argument("--staging", default="staging")
    parser.add_argument("--dwh", default="dwh")
    parser.add_argument("--mode", default="overwrite")
    args = parser.parse_args()

    tables = args.tables.split(",")
    staging = args.staging
    dwh = args.dwh
    mode = args.mode

    pg_url = "jdbc:postgresql://pg-dwh:5432/dwh"
    pg_user = os.getenv("PG_USER", "dwh")
    pg_pass = os.getenv("PG_PASS", "dwh")

    spark = (
        SparkSession.builder
        .appName("dwh-transform-batch")
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .getOrCreate()
    )

    for table in tables:
        try:
            transform_table(spark, table, staging, dwh, mode, pg_url, pg_user, pg_pass)
        except Exception as e:
            print(f"Failed to transform {table}: {e}")

    spark.stop()
    print(f"\nCompleted batch transformation of {len(tables)} tables")

if __name__ == "__main__":
    main()
