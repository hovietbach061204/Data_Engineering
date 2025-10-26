-- airflow-docker/dags/sql/mssql_pre/create_incremental_indexes.sql
-- Create indexes on ModifiedDate columns for incremental loading
-- These indexes optimize the watermark-based queries in check_updates_* files

USE CompanyX;
GO

-- ============================================================
-- Indexes for DimCustomer
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Customer_ModifiedDate' AND object_id = OBJECT_ID('Sales.Customer'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Customer_ModifiedDate
    ON Sales.Customer(ModifiedDate);
    PRINT '✓ Created IX_Customer_ModifiedDate';
END
ELSE
    PRINT '→ IX_Customer_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Person_ModifiedDate' AND object_id = OBJECT_ID('Person.Person'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Person_ModifiedDate
    ON Person.Person(ModifiedDate);
    PRINT '✓ Created IX_Person_ModifiedDate';
END
ELSE
    PRINT '→ IX_Person_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EmailAddress_ModifiedDate' AND object_id = OBJECT_ID('Person.EmailAddress'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_EmailAddress_ModifiedDate
    ON Person.EmailAddress(ModifiedDate);
    PRINT '✓ Created IX_EmailAddress_ModifiedDate';
END
ELSE
    PRINT '→ IX_EmailAddress_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Address_ModifiedDate' AND object_id = OBJECT_ID('Person.Address'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Address_ModifiedDate
    ON Person.Address(ModifiedDate);
    PRINT '✓ Created IX_Address_ModifiedDate';
END
ELSE
    PRINT '→ IX_Address_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateProvince_ModifiedDate' AND object_id = OBJECT_ID('Person.StateProvince'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_StateProvince_ModifiedDate
    ON Person.StateProvince(ModifiedDate);
    PRINT '✓ Created IX_StateProvince_ModifiedDate';
END
ELSE
    PRINT '→ IX_StateProvince_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CountryRegion_ModifiedDate' AND object_id = OBJECT_ID('Person.CountryRegion'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_CountryRegion_ModifiedDate
    ON Person.CountryRegion(ModifiedDate);
    PRINT '✓ Created IX_CountryRegion_ModifiedDate';
END
ELSE
    PRINT '→ IX_CountryRegion_ModifiedDate already exists';
GO

-- ============================================================
-- Indexes for DimProduct
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Product_ModifiedDate' AND object_id = OBJECT_ID('Production.Product'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Product_ModifiedDate
    ON Production.Product(ModifiedDate);
    PRINT '✓ Created IX_Product_ModifiedDate';
END
ELSE
    PRINT '→ IX_Product_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProductModel_ModifiedDate' AND object_id = OBJECT_ID('Production.ProductModel'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ProductModel_ModifiedDate
    ON Production.ProductModel(ModifiedDate);
    PRINT '✓ Created IX_ProductModel_ModifiedDate';
END
ELSE
    PRINT '→ IX_ProductModel_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProductCategory_ModifiedDate' AND object_id = OBJECT_ID('Production.ProductCategory'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ProductCategory_ModifiedDate
    ON Production.ProductCategory(ModifiedDate);
    PRINT '✓ Created IX_ProductCategory_ModifiedDate';
END
ELSE
    PRINT '→ IX_ProductCategory_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProductSubcategory_ModifiedDate' AND object_id = OBJECT_ID('Production.ProductSubcategory'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ProductSubcategory_ModifiedDate
    ON Production.ProductSubcategory(ModifiedDate);
    PRINT '✓ Created IX_ProductSubcategory_ModifiedDate';
END
ELSE
    PRINT '→ IX_ProductSubcategory_ModifiedDate already exists';
GO

-- ============================================================
-- Indexes for DimPromotion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SpecialOffer_ModifiedDate' AND object_id = OBJECT_ID('Sales.SpecialOffer'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SpecialOffer_ModifiedDate
    ON Sales.SpecialOffer(ModifiedDate);
    PRINT '✓ Created IX_SpecialOffer_ModifiedDate';
END
ELSE
    PRINT '→ IX_SpecialOffer_ModifiedDate already exists';
GO

-- ============================================================
-- Indexes for DimSalesReason
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesReason_ModifiedDate' AND object_id = OBJECT_ID('Sales.SalesReason'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SalesReason_ModifiedDate
    ON Sales.SalesReason(ModifiedDate);
    PRINT '✓ Created IX_SalesReason_ModifiedDate';
END
ELSE
    PRINT '→ IX_SalesReason_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrderHeaderSalesReason_ModifiedDate' AND object_id = OBJECT_ID('Sales.SalesOrderHeaderSalesReason'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SalesOrderHeaderSalesReason_ModifiedDate
    ON Sales.SalesOrderHeaderSalesReason(ModifiedDate);
    PRINT '✓ Created IX_SalesOrderHeaderSalesReason_ModifiedDate';
END
ELSE
    PRINT '→ IX_SalesOrderHeaderSalesReason_ModifiedDate already exists';
GO

-- ============================================================
-- Indexes for DimShipMethod
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ShipMethod_ModifiedDate' AND object_id = OBJECT_ID('Purchasing.ShipMethod'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ShipMethod_ModifiedDate
    ON Purchasing.ShipMethod(ModifiedDate);
    PRINT '✓ Created IX_ShipMethod_ModifiedDate';
END
ELSE
    PRINT '→ IX_ShipMethod_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrderHeader_ModifiedDate' AND object_id = OBJECT_ID('Sales.SalesOrderHeader'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_ModifiedDate
    ON Sales.SalesOrderHeader(ModifiedDate);
    PRINT '✓ Created IX_SalesOrderHeader_ModifiedDate';
END
ELSE
    PRINT '→ IX_SalesOrderHeader_ModifiedDate already exists';
GO

-- ============================================================
-- Indexes for DimStore
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Store_ModifiedDate' AND object_id = OBJECT_ID('Sales.Store'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Store_ModifiedDate
    ON Sales.Store(ModifiedDate);
    PRINT '✓ Created IX_Store_ModifiedDate';
END
ELSE
    PRINT '→ IX_Store_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BusinessEntityAddress_ModifiedDate' AND object_id = OBJECT_ID('Person.BusinessEntityAddress'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_BusinessEntityAddress_ModifiedDate
    ON Person.BusinessEntityAddress(ModifiedDate);
    PRINT '✓ Created IX_BusinessEntityAddress_ModifiedDate';
END
ELSE
    PRINT '→ IX_BusinessEntityAddress_ModifiedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AddressType_ModifiedDate' AND object_id = OBJECT_ID('Person.AddressType'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_AddressType_ModifiedDate
    ON Person.AddressType(ModifiedDate);
    PRINT '✓ Created IX_AddressType_ModifiedDate';
END
ELSE
    PRINT '→ IX_AddressType_ModifiedDate already exists';
GO

-- ============================================================
-- Indexes for DimTerritory
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesTerritory_ModifiedDate' AND object_id = OBJECT_ID('Sales.SalesTerritory'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SalesTerritory_ModifiedDate
    ON Sales.SalesTerritory(ModifiedDate);
    PRINT '✓ Created IX_SalesTerritory_ModifiedDate';
END
ELSE
    PRINT '→ IX_SalesTerritory_ModifiedDate already exists';
GO

PRINT '';
PRINT '========================================';
PRINT 'All incremental loading indexes created';
PRINT '========================================';
