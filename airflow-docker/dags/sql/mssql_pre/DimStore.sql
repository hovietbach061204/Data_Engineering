USE CompanyX;
SET NOCOUNT ON;

;WITH StoreWithAddresses AS (
    SELECT
        s.BusinessEntityID,
        s.[Name],
        atp.[Name]                AS AddressType,
        a.AddressLine1,
        a.AddressLine2,
        a.City,
        sp.[Name]                 AS StateProvinceName,
        cr.[Name]                 AS CountryRegionName,
        -- keep the modified dates so we can compute a robust "ModifiedDate"
        a.ModifiedDate            AS AddressModifiedDate,
        sp.ModifiedDate           AS StateProvinceModifiedDate,
        cr.ModifiedDate           AS CountryRegionCodeModifiedDate,
        atp.ModifiedDate          AS AddressTypeModifiedDate,
        s.ModifiedDate            AS StoreModifiedDate
    FROM Sales.Store AS s
    INNER JOIN Person.BusinessEntityAddress AS bea
        ON bea.BusinessEntityID = s.BusinessEntityID
    INNER JOIN Person.Address AS a
        ON a.AddressID = bea.AddressID
    INNER JOIN Person.StateProvince AS sp
        ON sp.StateProvinceID = a.StateProvinceID
    INNER JOIN Person.CountryRegion AS cr
        ON cr.CountryRegionCode = sp.CountryRegionCode
    INNER JOIN Person.AddressType AS atp
        ON atp.AddressTypeID = bea.AddressTypeID
),
StoreWithDemographics AS (
    SELECT
        s.BusinessEntityID,
        s.[Name],
        TRY_CONVERT(DECIMAL(18,2),
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/AnnualSales)[1]', 'float'))          AS AnnualSales,
        TRY_CONVERT(DECIMAL(18,2),
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/AnnualRevenue)[1]', 'float'))        AS AnnualRevenue,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/BankName)[1]', 'nvarchar(100)')          AS BankName,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/BusinessType)[1]', 'nvarchar(30)')       AS BusinessType,
        TRY_CONVERT(INT,
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/YearOpened)[1]', 'nvarchar(100)'))   AS YearOpened,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/Specialty)[1]', 'nvarchar(100)')         AS Specialty,
        TRY_CONVERT(INT,
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/SquareFeet)[1]', 'nvarchar(100)'))   AS SquareFeet,
        TRY_CONVERT(INT,
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/Brands)[1]', 'nvarchar(100)'))       AS Brands,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/Internet)[1]', 'nvarchar(30)')           AS Internet,
        TRY_CONVERT(INT,
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/NumberEmployees)[1]', 'nvarchar(100)')) AS NumberEmployees
    FROM Sales.Store AS s
    WHERE s.Demographics IS NOT NULL
),
OneAddressPerStore AS (
    SELECT
        swa.*,
        ROW_NUMBER() OVER (
            PARTITION BY swa.BusinessEntityID
            ORDER BY CASE swa.AddressType
                        WHEN N'Main Office' THEN 0
                        WHEN N'Shipping'    THEN 1
                        WHEN N'Billing'     THEN 2
                        ELSE 9
                     END,
                     swa.AddressLine1
        ) AS rn
    FROM StoreWithAddresses AS swa
)

INSERT INTO CompanyX.dbo.DimStore (
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
    oa.[Name],
    oa.BusinessEntityID AS StoreID,
    d.AnnualSales,
    d.AnnualRevenue,
    d.BusinessType,
    d.BankName,
    d.YearOpened,
    d.Specialty,
    d.SquareFeet,
    d.Brands,
    d.Internet,
    d.NumberEmployees,
    oa.AddressType,
    oa.AddressLine1,
    oa.AddressLine2,
    oa.City,
    oa.StateProvinceName,
    oa.CountryRegionName,
    (
        SELECT MAX(v)
        FROM (VALUES
                (oa.StoreModifiedDate),
                (oa.AddressModifiedDate),
                (oa.AddressTypeModifiedDate),
                (oa.CountryRegionCodeModifiedDate),
                (oa.StateProvinceModifiedDate)
             ) AS valueTable(v)
    ) AS ModifiedDate
FROM OneAddressPerStore AS oa
LEFT JOIN StoreWithDemographics AS d
    ON d.BusinessEntityID = oa.BusinessEntityID
WHERE oa.rn = 1;
