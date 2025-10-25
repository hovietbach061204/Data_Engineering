-- T-SQL
USE CompanyX;

SET NOCOUNT ON;

-- ============================================
-- Create indexes on dimension tables
-- ============================================

-- DimCustomer indexes
CREATE INDEX IX_DimCustomer_CustomerID ON DimCustomer(CustomerID);
CREATE INDEX IX_DimCustomer_StartDate ON DimCustomer(StartDate);
CREATE INDEX IX_DimCustomer_EndDate ON DimCustomer(EndDate);
CREATE UNIQUE INDEX UX_DimCustomer_CustomerID_Current
    ON DimCustomer(CustomerID)
    WHERE EndDate = '9999-12-31';

-- DimSalesReason indexes
CREATE INDEX IX_DimSalesReason_SalesReasonID ON DimSalesReason(SalesReasonID);
CREATE INDEX IX_DimSalesReason_StartDate ON DimSalesReason(StartDate);
CREATE INDEX IX_DimSalesReason_EndDate ON DimSalesReason(EndDate);
CREATE UNIQUE INDEX UX_DimSalesReason_Composite_Current
    ON DimSalesReason(SalesOrderID, SalesReasonID)
    WHERE EndDate = '9999-12-31';

-- DimPromotion indexes
CREATE INDEX IX_DimPromotion_SpecialOfferID ON DimPromotion(SpecialOfferID);
CREATE INDEX IX_DimPromotion_StartDate ON DimPromotion(StartDate);
CREATE INDEX IX_DimPromotion_EndDate ON DimPromotion(EndDate);
CREATE UNIQUE INDEX UX_DimPromotion_SpecialOfferID_Current
    ON DimPromotion(SpecialOfferID)
    WHERE EndDate = '9999-12-31';

-- DimProduct indexes
CREATE INDEX IX_DimProduct_ProductID ON DimProduct(ProductID);
CREATE INDEX IX_DimProduct_StartDate ON DimProduct(StartDate);
CREATE INDEX IX_DimProduct_EndDate ON DimProduct(EndDate);
CREATE UNIQUE INDEX UX_DimProduct_ProductID_Current
    ON DimProduct(ProductID)
    WHERE EndDate = '9999-12-31';

-- DimTerritory indexes
CREATE INDEX IX_DimTerritory_TerritoryID ON DimTerritory(TerritoryID);
CREATE INDEX IX_DimTerritory_StartDate ON DimTerritory(StartDate);
CREATE INDEX IX_DimTerritory_EndDate ON DimTerritory(EndDate);
CREATE UNIQUE INDEX UX_DimTerritory_TerritoryID_Current
    ON DimTerritory(TerritoryID)
    WHERE EndDate = '9999-12-31';

-- DimShipMethod indexes
CREATE INDEX IX_DimShipMethod_ShipMethodID ON DimShipMethod(ShipMethodID);
CREATE INDEX IX_DimShipMethod_StartDate ON DimShipMethod(StartDate);
CREATE INDEX IX_DimShipMethod_EndDate ON DimShipMethod(EndDate);
CREATE UNIQUE INDEX UX_DimShipMethod_ShipMethodID_Current
    ON DimShipMethod(ShipMethodID)
    WHERE EndDate = '9999-12-31';

-- DimStore indexes
CREATE INDEX IX_DimStore_StoreID ON DimStore(StoreID);
CREATE INDEX IX_DimStore_StartDate ON DimStore(StartDate);
CREATE INDEX IX_DimStore_EndDate ON DimStore(EndDate);
CREATE UNIQUE INDEX UX_DimStore_StoreID_Current
    ON DimStore(StoreID)
    WHERE EndDate = '9999-12-31';

