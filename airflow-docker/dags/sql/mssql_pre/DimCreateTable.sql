-- T-SQL
USE CompanyX;
GO
SET NOCOUNT ON;

-- 1) Drop FKs that are on or reference dbo tables
DECLARE @sql NVARCHAR(MAX);

SELECT @sql =
    STRING_AGG(
        'ALTER TABLE ' + QUOTENAME(ps.name) + '.' + QUOTENAME(pt.name) +
        ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';'
    , CHAR(10))
FROM sys.foreign_keys AS fk
JOIN sys.tables AS pt          ON fk.parent_object_id     = pt.object_id
JOIN sys.schemas AS ps         ON pt.schema_id            = ps.schema_id
JOIN sys.tables AS rt          ON fk.referenced_object_id = rt.object_id
JOIN sys.schemas AS rs         ON rt.schema_id            = rs.schema_id
WHERE ps.name = 'dbo' OR rs.name = 'dbo';

IF @sql IS NOT NULL AND LEN(@sql) > 0
    EXEC sys.sp_executesql @sql;

-- 2) Drop all dbo tables
SET @sql = NULL;

SELECT @sql =
    STRING_AGG(
        'DROP TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';'
    , CHAR(10))
FROM sys.tables AS t
JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = 'dbo';

IF @sql IS NOT NULL AND LEN(@sql) > 0
    EXEC sys.sp_executesql @sql;

GO
CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    PersonType nchar(2),
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    EmailAddress nvarchar(50),
    AddressLine1 nvarchar(60),
    EmailPromotion tinyint,
    City nvarchar(30),
    ProvinceName nvarchar(50),
    CountryRegionName nvarchar(50),
    BirthDate datetime,
    CommuteDistance nvarchar(50),
    DateFirstPurchase datetime,
    Education nvarchar(30),
    Gender nvarchar(2),
    HomeOwnerFlag BIT,
    MaritalStatus nvarchar(2),
    NumberCarsOwned int,
    NumberChildrenAtHome int,
    Occupation nvarchar(30),
    TotalChildren int,
    TotalPurchaseYTD float,
    YearlyIncome nvarchar(40),
    ModifiedDate datetime
);


GO
CREATE TABLE DimSalesReason (
    ReasonKey INT IDENTITY(1,1) PRIMARY KEY,
    SalesOrderID int not null,
    SalesReasonID INT NOT NULL,
    Name nvarchar(100),
    ReasonType nvarchar(100),
    ModifiedDate datetime
);


GO
CREATE TABLE DimPromotion(
    PromotionKey INT IDENTITY(1,1) PRIMARY KEY,
    SpecialOfferID INT NOT NULL,
    Description nvarchar(255),
    Type nvarchar(50),
    Category nvarchar(50),
    DiscountPct decimal(9,4),
    StartDate datetime,
    EndDate datetime,
    MinQty INT,
    MaxQty INT,
    ModifiedDate datetime
);


GO
CREATE TABLE DimProduct(
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    Name nvarchar(200),
    Color nvarchar(15),
    Size nvarchar(5),
    Weight decimal(8,2),
    Style nchar(2),
    ModelName nvarchar(50),
    CategoryName nvarchar(50),
    SubCategoryName nvarchar (50),
    StandardCost decimal(19,4),
    ListPrice decimal(19,4),
    WarrantyPeriod nvarchar(50),
    NoOfYears nvarchar(20),
    ModifiedDate datetime 
)

GO
CREATE TABLE DimTerritory
(
    Territory_key     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- surrogate key
    [Name]            NVARCHAR(100)     NULL,
    CountryRegionName NVARCHAR(100)     NULL,
    [Group]           NVARCHAR(50)      NULL,
    SalesYTD          DECIMAL(19,4)     NULL,
    SalesLastYear     DECIMAL(19,4)     NULL,
    CostYTD           DECIMAL(19,4)     NULL,
    CostLastYear      DECIMAL(19,4)     NULL,
    TerritoryID       INT               NOT NULL,
    ModifiedDate      datetime 
);

-- Optional: keep one row per TerritoryID
CREATE UNIQUE INDEX UX_Dim_Territory_TerritoryID ON DimTerritory(TerritoryID);

/* Checked below */
GO
CREATE TABLE DimShipMethod
(
    ShipMethod_key   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ShipMethodID     INT              NOT NULL,
    [Name]           NVARCHAR(50)     NULL,
    ShipBase         DECIMAL(19,4)    NULL,
    ShipDate         DATE             NULL,
    ModifiedDate     datetime
);
-- Optional: enforce uniqueness on natural key
CREATE UNIQUE INDEX UX_Dim_ShipMethod_ShipMethodID ON DimShipMethod(ShipMethodID);

GO
CREATE TABLE DimStore
(
    Store_key           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    StoreID             int                Not null,
    [Name]              NVARCHAR(100)      NULL,
    AnnualSales         DECIMAL(18,2)      NULL,
    AnnualRevenue       DECIMAL(18,2)      NULL,
    BusinessType        NVARCHAR(30)       NULL,
    BankName            NVARCHAR(100)      NULL,
    YearOpened          INT                NULL,
    Specialty           NVARCHAR(100)      NULL,
    SquareFeet          INT                NULL,
    Brands              INT                NULL,
    Internet            NVARCHAR(30)       NULL,
    NumberEmployees     INT                NULL,
    AddressType         NVARCHAR(50)       NULL,
    AddressLine1        NVARCHAR(60)       NULL,
    AddressLine2        NVARCHAR(60)       NULL,
    City                NVARCHAR(30)       NULL,
    StateProvinceName   NVARCHAR(50)       NULL,
    CountryRegionName   NVARCHAR(50)       NULL,
    ModifiedDate        datetime           NULL
);

GO
CREATE TABLE FactSale (
    FactSaleKey INT IDENTITY(1,1) PRIMARY KEY,
    DateKey             int,
    ProductKey      int       NOT NULL,
    PromotionKey       int       NOT NULL,
    CustomerKey        int       NOT NULL,
    TerritoryKey int NOT NULL,
    StoreKey int,
    SaleReasonKey int,

    SalesOrderID       int       NOT NULL,
    SalesOrderDetail   int       NOT NULL,

    OrderQty int,
    UnitPrice          money,
    UnitPriceDiscount  money     NOT NULL,
    OrderDate datetime,
    DueDate datetime,
    ShipDate datetime,
    Status int,
    OnlineOrderFlag bit,
    TaxAllocated money,
    Freight_Allocated money,
    TotalDueTime money,
    LineAmountSource int,
    SalesInfoModifiedDate datetime,
    LineAmount_Gross float,
    LineDiscountAmount float,
    LineAmount_Net float,
    TotalDue_Line float
);
