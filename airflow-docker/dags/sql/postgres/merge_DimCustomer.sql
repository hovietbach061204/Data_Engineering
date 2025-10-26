DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) Expire changed current rows
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
      );

    GET DIAGNOSTICS rows_expired = ROW_COUNT;

    -- 2) Insert new or changed records
    -- 2) Insert new or changed records (dedup + NOT EXISTS guard)
    WITH dedup AS (
      SELECT DISTINCT ON ("CustomerID") stg.*
      FROM {{ STAGING_SCHEMA }}."DimCustomer" stg
      ORDER BY "CustomerID", "StartDate" DESC
    )
    INSERT INTO {{ DWH_SCHEMA }}."DimCustomer" (
      "CustomerID","PersonType","FirstName","LastName","EmailAddress",
      "EmailPromotion","AddressLine1","City","StateProvinceName",
      "CountryRegionName","BirthDate","MaritalStatus","Gender",
      "Education","Occupation","HomeOwnerFlag","NumberCarsOwned",
      "NumberChildrenAtHome","TotalChildren","TotalPurchaseYTD",
      "YearlyIncome","DateFirstPurchase","StartDate","EndDate"
    )
    SELECT
      d."CustomerID", d."PersonType", d."FirstName", d."LastName",
      d."EmailAddress", d."EmailPromotion", d."AddressLine1",
      d."City", d."StateProvinceName", d."CountryRegionName",
      d."BirthDate", d."MaritalStatus", d."Gender", d."Education",
      d."Occupation", d."HomeOwnerFlag", d."NumberCarsOwned",
      d."NumberChildrenAtHome", d."TotalChildren", d."TotalPurchaseYTD",
      d."YearlyIncome", d."DateFirstPurchase", d."StartDate", current_until
    FROM dedup d
    WHERE NOT EXISTS (
      SELECT 1
      FROM {{ DWH_SCHEMA }}."DimCustomer" t
      WHERE t."CustomerID" = d."CustomerID"
        AND t."EndDate" = current_until
    );

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    RAISE NOTICE 'DimCustomer merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
