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


CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    PersonType nchar(2),
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    EmailAddress NVARCHAR(50),
    AddressLine1 NVARCHAR(60),
    EmailPromotion tinyint,
    City NVARCHAR(30),
    StateProvinceName NVARCHAR(50),
    CountryRegionName NVARCHAR(50),
    BirthDate datetime,
    MaritalStatus NVARCHAR(2),
    Gender NVARCHAR(2),
    Education NVARCHAR(30),
    Occupation NVARCHAR(30),
    HomeOwnerFlag BIT,
    NumberCarsOwned INT,
    NumberChildrenAtHome INT,
    TotalChildren INT,
    TotalPurchaseYTD money,
    YearlyIncome NVARCHAR(40),
    DateFirstPurchase datetime,
    ModifiedDate datetime DEFAULT GETDATE()
);

CREATE TABLE DimSalesReason (
    ReasonKey INT IDENTITY(1,1) PRIMARY KEY,
    SalesOrderID int not null,
    SalesReasonID INT NOT NULL,
    Name nvarchar(100),
    ReasonType nvarchar(100),
    ModifiedDate datetime
);


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


CREATE TABLE DimTerritory
(
    TerritoryKey     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- surrogate key
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

CREATE TABLE DimShipMethod
(
    ShipMethodKey   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ShipMethodID     INT              NOT NULL,
    [Name]           NVARCHAR(50)     NULL,
    ShipBase         DECIMAL(19,4)    NULL,
    ShipDate         DATE             NULL,
    ModifiedDate     datetime
);
-- Optional: enforce uniqueness on natural key
CREATE UNIQUE INDEX UX_Dim_ShipMethod_ShipMethodID ON DimShipMethod(ShipMethodID);


CREATE TABLE DimStore
(
    StoreKey           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
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

CREATE TABLE DimDate
(
    [DateKey] INT primary key,
    [Date] DATETIME,
    [FullDate] CHAR(10),-- Date in MM-dd-yyyy format
    [DayOfMonth] VARCHAR(2), -- Field will hold day number of Month
    [DaySuffix] VARCHAR(4), -- Apply suffix as 1st, 2nd ,3rd etc
    [DayName] VARCHAR(9), -- Contains name of the day, Sunday, Monday
    [DayOfWeek] CHAR(1),-- First Day Sunday=1 and Saturday=7
    [DayOfWeekInMonth] VARCHAR(2), --1st Monday or 2nd Monday in Month
    [DayOfWeekInYear] VARCHAR(2),
    [DayOfQuarter] VARCHAR(3),
    [DayOfYear] VARCHAR(3),
    [WeekOfMonth] VARCHAR(1),-- Week Number of Month
    [WeekOfQuarter] VARCHAR(2), --Week Number of the Quarter
    [WeekOfYear] VARCHAR(2),--Week Number of the Year
    [Month] VARCHAR(2), --Number of the Month 1 to 12
    [MonthName] VARCHAR(9),--January, February etc
    [MonthOfQuarter] VARCHAR(2),-- Month Number belongs to Quarter
    [Quarter] CHAR(1),
    [QuarterName] VARCHAR(9),--First,Second..
    [Year] CHAR(4),-- Year value of Date stored in Row
    [YearName] CHAR(7), --CY 2012,CY 2013
    [MonthYear] CHAR(10), --Jan-2013,Feb-2013
    [MMYYYY] CHAR(6),
    [FirstDayOfMonth] DATE,
    [LastDayOfMonth] DATE,
    [FirstDayOfQuarter] DATE,
    [LastDayOfQuarter] DATE,
    [FirstDayOfYear] DATE,
    [LastDayOfYear] DATE,
    [IsHoliday] BIT,-- Flag 1=National Holiday, 0-No National Holiday
    [IsWeekday] BIT,-- 0=Week End ,1=Week Day
    [HolidayName] VARCHAR(50),--Name of Holiday in US
)

CREATE TABLE FactSales (
    FactSaleKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductKey      int       NOT NULL,
    PromotionKey       int       NOT NULL,
    CustomerKey        int       NOT NULL,
    TerritoryKey int NOT NULL,
    StoreKey int,
    SaleReasonKey int,
    ShipMethodKey int,

    SalesOrderID       int       NOT NULL,
    SalesOrderDetail   int       NOT NULL,

    OrderQty int,
    UnitPrice          money,
    UnitPriceDiscount  money     NOT NULL,
    OrderDateKey int,
    DueDateKey int,
    ShipDateKey int,
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
    TotalDue_Line float,

    Foreign key (ProductKey) references CompanyX.dbo.DimProduct (ProductKey) ON DELETE CASCADE ON UPDATE CASCADE,
    Foreign key (PromotionKey) references CompanyX.dbo.DimPromotion (PromotionKey) ON DELETE CASCADE ON UPDATE CASCADE,
    Foreign key (CustomerKey) references CompanyX.dbo.DimCustomer (CustomerKey) ON DELETE CASCADE ON UPDATE CASCADE,
    Foreign key (TerritoryKey) references CompanyX.dbo.DimTerritory (TerritoryKey) ON DELETE CASCADE ON UPDATE CASCADE,
    Foreign key (StoreKey) references CompanyX.dbo.DimStore (StoreKey) ON DELETE CASCADE ON UPDATE CASCADE,
    Foreign key (SaleReasonKey) references CompanyX.dbo.DimSalesReason (ReasonKey) ON DELETE CASCADE ON UPDATE CASCADE,
    Foreign key (ShipMethodKey) references CompanyX.dbo.DimShipMethod (ShipMethodKey) ON DELETE CASCADE ON UPDATE CASCADE
);