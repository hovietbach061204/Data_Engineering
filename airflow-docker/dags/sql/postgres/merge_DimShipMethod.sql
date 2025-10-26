DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) expire changed current rows
    WITH expired_rows AS (
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
          )
        RETURNING tgt."ShipMethodKey"
    )
    SELECT COUNT(*) INTO rows_expired FROM expired_rows;

    -- 2) insert new records / new versions
    WITH inserted_rows AS (
        INSERT INTO {{ DWH_SCHEMA }}."DimShipMethod" (
            "ShipMethodID", "Name", "ShipBase", "ShipRate", "ShipDate", "StartDate", "EndDate"
        )
        SELECT
            stg."ShipMethodID",
            stg."Name",
            stg."ShipBase",
            stg."ShipRate",
            stg."ShipDate",
            stg."StartDate",
            current_until
        FROM {{ STAGING_SCHEMA }}."DimShipMethod" AS stg
        LEFT JOIN {{ DWH_SCHEMA }}."DimShipMethod" AS tgt
               ON tgt."ShipMethodID" = stg."ShipMethodID"
              AND tgt."EndDate"      = current_until
        WHERE tgt."ShipMethodKey" IS NULL
           OR tgt."ShipMethodKey" IN (SELECT "ShipMethodKey" FROM expired_rows)
        RETURNING "ShipMethodKey"
    )
    SELECT COUNT(*) INTO rows_inserted FROM inserted_rows;

    RAISE NOTICE 'DimShipMethod merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
