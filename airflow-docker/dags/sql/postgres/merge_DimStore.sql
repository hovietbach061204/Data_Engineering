-- PostgreSQL
-- Merge DimStore from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) Expire changed current rows
    UPDATE {{ DWH_SCHEMA }}."DimStore" AS tgt
    SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
    FROM {{ STAGING_SCHEMA }}."DimStore" AS stg
    WHERE tgt."StoreID" = stg."StoreID"
      AND tgt."EndDate" = current_until
      AND (
          tgt."Name" IS DISTINCT FROM stg."Name" OR
          tgt."AnnualSales" IS DISTINCT FROM stg."AnnualSales" OR
          tgt."AnnualRevenue" IS DISTINCT FROM stg."AnnualRevenue" OR
          tgt."BusinessType" IS DISTINCT FROM stg."BusinessType" OR
          tgt."BankName" IS DISTINCT FROM stg."BankName" OR
          tgt."YearOpened" IS DISTINCT FROM stg."YearOpened" OR
          tgt."Specialty" IS DISTINCT FROM stg."Specialty" OR
          tgt."SquareFeet" IS DISTINCT FROM stg."SquareFeet" OR
          tgt."Brands" IS DISTINCT FROM stg."Brands" OR
          tgt."Internet" IS DISTINCT FROM stg."Internet" OR
          tgt."NumberEmployees" IS DISTINCT FROM stg."NumberEmployees" OR
          tgt."AddressType" IS DISTINCT FROM stg."AddressType" OR
          tgt."AddressLine1" IS DISTINCT FROM stg."AddressLine1" OR
          tgt."AddressLine2" IS DISTINCT FROM stg."AddressLine2" OR
          tgt."City" IS DISTINCT FROM stg."City" OR
          tgt."StateProvinceName" IS DISTINCT FROM stg."StateProvinceName" OR
          tgt."CountryRegionName" IS DISTINCT FROM stg."CountryRegionName"
      );

    GET DIAGNOSTICS rows_expired = ROW_COUNT;

    -- 2) Insert new or changed records
    INSERT INTO {{ DWH_SCHEMA }}."DimStore" (
        "StoreID", "Name", "AnnualSales", "AnnualRevenue", "BusinessType",
        "BankName", "YearOpened", "Specialty", "SquareFeet", "Brands",
        "Internet", "NumberEmployees", "AddressType", "AddressLine1",
        "AddressLine2", "City", "StateProvinceName", "CountryRegionName",
        "StartDate", "EndDate"
    )
    SELECT
        stg."StoreID", stg."Name", stg."AnnualSales", stg."AnnualRevenue",
        stg."BusinessType", stg."BankName", stg."YearOpened", stg."Specialty",
        stg."SquareFeet", stg."Brands", stg."Internet", stg."NumberEmployees",
        stg."AddressType", stg."AddressLine1", stg."AddressLine2", stg."City",
        stg."StateProvinceName", stg."CountryRegionName", stg."StartDate", current_until
    FROM {{ STAGING_SCHEMA }}."DimStore" AS stg
    LEFT JOIN {{ DWH_SCHEMA }}."DimStore" AS tgt
           ON tgt."StoreID" = stg."StoreID"
          AND tgt."EndDate" = current_until
    WHERE tgt."StoreKey" IS NULL
       OR tgt."EndDate" < current_until;

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    RAISE NOTICE 'DimStore merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
