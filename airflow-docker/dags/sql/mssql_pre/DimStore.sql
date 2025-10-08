-- T-SQL

USE [CompanyX];
GO
SET NOCOUNT ON;


-- 1) Drop and rebuild staging table for demographics
IF OBJECT_ID('dbo.ExtractedStoreDemographic','U') IS NOT NULL
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
    TRY_CONVERT(DECIMAL(18,2), sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/AnnualSales)[1]', 'float')),
    TRY_CONVERT(DECIMAL(18,2), sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/AnnualRevenue)[1]', 'float')),
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/BankName)[1]', 'nvarchar(100)'),
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/BusinessType)[1]', 'nvarchar(30)'),
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/YearOpened)[1]', 'nvarchar(100)')),
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/Specialty)[1]', 'nvarchar(100)'),
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/SquareFeet)[1]', 'nvarchar(100)')),
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/Brands)[1]', 'nvarchar(100)')),
    sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/Internet)[1]', 'nvarchar(30)'),
    TRY_CONVERT(INT, sx.DemXML.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey"; (/StoreSurvey/NumberEmployees)[1]', 'nvarchar(100)'))
FROM StoreXML sx;
GO

-- 2) Resolve store addresses into staging
IF OBJECT_ID('dbo.StoreAddressResolved','U') IS NOT NULL DROP TABLE dbo.StoreAddressResolved;
GO

SELECT
    s.BusinessEntityID,
    s.[Name],
    atp.[Name] AS AddressType,
    a.AddressLine1,
    a.AddressLine2,
    a.City,
    sp.[Name] AS StateProvinceName,
    a.PostalCode,
    cr.[Name] AS CountryRegionName,
    a.ModifiedDate AS AddressModifiedDate,
    sp.ModifiedDate AS StateProvinceModifiedDate,
    cr.ModifiedDate AS CountryRegionCodeModifiedDate,
    atp.ModifiedDate AS AddressTypeModifiedDate
INTO dbo.StoreAddressResolved
FROM CompanyX.Sales.Store AS s
INNER JOIN CompanyX.Person.BusinessEntityAddress AS bea
    ON bea.BusinessEntityID = s.BusinessEntityID
INNER JOIN CompanyX.Person.Address AS a
    ON a.AddressID = bea.AddressID
INNER JOIN CompanyX.Person.StateProvince AS sp
    ON sp.StateProvinceID = a.StateProvinceID
INNER JOIN CompanyX.Person.CountryRegion AS cr
    ON cr.CountryRegionCode = sp.CountryRegionCode
INNER JOIN CompanyX.Person.AddressType AS atp
    ON atp.AddressTypeID = bea.AddressTypeID;

-- 4) Load DimStore with a single address per store (avoid duplicates)
;WITH StoreBase AS
(
    SELECT s.BusinessEntityID, s.[Name], s.ModifiedDate
    FROM CompanyX.Sales.Store AS s
),
sa_one AS
(
    SELECT
        sar.BusinessEntityID,
        sar.AddressType,
        sar.AddressLine1,
        sar.AddressLine2,
        sar.City,
        sar.StateProvinceName,
        sar.CountryRegionName,
        sar.AddressModifiedDate,
        sar.AddressTypeModifiedDate,
        sar.CountryRegionCodeModifiedDate,
        sar.StateProvinceModifiedDate,
        ROW_NUMBER() OVER
        (
            PARTITION BY sar.BusinessEntityID
            ORDER BY CASE sar.AddressType
                        WHEN N'Main Office' THEN 0
                        WHEN N'Shipping'    THEN 1
                        WHEN N'Billing'     THEN 2
                        ELSE 9
                     END,
                     sar.AddressLine1
        ) AS rn
    FROM dbo.StoreAddressResolved AS sar
)
INSERT INTO CompanyX.dbo.DimStore
(
    [Name],
    StoreID,
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
    CountryRegionName,
    ModifiedDate
)
SELECT
    sb.[Name],
    sb.BusinessEntityID AS StoreID,
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
    sa.CountryRegionName,
    (
        SELECT MAX(v)
        FROM (VALUES 
                (sb.ModifiedDate),
                (sa.AddressModifiedDate),
                (sa.AddressTypeModifiedDate),
                (sa.CountryRegionCodeModifiedDate),
                (sa.StateProvinceModifiedDate)
             ) AS valueTable(v)
    ) AS ModifiedDate
FROM StoreBase sb
LEFT JOIN dbo.ExtractedStoreDemographic ed
    ON ed.BusinessEntityID = sb.BusinessEntityID
LEFT JOIN sa_one sa
    ON sa.BusinessEntityID = sb.BusinessEntityID
   AND sa.rn = 1;

