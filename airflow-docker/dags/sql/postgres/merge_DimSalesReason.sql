-- PostgreSQL
-- Merge DimSalesReason from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) expire changed current rows
    WITH expired_rows AS (
        UPDATE {{ DWH_SCHEMA }}."DimSalesReason" AS tgt
        SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
        FROM {{ STAGING_SCHEMA }}."DimSalesReason" AS stg
        WHERE tgt."SalesReasonID" = stg."SalesReasonID"
          AND tgt."SalesOrderID" = stg."SalesOrderID"
          AND tgt."EndDate" = current_until
          AND (
              tgt."Name" IS DISTINCT FROM stg."Name" OR
              tgt."ReasonType" IS DISTINCT FROM stg."ReasonType"
          )
        RETURNING tgt."ReasonKey"
    )
    SELECT COUNT(*) INTO rows_expired FROM expired_rows;

    -- 2) insert new records / new versions
    WITH inserted_rows AS (
        INSERT INTO {{ DWH_SCHEMA }}."DimSalesReason" (
            "SalesOrderID",
            "SalesReasonID",
            "Name",
            "ReasonType",
            "StartDate",
            "EndDate"
        )
        SELECT
            stg."SalesOrderID",
            stg."SalesReasonID",
            stg."Name",
            stg."ReasonType",
            stg."StartDate",
            current_until
        FROM {{ STAGING_SCHEMA }}."DimSalesReason" AS stg
        LEFT JOIN {{ DWH_SCHEMA }}."DimSalesReason" AS tgt
               ON tgt."SalesReasonID" = stg."SalesReasonID"
              AND tgt."SalesOrderID" = stg."SalesOrderID"
              AND tgt."EndDate" = current_until
        WHERE tgt."ReasonKey" IS NULL
           OR tgt."ReasonKey" IN (SELECT "ReasonKey" FROM expired_rows)
        RETURNING "ReasonKey"
    )
    SELECT COUNT(*) INTO rows_inserted FROM inserted_rows;

    RAISE NOTICE 'DimSalesReason merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
