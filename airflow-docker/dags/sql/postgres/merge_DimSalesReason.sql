-- PostgreSQL
-- Merge DimSalesReason from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) Expire changed current rows
    UPDATE {{ DWH_SCHEMA }}."DimSalesReason" AS tgt
    SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
    FROM {{ STAGING_SCHEMA }}."DimSalesReason" AS stg
    WHERE tgt."SalesReasonID" = stg."SalesReasonID"
      AND tgt."SalesOrderID" = stg."SalesOrderID"
      AND tgt."EndDate" = current_until
      AND (
          tgt."Name" IS DISTINCT FROM stg."Name" OR
          tgt."ReasonType" IS DISTINCT FROM stg."ReasonType"
      );

    GET DIAGNOSTICS rows_expired = ROW_COUNT;

    -- 2) Insert new or changed records
    INSERT INTO {{ DWH_SCHEMA }}."DimSalesReason" (
        "SalesOrderID", "SalesReasonID", "Name", "ReasonType",
        "StartDate", "EndDate"
    )
    SELECT
        stg."SalesOrderID", stg."SalesReasonID", stg."Name", stg."ReasonType",
        stg."StartDate", current_until
    FROM {{ STAGING_SCHEMA }}."DimSalesReason" AS stg
    LEFT JOIN {{ DWH_SCHEMA }}."DimSalesReason" AS tgt
           ON tgt."SalesReasonID" = stg."SalesReasonID"
          AND tgt."SalesOrderID" = stg."SalesOrderID"
          AND tgt."EndDate" = current_until
    WHERE tgt."SalesReasonKey" IS NULL
       OR tgt."EndDate" < current_until;

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    RAISE NOTICE 'DimSalesReason merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
