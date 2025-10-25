-- airflow-docker/dags/sql/mssql_incremental/check_updates_DimStore.sql
USE CompanyX;
SET NOCOUNT ON;

DECLARE @WM_Store DATETIME = '{{ watermark_dict["Sales.Store"] }}';
DECLARE @WM_BusinessEntityAddress DATETIME = '{{ watermark_dict["Person.BusinessEntityAddress"] }}';
DECLARE @WM_Address DATETIME = '{{ watermark_dict["Person.Address"] }}';
DECLARE @WM_StateProvince DATETIME = '{{ watermark_dict["Person.StateProvince"] }}';
DECLARE @WM_CountryRegion DATETIME = '{{ watermark_dict["Person.CountryRegion"] }}';
DECLARE @WM_AddressType DATETIME = '{{ watermark_dict["Person.AddressType"] }}';

WITH StoreWithAddresses AS (
    SELECT
        s.BusinessEntityID,
        s.[Name],
        atp.[Name] AS AddressType,
        a.AddressLine1,
        a.AddressLine2,
        a.City,
        sp.[Name] AS StateProvinceName,
        cr.[Name] AS CountryRegionName,
        a.ModifiedDate AS AddressModifiedDate,
        sp.ModifiedDate AS StateProvinceModifiedDate,
        cr.ModifiedDate AS CountryRegionCodeModifiedDate,
        atp.ModifiedDate AS AddressTypeModifiedDate,
        s.ModifiedDate AS StoreModifiedDate,
        bea.ModifiedDate AS BusinessEntityAddressModifiedDate
    FROM Sales.Store AS s WITH (INDEX(IX_Store_ModifiedDate))
    INNER JOIN Person.BusinessEntityAddress AS bea WITH (INDEX(IX_BusinessEntityAddress_ModifiedDate))
        ON bea.BusinessEntityID = s.BusinessEntityID
    INNER JOIN Person.Address AS a WITH (INDEX(IX_Address_ModifiedDate))
        ON a.AddressID = bea.AddressID
    INNER JOIN Person.StateProvince AS sp WITH (INDEX(IX_StateProvince_ModifiedDate))
        ON sp.StateProvinceID = a.StateProvinceID
    INNER JOIN Person.CountryRegion AS cr WITH (INDEX(IX_CountryRegion_ModifiedDate))
        ON cr.CountryRegionCode = sp.CountryRegionCode
    INNER JOIN Person.AddressType AS atp WITH (INDEX(IX_AddressType_ModifiedDate))
        ON atp.AddressTypeID = bea.AddressTypeID
    WHERE
        s.ModifiedDate > @WM_Store OR
        bea.ModifiedDate > @WM_BusinessEntityAddress OR
        a.ModifiedDate > @WM_Address OR
        sp.ModifiedDate > @WM_StateProvince OR
        cr.ModifiedDate > @WM_CountryRegion OR
        atp.ModifiedDate > @WM_AddressType
),
StoreWithDemographics AS (
    SELECT
        s.BusinessEntityID,
        s.[Name],
        TRY_CONVERT(DECIMAL(18,2),
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/AnnualSales)[1]', 'float')) AS AnnualSales,
        TRY_CONVERT(DECIMAL(18,2),
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/AnnualRevenue)[1]', 'float')) AS AnnualRevenue,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/BankName)[1]', 'nvarchar(100)') AS BankName,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/BusinessType)[1]', 'nvarchar(30)') AS BusinessType,
        TRY_CONVERT(INT,
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/YearOpened)[1]', 'nvarchar(100)')) AS YearOpened,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/Specialty)[1]', 'nvarchar(100)') AS Specialty,
        TRY_CONVERT(INT,
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/SquareFeet)[1]', 'nvarchar(100)')) AS SquareFeet,
        TRY_CONVERT(INT,
            s.Demographics.value(
                'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
                 (/StoreSurvey/Brands)[1]', 'nvarchar(100)')) AS Brands,
        s.Demographics.value(
            'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey";
             (/StoreSurvey/Internet)[1]', 'nvarchar(30)') AS Internet,
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
            (oa.StateProvinceModifiedDate),
            (oa.BusinessEntityAddressModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM OneAddressPerStore AS oa
LEFT JOIN StoreWithDemographics AS d
    ON d.BusinessEntityID = oa.BusinessEntityID
WHERE oa.rn = 1;
