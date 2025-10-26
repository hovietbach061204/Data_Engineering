-- ==========================================================
-- STEP 1. Ensure all DIM tables have primary keys on surrogate keys
-- ==========================================================

ALTER TABLE dwh."DimCustomer"
    DROP CONSTRAINT IF EXISTS pk_dimcustomer CASCADE ;
ALTER TABLE dwh."DimCustomer"
    ADD CONSTRAINT pk_dimcustomer PRIMARY KEY ("CustomerKey");

ALTER TABLE dwh."DimProduct"
    DROP CONSTRAINT IF EXISTS pk_dimproduct CASCADE;
ALTER TABLE dwh."DimProduct"
    ADD CONSTRAINT pk_dimproduct PRIMARY KEY ("ProductKey");

ALTER TABLE dwh."DimPromotion"
    DROP CONSTRAINT IF EXISTS pk_dimpromotion CASCADE;
ALTER TABLE dwh."DimPromotion"
    ADD CONSTRAINT pk_dimpromotion PRIMARY KEY ("PromotionKey");

ALTER TABLE dwh."DimSalesReason"
    DROP CONSTRAINT IF EXISTS pk_dimsalesreason CASCADE;
ALTER TABLE dwh."DimSalesReason"
    ADD CONSTRAINT pk_dimsalesreason PRIMARY KEY ("SalesReasonKey");

ALTER TABLE dwh."DimTerritory"
    DROP CONSTRAINT IF EXISTS pk_dimterritory CASCADE;
ALTER TABLE dwh."DimTerritory"
    ADD CONSTRAINT pk_dimterritory PRIMARY KEY ("TerritoryKey");

ALTER TABLE dwh."DimShipMethod"
    DROP CONSTRAINT IF EXISTS pk_dimshipmethod CASCADE;
ALTER TABLE dwh."DimShipMethod"
    ADD CONSTRAINT pk_dimshipmethod PRIMARY KEY ("ShipMethodKey");

ALTER TABLE dwh."DimStore"
    DROP CONSTRAINT IF EXISTS pk_dimstore CASCADE;
ALTER TABLE dwh."DimStore"
    ADD CONSTRAINT pk_dimstore PRIMARY KEY ("StoreKey");

ALTER TABLE dwh."DimDate"
    DROP CONSTRAINT IF EXISTS pk_dimdate CASCADE;
ALTER TABLE dwh."DimDate"
    ADD CONSTRAINT pk_dimdate PRIMARY KEY ("DateKey");

ALTER TABLE dwh."FactSales"
    DROP CONSTRAINT IF EXISTS pk_factsales CASCADE;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT pk_factsales PRIMARY KEY ("FactSalesKey");

-- ==========================================================
-- STEP 2. Recreate indexes for performance (unchanged)
-- ==========================================================

-- DimCustomer indexes
CREATE INDEX IF NOT EXISTS ix_dimcustomer_customerid
    ON dwh."DimCustomer"("CustomerID");
CREATE INDEX IF NOT EXISTS ix_dimcustomer_startdate
    ON dwh."DimCustomer"("StartDate");
CREATE INDEX IF NOT EXISTS ix_dimcustomer_enddate
    ON dwh."DimCustomer"("EndDate");
CREATE UNIQUE INDEX IF NOT EXISTS ux_dimcustomer_customerid_current
    ON dwh."DimCustomer"("CustomerID")
    WHERE "EndDate" = '9999-12-31'::timestamp;

-- DimSalesReason indexes
CREATE INDEX IF NOT EXISTS ix_dimsalesreason_salesreasonid
    ON dwh."DimSalesReason"("SalesReasonID");
CREATE INDEX IF NOT EXISTS ix_dimsalesreason_startdate
    ON dwh."DimSalesReason"("StartDate");
CREATE INDEX IF NOT EXISTS ix_dimsalesreason_enddate
    ON dwh."DimSalesReason"("EndDate");
CREATE UNIQUE INDEX IF NOT EXISTS ix_dimsalesreason_composite_current
    ON dwh."DimSalesReason"("SalesOrderID", "SalesReasonID")
    WHERE "EndDate" = '9999-12-31'::timestamp;

-- DimPromotion indexes
CREATE INDEX IF NOT EXISTS ix_dimpromotion_specialofferid
    ON dwh."DimPromotion"("SpecialOfferID");
CREATE INDEX IF NOT EXISTS ix_dimpromotion_startdate
    ON dwh."DimPromotion"("StartDate");
CREATE INDEX IF NOT EXISTS ix_dimpromotion_enddate
    ON dwh."DimPromotion"("EndDate");
CREATE UNIQUE INDEX IF NOT EXISTS ux_dimpromotion_specialofferid_current
    ON dwh."DimPromotion"("SpecialOfferID")
    WHERE "EndDate" = '9999-12-31'::timestamp;

