-- T-SQL
USE CompanyX;
SET NOCOUNT ON;

-- Watermarks passed as parameters (Jinja2 templating)
DECLARE @WM_Customer DATETIME = '{{ watermark_dict["Sales.Customer"] }}';
DECLARE @WM_Person DATETIME = '{{ watermark_dict["Person.Person"] }}';
DECLARE @WM_EmailAddress DATETIME = '{{ watermark_dict["Person.EmailAddress"] }}';
DECLARE @WM_Address DATETIME = '{{ watermark_dict["Person.Address"] }}';
DECLARE @WM_StateProvince DATETIME = '{{ watermark_dict["Person.StateProvince"] }}';
DECLARE @WM_CountryRegion DATETIME = '{{ watermark_dict["Person.CountryRegion"] }}';

-- Reuse exact same query logic from DimCustomer.sql, just add watermark filter
WITH vIndividualCustomer AS (
    SELECT
        p.BusinessEntityID,
        c.CustomerID,
        p.PersonType,
        p.FirstName,
        p.LastName,
        ea.EmailAddress,
        p.EmailPromotion,
        a.AddressLine1,
        a.City,
        sp.Name AS StateProvinceName,
        cr.Name AS CountryRegionName,
        p.Demographics,
        c.ModifiedDate AS CustomerModifiedDate,
        p.ModifiedDate AS PersonModifiedDate,
        ea.ModifiedDate AS EmailModifiedDate,
        a.ModifiedDate AS AddressModifiedDate,
        sp.ModifiedDate AS StateProvinceModifiedDate,
        cr.ModifiedDate AS CountryRegionModifiedDate
    FROM Person.Person p WITH (INDEX(IX_Person_ModifiedDate))
    INNER JOIN Sales.Customer c WITH (INDEX(IX_Customer_ModifiedDate))
        ON c.PersonID = p.BusinessEntityID
    INNER JOIN Person.BusinessEntityAddress bea
        ON bea.BusinessEntityID = p.BusinessEntityID
    INNER JOIN Person.Address a WITH (INDEX(IX_Address_ModifiedDate))
        ON a.AddressID = bea.AddressID
    INNER JOIN Person.StateProvince sp WITH (INDEX(IX_StateProvince_ModifiedDate))
        ON sp.StateProvinceID = a.StateProvinceID
    INNER JOIN Person.CountryRegion cr WITH (INDEX(IX_CountryRegion_ModifiedDate))
        ON cr.CountryRegionCode = sp.CountryRegionCode
    INNER JOIN Person.AddressType atp
        ON atp.AddressTypeID = bea.AddressTypeID
    LEFT JOIN Person.EmailAddress ea WITH (INDEX(IX_EmailAddress_ModifiedDate))
        ON ea.BusinessEntityID = p.BusinessEntityID
    WHERE c.StoreID IS NULL
      AND (
          c.ModifiedDate > @WM_Customer OR
          p.ModifiedDate > @WM_Person OR
          ea.ModifiedDate > @WM_EmailAddress OR
          a.ModifiedDate > @WM_Address OR
          sp.ModifiedDate > @WM_StateProvince OR
          cr.ModifiedDate > @WM_CountryRegion
      )
),
vPersonDemographics AS (
    -- Same as original script (demographics parsing)
    SELECT
        p.BusinessEntityID,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            TotalPurchaseYTD[1]', 'money') AS TotalPurchaseYTD,
        CONVERT(datetime, REPLACE([ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            DateFirstPurchase[1]', 'nvarchar(20)'), 'Z', ''), 101) AS DateFirstPurchase,
        CONVERT(datetime, REPLACE([ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            BirthDate[1]', 'nvarchar(20)'), 'Z', ''), 101) AS BirthDate,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            MaritalStatus[1]', 'nvarchar(2)') AS MaritalStatus,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            YearlyIncome[1]', 'nvarchar(40)') AS YearlyIncome,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            Gender[1]', 'nvarchar(2)') AS Gender,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            TotalChildren[1]', 'int') AS TotalChildren,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            NumberChildrenAtHome[1]', 'int') AS NumberChildrenAtHome,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            Education[1]', 'nvarchar(30)') AS Education,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            Occupation[1]', 'nvarchar(30)') AS Occupation,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            HomeOwnerFlag[1]', 'bit') AS HomeOwnerFlag,
        [ref].value(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";
            NumberCarsOwned[1]', 'int') AS NumberCarsOwned
    FROM Person.Person p
    CROSS APPLY p.Demographics.nodes(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"; /IndividualSurvey') AS [IndividualSurvey](ref)
    WHERE p.Demographics IS NOT NULL
)

SELECT
    ic.CustomerID,
    ic.PersonType,
    ic.FirstName,
    ic.LastName,
    ic.EmailAddress,
    ic.EmailPromotion,
    ic.AddressLine1,
    ic.City,
    ic.StateProvinceName,
    ic.CountryRegionName,
    pd.BirthDate,
    pd.MaritalStatus,
    pd.Gender,
    pd.Education,
    pd.Occupation,
    pd.HomeOwnerFlag,
    pd.NumberCarsOwned,
    pd.NumberChildrenAtHome,
    pd.TotalChildren,
    pd.TotalPurchaseYTD,
    pd.YearlyIncome,
    pd.DateFirstPurchase,
    -- StartDate = Latest ModifiedDate from all contributing tables
    (
        SELECT MAX(v)
        FROM (VALUES
            (ic.CustomerModifiedDate),
            (ic.PersonModifiedDate),
            (ic.EmailModifiedDate),
            (ic.AddressModifiedDate),
            (ic.StateProvinceModifiedDate),
            (ic.CountryRegionModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM vIndividualCustomer AS ic
LEFT JOIN vPersonDemographics AS pd
    ON ic.BusinessEntityID = pd.BusinessEntityID;
