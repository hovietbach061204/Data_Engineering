-- PostgreSQL
-- Merge DimPromotion from staging into DWH (SCD Type 2)

DO $$
DECLARE
    rows_expired  INT := 0;
    rows_inserted INT := 0;
    current_until TIMESTAMP := '9999-12-31'::timestamp;
BEGIN
    -- 1) Expire changed current rows
    UPDATE {{ DWH_SCHEMA }}."DimPromotion" AS tgt
    SET "EndDate" = stg."StartDate" - INTERVAL '1 second'
    FROM {{ STAGING_SCHEMA }}."DimPromotion" AS stg
    WHERE tgt."SpecialOfferID" = stg."SpecialOfferID"
      AND tgt."EndDate" = current_until
      AND (
          tgt."Description" IS DISTINCT FROM stg."Description" OR
          tgt."Type" IS DISTINCT FROM stg."Type" OR
          tgt."Category" IS DISTINCT FROM stg."Category" OR
          tgt."DiscountPct" IS DISTINCT FROM stg."DiscountPct" OR
          tgt."MinQty" IS DISTINCT FROM stg."MinQty" OR
          tgt."MaxQty" IS DISTINCT FROM stg."MaxQty"
      );

    GET DIAGNOSTICS rows_expired = ROW_COUNT;

    -- 2) Insert new or changed records
    INSERT INTO {{ DWH_SCHEMA }}."DimPromotion" (
        "SpecialOfferID", "Description", "Type", "Category", "DiscountPct",
        "StartDate", "EndDate", "MinQty", "MaxQty"
    )
    SELECT
        stg."SpecialOfferID", stg."Description", stg."Type", stg."Category",
        stg."DiscountPct", stg."StartDate", current_until, stg."MinQty", stg."MaxQty"
    FROM {{ STAGING_SCHEMA }}."DimPromotion" AS stg
    LEFT JOIN {{ DWH_SCHEMA }}."DimPromotion" AS tgt
           ON tgt."SpecialOfferID" = stg."SpecialOfferID"
          AND tgt."EndDate" = current_until
    WHERE tgt."PromotionKey" IS NULL
       OR tgt."EndDate" < current_until;

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    RAISE NOTICE 'DimPromotion merge: % rows expired, % rows inserted',
                 rows_expired, rows_inserted;
END $$;
