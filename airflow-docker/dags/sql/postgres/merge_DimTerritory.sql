-- PostgreSQL
-- Merge DimTerritory from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) expire changed current rows
    WITH expired_rows AS (
        UPDATE {{ DWH_SCHEMA }}."DimTerritory" AS tgt
        SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
        FROM {{ STAGING_SCHEMA }}."DimTerritory" AS stg
        WHERE tgt."TerritoryID" = stg."TerritoryID"
          AND tgt."EndDate" = current_until
          AND (
              tgt."Name" IS DISTINCT FROM stg."Name" OR
              tgt."CountryRegionName" IS DISTINCT FROM stg."CountryRegionName" OR
              tgt."Group" IS DISTINCT FROM stg."Group" OR
              tgt."SalesYTD" IS DISTINCT FROM stg."SalesYTD" OR
              tgt."SalesLastYear" IS DISTINCT FROM stg."SalesLastYear" OR
              tgt."CostYTD" IS DISTINCT FROM stg."CostYTD" OR
              tgt."CostLastYear" IS DISTINCT FROM stg."CostLastYear"
          )
        RETURNING tgt."TerritoryKey"
    )
    SELECT COUNT(*) INTO rows_expired FROM expired_rows;

    -- 2) insert new records / new versions
    WITH inserted_rows AS (
        INSERT INTO {{ DWH_SCHEMA }}."DimTerritory" (
            "TerritoryID",
            "Name",
            "CountryRegionName",
            "Group",
            "SalesYTD",
            "SalesLastYear",
            "CostYTD",
            "CostLastYear",
            "StartDate",
            "EndDate"
        )
        SELECT
            stg."TerritoryID",
            stg."Name",
            stg."CountryRegionName",
            stg."Group",
            stg."SalesYTD",
            stg."SalesLastYear",
            stg."CostYTD",
            stg."CostLastYear",
            stg."StartDate",
            current_until
        FROM {{ STAGING_SCHEMA }}."DimTerritory" AS stg
        LEFT JOIN {{ DWH_SCHEMA }}."DimTerritory" AS tgt
               ON tgt."TerritoryID" = stg."TerritoryID"
              AND tgt."EndDate" = current_until
        WHERE tgt."TerritoryKey" IS NULL
           OR tgt."TerritoryKey" IN (SELECT "TerritoryKey" FROM expired_rows)
        RETURNING "TerritoryKey"
    )
    SELECT COUNT(*) INTO rows_inserted FROM inserted_rows;

    RAISE NOTICE 'DimTerritory merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