-- ============================================
-- Create foreign keys on FactSales
-- ============================================

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_Product
    FOREIGN KEY (ProductKey)
    REFERENCES DimProduct (ProductKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_Promotion
    FOREIGN KEY (PromotionKey)
    REFERENCES DimPromotion (PromotionKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_Customer
    FOREIGN KEY (CustomerKey)
    REFERENCES DimCustomer (CustomerKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_Territory
    FOREIGN KEY (TerritoryKey)
    REFERENCES DimTerritory (TerritoryKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_Store
    FOREIGN KEY (StoreKey)
    REFERENCES DimStore (StoreKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_SalesReason
    FOREIGN KEY (SalesReasonKey)
    REFERENCES DimSalesReason (SalesReasonKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_ShipMethod
    FOREIGN KEY (ShipMethodKey)
    REFERENCES DimShipMethod (ShipMethodKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE FactSales
    ADD CONSTRAINT FK_FactSales_OrderDate
    FOREIGN KEY (OrderDateKey)
    REFERENCES DimDate (DateKey)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- ALTER TABLE FactSales
--     ADD CONSTRAINT FK_FactSales_DueDate
--     FOREIGN KEY (DueDateKey)
--     REFERENCES DimDate (DateKey)
--     ON DELETE CASCADE
--     ON UPDATE CASCADE;
--
-- ALTER TABLE FactSales
--     ADD CONSTRAINT FK_FactSales_ShipDate
--     FOREIGN KEY (ShipDateKey)
--     REFERENCES DimDate (DateKey)
--     ON DELETE CASCADE
--     ON UPDATE CASCADE;


-- -- 1) Drop current PK (whatever its name is)
-- DECLARE @pk sysname;
-- SELECT @pk = kc.name
-- FROM sys.key_constraints kc
-- WHERE kc.parent_object_id = OBJECT_ID('dbo.FactSales')
--   AND kc.type = 'PK';
--
-- -- IF @pk IS NOT NULL
-- --     EXEC('ALTER TABLE dbo.FactSales DROP CONSTRAINT ' + QUOTENAME(@pk) + ';');
--
-- -- 2) Ensure all PK columns are NOT NULL (no-ops if already NOT NULL)
-- ALTER TABLE dbo.FactSales ALTER COLUMN SalesOrderID     INT NOT NULL;
-- ALTER TABLE dbo.FactSales ALTER COLUMN SalesOrderDetail INT NOT NULL;
-- ALTER TABLE dbo.FactSales ALTER COLUMN ProductKey       INT NOT NULL;
-- ALTER TABLE dbo.FactSales ALTER COLUMN PromotionKey     INT NOT NULL;
-- ALTER TABLE dbo.FactSales ALTER COLUMN CustomerKey      INT NOT NULL;
-- ALTER TABLE dbo.FactSales ALTER COLUMN TerritoryKey     INT NOT NULL;
-- -- ALTER TABLE dbo.FactSales ALTER COLUMN StoreKey         INT NOT NULL;
-- -- ALTER TABLE dbo.FactSales ALTER COLUMN SalesReasonKey   INT NOT NULL;
-- -- ALTER TABLE dbo.FactSales ALTER COLUMN ShipMethodKey    INT NOT NULL;
--
-- -- 3) Safety check: fail fast if duplicates exist on the full grain
-- IF EXISTS (
--     SELECT 1
--     FROM dbo.FactSales
--     GROUP BY
--         SalesOrderID, SalesOrderDetail,
--         ProductKey, PromotionKey, CustomerKey,
--         TerritoryKey
-- --              , StoreKey, SalesReasonKey, ShipMethodKey
--     HAVING COUNT(*) > 1
-- )
--     THROW 51001, 'Duplicate rows exist for the full FK+order grain; cannot create composite PK.', 1;
--
-- -- 4) Create the composite PRIMARY KEY (clustered by order/detail first)
-- ALTER TABLE dbo.FactSales
-- ADD CONSTRAINT PK_FactSales_FullGrain
-- PRIMARY KEY CLUSTERED (
--     SalesOrderID, SalesOrderDetail,       -- driving query filters
--     ProductKey, PromotionKey, CustomerKey,
--     TerritoryKey
-- --     , StoreKey, SalesReasonKey, ShipMethodKey
-- );
