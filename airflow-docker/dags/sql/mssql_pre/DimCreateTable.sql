-- T-SQL
USE CompanyX;

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


-- Create dimension tables
CREATE TABLE DimCustomer (
    CustomerKey         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CustomerID          INT                NOT NULL,
    PersonType          NVARCHAR(2)        NULL,
    FirstName           NVARCHAR(50)       NULL,
    LastName            NVARCHAR(50)       NULL,
    EmailAddress        NVARCHAR(50)       NULL,
    EmailPromotion      INT                NULL,
    AddressLine1        NVARCHAR(60)       NULL,
    City                NVARCHAR(30)       NULL,
    StateProvinceName   NVARCHAR(50)       NULL,
    CountryRegionName   NVARCHAR(50)       NULL,
    BirthDate           DATETIME           NULL,
    MaritalStatus       NVARCHAR(1)        NULL,
    Gender              NVARCHAR(1)        NULL,
    Education           NVARCHAR(40)       NULL,
    Occupation          NVARCHAR(100)      NULL,
    HomeOwnerFlag       BIT                NULL,
    NumberCarsOwned     INT                NULL,
    NumberChildrenAtHome INT               NULL,
    TotalChildren       INT                NULL,
    TotalPurchaseYTD    MONEY              NULL,
    YearlyIncome        NVARCHAR(50)       NULL,
    DateFirstPurchase   DATETIME           NULL,
    StartDate           DATETIME           NOT NULL,
    EndDate             DATETIME           NOT NULL DEFAULT '9999-12-31'
);

CREATE TABLE DimSalesReason (
    SalesReasonKey      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SalesOrderID        INT                NOT NULL,
    SalesReasonID       INT                NOT NULL,
    Name                NVARCHAR(50)       NULL,
    ReasonType          NVARCHAR(50)       NULL,
    StartDate           DATETIME           NOT NULL,
    EndDate             DATETIME           NOT NULL DEFAULT '9999-12-31'
);

CREATE TABLE DimPromotion (
    PromotionKey        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SpecialOfferID      INT                NOT NULL,
    Description         NVARCHAR(255)      NULL,
    Type                NVARCHAR(50)       NULL,
    Category            NVARCHAR(50)       NULL,
    DiscountPct         SMALLMONEY         NULL,
    StartDate           DATETIME           NOT NULL,
    EndDate             DATETIME           NOT NULL DEFAULT '9999-12-31',
    MinQty              INT                NULL,
    MaxQty              INT                NULL
);

CREATE TABLE DimProduct (
    ProductKey          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProductID           INT                NOT NULL,
    Name                NVARCHAR(50)       NULL,
    Color               NVARCHAR(15)       NULL,
    Size                NVARCHAR(5)        NULL,
    Weight              DECIMAL(8,2)       NULL,
    Style               NVARCHAR(2)        NULL,
    ModelName           NVARCHAR(50)       NULL,
    CategoryName        NVARCHAR(50)       NULL,
    SubCategoryName     NVARCHAR(50)       NULL,
    StandardCost        MONEY              NULL,
    ListPrice           MONEY              NULL,
    WarrantyPeriod      NVARCHAR(50)       NULL,
    NoOfYears           NVARCHAR(50)       NULL,
    StartDate           DATETIME           NOT NULL,
    EndDate             DATETIME           NOT NULL DEFAULT '9999-12-31'
);

CREATE TABLE DimTerritory (
    TerritoryKey        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TerritoryID         INT                NOT NULL,
    Name                NVARCHAR(50)       NULL,
    CountryRegionName   NVARCHAR(50)       NULL,
    [Group]             NVARCHAR(50)       NULL,
    SalesYTD            DECIMAL(19,4)      NULL,
    SalesLastYear       DECIMAL(19,4)      NULL,
    CostYTD             DECIMAL(19,4)      NULL,
    CostLastYear        DECIMAL(19,4)      NULL,
    StartDate           DATETIME           NOT NULL,
    EndDate             DATETIME           NOT NULL DEFAULT '9999-12-31'
);

CREATE TABLE DimShipMethod (
    ShipMethodKey       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ShipMethodID        INT                NOT NULL,
    Name                NVARCHAR(50)       NULL,
    ShipBase            MONEY              NULL,
    ShipRate            MONEY              NULL,
    ShipDate            DATETIME           NULL,
    StartDate           DATETIME           NOT NULL,
    EndDate             DATETIME           NOT NULL DEFAULT '9999-12-31'
);

CREATE TABLE DimStore (
    StoreKey            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    StoreID             INT                NOT NULL,
    Name                NVARCHAR(50)       NULL,
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
    StartDate           DATETIME           NOT NULL,
    EndDate             DATETIME           NOT NULL DEFAULT '9999-12-31'
);

CREATE TABLE DimDate
(
    [DateKey] INT PRIMARY KEY,
    [Date] DATETIME,
    [FullDate] CHAR(10),
    [DayOfMonth] VARCHAR(2),
    [DaySuffix] VARCHAR(4),
    [DayName] VARCHAR(9),
    [DayOfWeek] CHAR(1),
    [DayOfWeekInMonth] VARCHAR(2),
    [DayOfWeekInYear] VARCHAR(2),
    [DayOfQuarter] VARCHAR(3),
    [DayOfYear] VARCHAR(3),
    [WeekOfMonth] VARCHAR(1),
    [WeekOfQuarter] VARCHAR(2),
    [WeekOfYear] VARCHAR(2),
    [Month] VARCHAR(2),
    [MonthName] VARCHAR(9),
    [MonthOfQuarter] VARCHAR(2),
    [Quarter] CHAR(1),
    [QuarterName] VARCHAR(9),
    [Year] CHAR(4),
    [YearName] CHAR(7),
    [MonthYear] CHAR(10),
    [MMYYYY] CHAR(6),
    [FirstDayOfMonth] DATE,
    [LastDayOfMonth] DATE,
    [FirstDayOfQuarter] DATE,
    [LastDayOfQuarter] DATE,
    [FirstDayOfYear] DATE,
    [LastDayOfYear] DATE,
    [IsHoliday] BIT,
    [IsWeekday] BIT,
    [HolidayName] VARCHAR(50)
);

-- Create fact table (without FKs - they're added after indexes)
CREATE TABLE FactSales (
    FactSalesKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProductKey      INT       NOT NULL,
    PromotionKey    INT       NOT NULL,
    CustomerKey     INT       NOT NULL,
    TerritoryKey    INT       NOT NULL,
    StoreKey        INT       NULL,
    SalesReasonKey   INT       NULL,
    ShipMethodKey   INT       NULL,

    SalesOrderID       INT       NOT NULL,
    SalesOrderDetail   INT       NOT NULL,

    OrderQty           INT       NULL,
    UnitPrice          MONEY     NULL,
    UnitPriceDiscount  MONEY     NOT NULL,
    OrderDateKey       INT       NULL,
    DueDateKey         INT       NULL,
    ShipDateKey        INT       NULL,
    Status             INT       NULL,
    OnlineOrderFlag    BIT       NULL,
    TaxAllocated       MONEY     NULL,
    Freight_Allocated  MONEY     NULL,
    TotalDueTime       MONEY     NULL,
    LineAmountSource   INT       NULL,
    SalesInfoModifiedDate DATETIME NULL,
    LineAmount_Gross   FLOAT     NULL,
    LineDiscountAmount FLOAT     NULL,
    LineAmount_Net     FLOAT     NULL,
    TotalDue_Line      FLOAT     NULL
);
