-- PostgreSQL
-- Merge FactSales from staging into DWH (insert-only for facts)

DO $$
DECLARE
    rows_inserted INT := 0;
BEGIN
    -- Insert new fact records (no SCD logic - facts are immutable)
    WITH inserted_rows AS (
        INSERT INTO {{ DWH_SCHEMA }}."FactSales" (
            "ProductKey",
            "PromotionKey",
            "CustomerKey",
            "TerritoryKey",
            "StoreKey",
            "SaleReasonKey",
            "ShipMethodKey",
            "SalesOrderID",
            "SalesOrderDetail",
            "OrderQty",
            "UnitPrice",
            "UnitPriceDiscount",
            "OrderDateKey",
            "DueDateKey",
            "ShipDateKey",
            "Status",
            "OnlineOrderFlag",
            "TaxAllocated",
            "Freight_Allocated",
            "TotalDueTime",
            "LineAmountSource",
            "SalesInfoModifiedDate",
            "LineAmount_Gross",
            "LineDiscountAmount",
            "LineAmount_Net",
            "TotalDue_Line"
        )
        SELECT
            -- Resolve ProductKey from DimProduct using ProductID
            COALESCE(
                (SELECT p."ProductKey"
                 FROM {{ DWH_SCHEMA }}."DimProduct" p
                 WHERE p."ProductID" = stg."ProductID"
                   AND p."EndDate" = '9999-12-31'::timestamp
                 LIMIT 1),
                -1
            ) AS "ProductKey",

            -- Resolve PromotionKey from DimPromotion using PromotionID
            COALESCE(
                (SELECT pr."PromotionKey"
                 FROM {{ DWH_SCHEMA }}."DimPromotion" pr
                 WHERE pr."SpecialOfferID" = stg."PromotionID"
                   AND pr."EndDate" = '9999-12-31'::timestamp
                 LIMIT 1),
                -1
            ) AS "PromotionKey",

            -- Resolve CustomerKey from DimCustomer using CustomerID
            COALESCE(
                (SELECT c."CustomerKey"
                 FROM {{ DWH_SCHEMA }}."DimCustomer" c
                 WHERE c."CustomerID" = stg."CustomerID"
                   AND c."EndDate" = '9999-12-31'::timestamp
                 LIMIT 1),
                -1
            ) AS "CustomerKey",

            -- Resolve TerritoryKey from DimTerritory using TerritoryID
            COALESCE(
                (SELECT t."TerritoryKey"
                 FROM {{ DWH_SCHEMA }}."DimTerritory" t
                 WHERE t."TerritoryID" = stg."TerritoryID"
                   AND t."EndDate" = '9999-12-31'::timestamp
                 LIMIT 1),
                -1
            ) AS "TerritoryKey",

            -- Resolve StoreKey from DimStore using StoreID
            COALESCE(
                (SELECT s."StoreKey"
                 FROM {{ DWH_SCHEMA }}."DimStore" s
                 WHERE s."StoreID" = stg."StoreID"
                   AND s."EndDate" = '9999-12-31'::timestamp
                 LIMIT 1),
                -1
            ) AS "StoreKey",

            -- Resolve SaleReasonKey from DimSalesReason (using SalesOrderID + SalesReasonID)
            COALESCE(
                (SELECT sr."ReasonKey"
                 FROM {{ DWH_SCHEMA }}."DimSalesReason" sr
                 WHERE sr."SalesOrderID" = stg."SalesOrderID"
                   AND sr."EndDate" = '9999-12-31'::timestamp
                 LIMIT 1),
                -1
            ) AS "SaleReasonKey",

            -- Resolve ShipMethodKey from DimShipMethod using ShipMethodID
            COALESCE(
                (SELECT sm."ShipMethodKey"
                 FROM {{ DWH_SCHEMA }}."DimShipMethod" sm
                 WHERE sm."ShipMethodID" = stg."ShipMethodID"
                   AND sm."EndDate" = '9999-12-31'::timestamp
                 LIMIT 1),
                -1
            ) AS "ShipMethodKey",

            -- Business keys and measures from staging
            stg."SalesOrderID",
            stg."SalesOrderDetail",
            stg."OrderQty",
            stg."UnitPrice",
            stg."UnitPriceDiscount",
            stg."OrderDateKey",
            stg."DueDateKey",
            stg."ShipDateKey",
            stg."Status",
            stg."OnlineOrderFlag",
            stg."TaxAllocated",
            stg."Freight_Allocated",
            stg."TotalDueTime",
            stg."LineAmountSource",
            stg."SalesInfoModifiedDate",
            stg."LineAmount_Gross",
            stg."LineDiscountAmount",
            stg."LineAmount_Net",
            stg."TotalDue_Line"

        FROM {{ STAGING_SCHEMA }}."FactSales" AS stg

        -- Anti-join: Only insert if this combination doesn't exist yet
        LEFT JOIN {{ DWH_SCHEMA }}."FactSales" AS tgt
            ON tgt."SalesOrderID" = stg."SalesOrderID"
            AND tgt."SalesOrderDetail" = stg."SalesOrderDetail"

        WHERE tgt."FactSaleKey" IS NULL

        RETURNING "FactSaleKey"
    )
    SELECT COUNT(*) INTO rows_inserted FROM inserted_rows;

    RAISE NOTICE 'FactSales merge: % rows inserted', rows_inserted;
END $$;
