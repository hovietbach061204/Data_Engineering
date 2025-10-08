/* =======================================================================
   STEP 1 – Final version (namespace + safe conversion)
   ======================================================================= */

IF OBJECT_ID('dbo.ExtractedStoreDemographic') IS NOT NULL
    DROP TABLE dbo.ExtractedStoreDemographic;
GO

CREATE TABLE dbo.ExtractedStoreDemographic
(
    BusinessEntityID  INT           NOT NULL,
    AnnualSales       DECIMAL(18,2) NULL,
    AnnualRevenue     DECIMAL(18,2) NULL,
    BankName          NVARCHAR(100) NULL,
    BusinessType      NVARCHAR(30)  NULL,
    YearOpened        INT           NULL,
    Specialty         NVARCHAR(100) NULL,
    SquareFeet        INT           NULL,
    Brands            INT           NULL,
    Internet          NVARCHAR(30)  NULL,
    NumberEmployees   INT           NULL
);
GO

;WITH StoreXML AS
(
    SELECT 
        s.BusinessEntityID,
        s.[Name],
        s.Demographics AS DemXML
    FROM CompanyX.Sales.Store AS s
    WHERE s.Demographics IS NOT NULL
)
INSERT INTO dbo.ExtractedStoreDemographic
(
    BusinessEntityID, AnnualSales, AnnualRevenue, BankName, BusinessType,
    YearOpened, Specialty, SquareFeet, Brands, Internet, NumberEmployees
)
SELECT
    sx.BusinessEntityID,

    -- ✅ Decimal fields: read as float then convert
    TRY_CONVERT(DECIMAL(18,2), sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/AnnualSales)[1]', 'float')),
    TRY_CONVERT(DECIMAL(18,2), sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/AnnualRevenue)[1]', 'float')),

    -- ✅ String fields
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/BankName)[1]', 'nvarchar(100)'),
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/BusinessType)[1]', 'nvarchar(30)'),

    -- ✅ Int fields: read as NVARCHAR first, then TRY_CONVERT to handle bad data like "4+"
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/YearOpened)[1]', 'nvarchar(100)')),
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/Specialty)[1]', 'nvarchar(100)'),
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/SquareFeet)[1]', 'nvarchar(100)')),
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/Brands)[1]', 'nvarchar(100)')),
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/Internet)[1]', 'nvarchar(30)'),
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/NumberEmployees)[1]', 'nvarchar(100)'))
FROM StoreXML sx;
GO



-------------------------------------------------------
-- Clean staging if re-running
IF OBJECT_ID('dbo.StoreAddressMap') IS NOT NULL DROP TABLE dbo.StoreAddressMap;
IF OBJECT_ID('dbo.StoreAddressResolved') IS NOT NULL DROP TABLE dbo.StoreAddressResolved;
GO

;WITH StoreBase AS
(
    SELECT s.BusinessEntityID, s.[Name]
    FROM CompanyX.Sales.Store AS s
),
AddrRanked AS
(
    SELECT
        bea.BusinessEntityID,
        bea.AddressID,
        atp.[Name] AS AddressType,
        ROW_NUMBER() OVER
        (
            PARTITION BY bea.BusinessEntityID
            ORDER BY CASE
                        WHEN UPPER(LTRIM(RTRIM(atp.[Name]))) = N'MAIN OFFICE' THEN 1
                        WHEN UPPER(LTRIM(RTRIM(atp.[Name]))) = N'SHIPPING'    THEN 2
                        ELSE 9
                     END,
                     bea.AddressID
        ) AS rn
    FROM CompanyX.Person.BusinessEntityAddress AS bea
    INNER JOIN CompanyX.Person.AddressType AS atp
        ON atp.AddressTypeID = bea.AddressTypeID
    INNER JOIN StoreBase sb
        ON sb.BusinessEntityID = bea.BusinessEntityID
)
SELECT
    BusinessEntityID,
    AddressID,
    AddressType,
    rn
INTO dbo.StoreAddressMap
FROM AddrRanked;
GO

;WITH Chosen AS
(
SELECT BusinessEntityID, AddressID, AddressType
    FROM dbo.StoreAddressMap
    WHERE UPPER(LTRIM(RTRIM(AddressType))) IN (N'MAIN OFFICE', N'SHIPPING')
),
Geo AS
(
    SELECT
        a.AddressID,
        a.AddressLine1,
        a.AddressLine2,
        a.City,
        sp.[Name] AS StateProvinceName,
        cr.[Name] AS CountryRegionName
    FROM CompanyX.Person.Address AS a
    LEFT JOIN CompanyX.Person.StateProvince  AS sp ON sp.StateProvinceID  = a.StateProvinceID
    LEFT JOIN CompanyX.Person.CountryRegion  AS cr ON cr.CountryRegionCode = sp.CountryRegionCode
)
SELECT
    c.BusinessEntityID,
    c.AddressType,
    g.AddressLine1,
    g.AddressLine2,
    g.City,
    g.StateProvinceName,
    g.CountryRegionName
INTO dbo.StoreAddressResolved
FROM Chosen c
LEFT JOIN Geo g
       ON g.AddressID = c.AddressID;
GO



IF OBJECT_ID('dbo.DimStore','U') IS NOT NULL
    DROP TABLE dbo.DimStore;
GO

CREATE TABLE dbo.DimStore
(
    Store_key           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- surrogate PK
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
    CountryRegionName   NVARCHAR(50)       NULL
);
GO
;WITH StoreBase AS
(
    SELECT 
        s.BusinessEntityID,
        s.[Name]
    FROM CompanyX.Sales.Store AS s
)
INSERT INTO dbo.DimStore
(
    [Name],
    AnnualSales,
    AnnualRevenue,
    BusinessType,
    BankName,
    YearOpened,
    Specialty,
    SquareFeet,
    Brands,
    Internet,
    NumberEmployees,
    AddressType,
    AddressLine1,
    AddressLine2,
    City,
    StateProvinceName,
    CountryRegionName
)
SELECT
    sb.[Name],
    ed.AnnualSales,
    ed.AnnualRevenue,
    ed.BusinessType,
    ed.BankName,
    ed.YearOpened,
    ed.Specialty,
    ed.SquareFeet,
    ed.Brands,
    ed.Internet,
    ed.NumberEmployees,
    sa.AddressType,
    sa.AddressLine1,
    sa.AddressLine2,
    sa.City,
    sa.StateProvinceName,
    sa.CountryRegionName
FROM StoreBase sb
LEFT JOIN dbo.ExtractedStoreDemographic ed
       ON ed.BusinessEntityID = sb.BusinessEntityID
LEFT JOIN dbo.StoreAddressResolved sa
       ON sa.BusinessEntityID = sb.BusinessEntityID;
GO

SELECT *
FROM dbo.DimStore;

