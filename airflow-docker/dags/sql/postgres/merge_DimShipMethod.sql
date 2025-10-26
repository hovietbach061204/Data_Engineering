-- PostgreSQL
-- Merge DimShipMethod from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) Expire changed current rows
    UPDATE {{ DWH_SCHEMA }}."DimShipMethod" AS tgt
    SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
    FROM {{ STAGING_SCHEMA }}."DimShipMethod" AS stg
    WHERE tgt."ShipMethodID" = stg."ShipMethodID"
      AND tgt."EndDate" = current_until
      AND (
          tgt."Name" IS DISTINCT FROM stg."Name" OR
          tgt."ShipBase" IS DISTINCT FROM stg."ShipBase" OR
          tgt."ShipRate" IS DISTINCT FROM stg."ShipRate" OR
          tgt."ShipDate" IS DISTINCT FROM stg."ShipDate"
      );

    GET DIAGNOSTICS rows_expired = ROW_COUNT;

    -- 2) Insert new or changed records
    WITH dedup AS (
        SELECT DISTINCT ON ("ShipMethodID") stg.*
        FROM {{ STAGING_SCHEMA }}."DimShipMethod" stg
        ORDER BY "ShipMethodID", "StartDate" DESC
    )
    INSERT INTO {{ DWH_SCHEMA }}."DimShipMethod" (
      "ShipMethodID","Name","ShipBase","ShipRate","ShipDate",
      "StartDate","EndDate"
    )
    SELECT
      d."ShipMethodID", d."Name", d."ShipBase", d."ShipRate",
      d."ShipDate", d."StartDate", current_until
    FROM dedup d
    WHERE NOT EXISTS (
      SELECT 1
      FROM {{ DWH_SCHEMA }}."DimShipMethod" t
      WHERE t."ShipMethodID" = d."ShipMethodID"
        AND t."EndDate" = current_until
    );

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    RAISE NOTICE 'DimShipMethod merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
