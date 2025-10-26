-- PostgreSQL
-- Merge DimProduct from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) Expire changed current rows
    UPDATE {{ DWH_SCHEMA }}."DimProduct" AS tgt
    SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
    FROM {{ STAGING_SCHEMA }}."DimProduct" AS stg
    WHERE tgt."ProductID" = stg."ProductID"
      AND tgt."EndDate" = current_until
      AND (
          tgt."Name" IS DISTINCT FROM stg."Name" OR
          tgt."Color" IS DISTINCT FROM stg."Color" OR
          tgt."Size" IS DISTINCT FROM stg."Size" OR
          tgt."Weight" IS DISTINCT FROM stg."Weight" OR
          tgt."Style" IS DISTINCT FROM stg."Style" OR
          tgt."ModelName" IS DISTINCT FROM stg."ModelName" OR
          tgt."CategoryName" IS DISTINCT FROM stg."CategoryName" OR
          tgt."SubCategoryName" IS DISTINCT FROM stg."SubCategoryName" OR
          tgt."StandardCost" IS DISTINCT FROM stg."StandardCost" OR
          tgt."ListPrice" IS DISTINCT FROM stg."ListPrice" OR
          tgt."WarrantyPeriod" IS DISTINCT FROM stg."WarrantyPeriod" OR
          tgt."NoOfYears" IS DISTINCT FROM stg."NoOfYears"
      );

    GET DIAGNOSTICS rows_expired = ROW_COUNT;

    -- 2) Insert new or changed records
    INSERT INTO {{ DWH_SCHEMA }}."DimProduct" (
        "ProductID", "Name", "Color", "Size", "Weight", "Style",
        "ModelName", "CategoryName", "SubCategoryName",
        "StandardCost", "ListPrice", "WarrantyPeriod", "NoOfYears",
        "StartDate", "EndDate"
    )
    SELECT
        stg."ProductID", stg."Name", stg."Color", stg."Size", stg."Weight",
        stg."Style", stg."ModelName", stg."CategoryName", stg."SubCategoryName",
        stg."StandardCost", stg."ListPrice", stg."WarrantyPeriod",
        stg."NoOfYears", stg."StartDate", current_until
    FROM {{ STAGING_SCHEMA }}."DimProduct" AS stg
    LEFT JOIN {{ DWH_SCHEMA }}."DimProduct" AS tgt
           ON tgt."ProductID" = stg."ProductID"
          AND tgt."EndDate" = current_until
    WHERE tgt."ProductKey" IS NULL
       OR tgt."EndDate" < current_until;

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    RAISE NOTICE 'DimProduct merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;