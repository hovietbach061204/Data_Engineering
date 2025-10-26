-- PostgreSQL
-- Merge DimCustomer from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) expire changed current rows
    WITH expired_rows AS (
        UPDATE {{ DWH_SCHEMA }}."DimCustomer" AS tgt
        SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
        FROM {{ STAGING_SCHEMA }}."DimCustomer" AS stg
        WHERE tgt."CustomerID" = stg."CustomerID"
          AND tgt."EndDate" = current_until
          AND (
              tgt."PersonType" IS DISTINCT FROM stg."PersonType" OR
              tgt."FirstName" IS DISTINCT FROM stg."FirstName" OR
              tgt."LastName" IS DISTINCT FROM stg."LastName" OR
              tgt."EmailAddress" IS DISTINCT FROM stg."EmailAddress" OR
              tgt."EmailPromotion" IS DISTINCT FROM stg."EmailPromotion" OR
              tgt."AddressLine1" IS DISTINCT FROM stg."AddressLine1" OR
              tgt."City" IS DISTINCT FROM stg."City" OR
              tgt."StateProvinceName" IS DISTINCT FROM stg."StateProvinceName" OR
              tgt."CountryRegionName" IS DISTINCT FROM stg."CountryRegionName" OR
              tgt."BirthDate" IS DISTINCT FROM stg."BirthDate" OR
              tgt."MaritalStatus" IS DISTINCT FROM stg."MaritalStatus" OR
              tgt."Gender" IS DISTINCT FROM stg."Gender" OR
              tgt."Education" IS DISTINCT FROM stg."Education" OR
              tgt."Occupation" IS DISTINCT FROM stg."Occupation" OR
              tgt."HomeOwnerFlag" IS DISTINCT FROM stg."HomeOwnerFlag" OR
              tgt."NumberCarsOwned" IS DISTINCT FROM stg."NumberCarsOwned" OR
              tgt."NumberChildrenAtHome" IS DISTINCT FROM stg."NumberChildrenAtHome" OR
              tgt."TotalChildren" IS DISTINCT FROM stg."TotalChildren" OR
              tgt."TotalPurchaseYTD" IS DISTINCT FROM stg."TotalPurchaseYTD" OR
              tgt."YearlyIncome" IS DISTINCT FROM stg."YearlyIncome" OR
              tgt."DateFirstPurchase" IS DISTINCT FROM stg."DateFirstPurchase"
          )
        RETURNING tgt."CustomerKey"
    )
    SELECT COUNT(*) INTO rows_expired FROM expired_rows;

    -- 2) insert new records / new versions
    WITH inserted_rows AS (
        INSERT INTO {{ DWH_SCHEMA }}."DimCustomer" (
            "CustomerID",
            "PersonType",
            "FirstName",
            "LastName",
            "EmailAddress",
            "EmailPromotion",
            "AddressLine1",
            "City",
            "StateProvinceName",
            "CountryRegionName",
            "BirthDate",
            "MaritalStatus",
            "Gender",
            "Education",
            "Occupation",
            "HomeOwnerFlag",
            "NumberCarsOwned",
            "NumberChildrenAtHome",
            "TotalChildren",
            "TotalPurchaseYTD",
            "YearlyIncome",
            "DateFirstPurchase",
            "StartDate",
            "EndDate"
        )
        SELECT
            stg."CustomerID",
            stg."PersonType",
            stg."FirstName",
            stg."LastName",
            stg."EmailAddress",
            stg."EmailPromotion",
            stg."AddressLine1",
            stg."City",
            stg."StateProvinceName",
            stg."CountryRegionName",
            stg."BirthDate",
            stg."MaritalStatus",
            stg."Gender",
            stg."Education",
            stg."Occupation",
            stg."HomeOwnerFlag",
            stg."NumberCarsOwned",
            stg."NumberChildrenAtHome",
            stg."TotalChildren",
            stg."TotalPurchaseYTD",
            stg."YearlyIncome",
            stg."DateFirstPurchase",
            stg."StartDate",
            current_until
        FROM {{ STAGING_SCHEMA }}."DimCustomer" AS stg
        LEFT JOIN {{ DWH_SCHEMA }}."DimCustomer" AS tgt
               ON tgt."CustomerID" = stg."CustomerID"
              AND tgt."EndDate" = current_until
        WHERE tgt."CustomerKey" IS NULL
           OR tgt."CustomerKey" IN (SELECT "CustomerKey" FROM expired_rows)
        RETURNING "CustomerKey"
    )
    SELECT COUNT(*) INTO rows_inserted FROM inserted_rows;

    RAISE NOTICE 'DimCustomer merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