-- DimProduct indexes
CREATE INDEX IF NOT EXISTS ix_dimproduct_productid
    ON dwh."DimProduct"("ProductID");
CREATE INDEX IF NOT EXISTS ix_dimproduct_startdate
    ON dwh."DimProduct"("StartDate");
CREATE INDEX IF NOT EXISTS ix_dimproduct_enddate
    ON dwh."DimProduct"("EndDate");
CREATE UNIQUE INDEX IF NOT EXISTS ux_dimproduct_productid_current
    ON dwh."DimProduct"("ProductID")
    WHERE "EndDate" = '9999-12-31'::timestamp;

-- DimTerritory indexes
CREATE INDEX IF NOT EXISTS ix_dimterritory_territoryid
    ON dwh."DimTerritory"("TerritoryID");
CREATE INDEX IF NOT EXISTS ix_dimterritory_startdate
    ON dwh."DimTerritory"("StartDate");
CREATE INDEX IF NOT EXISTS ix_dimterritory_enddate
    ON dwh."DimTerritory"("EndDate");
CREATE UNIQUE INDEX IF NOT EXISTS ux_dimterritory_territoryid_current
    ON dwh."DimTerritory"("TerritoryID")
    WHERE "EndDate" = '9999-12-31'::timestamp;

-- DimShipMethod indexes
CREATE INDEX IF NOT EXISTS ix_dimshipmethod_shipmethodid
    ON dwh."DimShipMethod"("ShipMethodID");
CREATE INDEX IF NOT EXISTS ix_dimshipmethod_startdate
    ON dwh."DimShipMethod"("StartDate");
CREATE INDEX IF NOT EXISTS ix_dimshipmethod_enddate
    ON dwh."DimShipMethod"("EndDate");
CREATE UNIQUE INDEX IF NOT EXISTS ux_dimshipmethod_shipmethodid_current
    ON dwh."DimShipMethod"("ShipMethodID")
    WHERE "EndDate" = '9999-12-31'::timestamp;

-- DimStore indexes
CREATE INDEX IF NOT EXISTS ix_dimstore_storeid
    ON dwh."DimStore"("StoreID");
CREATE INDEX IF NOT EXISTS ix_dimstore_startdate
    ON dwh."DimStore"("StartDate");
CREATE INDEX IF NOT EXISTS ix_dimstore_enddate
    ON dwh."DimStore"("EndDate");
CREATE UNIQUE INDEX IF NOT EXISTS ux_dimstore_storeid_current
    ON dwh."DimStore"("StoreID")
    WHERE "EndDate" = '9999-12-31'::timestamp;

-- DimDate indexes
CREATE INDEX IF NOT EXISTS ix_dimdate_date
    ON dwh."DimDate"("Date");
CREATE INDEX IF NOT EXISTS ix_dimdate_year
    ON dwh."DimDate"("Year");
CREATE INDEX IF NOT EXISTS ix_dimdate_quarter
    ON dwh."DimDate"("Quarter");
CREATE INDEX IF NOT EXISTS ix_dimdate_month
    ON dwh."DimDate"("Month");

-- ==========================================================
-- STEP 3. Recreate all FACT foreign keys (now valid)
-- ==========================================================

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_product;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_product
    FOREIGN KEY ("ProductKey")
    REFERENCES dwh."DimProduct"("ProductKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_promotion;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_promotion
    FOREIGN KEY ("PromotionKey")
    REFERENCES dwh."DimPromotion"("PromotionKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_customer;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_customer
    FOREIGN KEY ("CustomerKey")
    REFERENCES dwh."DimCustomer"("CustomerKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_territory;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_territory
    FOREIGN KEY ("TerritoryKey")
    REFERENCES dwh."DimTerritory"("TerritoryKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_store;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_store
    FOREIGN KEY ("StoreKey")
    REFERENCES dwh."DimStore"("StoreKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_salesreason;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_salesreason
    FOREIGN KEY ("SalesReasonKey")
    REFERENCES dwh."DimSalesReason"("SalesReasonKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_shipmethod;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_shipmethod
    FOREIGN KEY ("ShipMethodKey")
    REFERENCES dwh."DimShipMethod"("ShipMethodKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_orderdate;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_orderdate
    FOREIGN KEY ("OrderDateKey")
    REFERENCES dwh."DimDate"("DateKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_duedate;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_duedate
    FOREIGN KEY ("DueDateKey")
    REFERENCES dwh."DimDate"("DateKey");

ALTER TABLE dwh."FactSales" DROP CONSTRAINT IF EXISTS fk_factsales_shipdate;
ALTER TABLE dwh."FactSales"
    ADD CONSTRAINT fk_factsales_shipdate
    FOREIGN KEY ("ShipDateKey")
    REFERENCES dwh."DimDate"("DateKey");
