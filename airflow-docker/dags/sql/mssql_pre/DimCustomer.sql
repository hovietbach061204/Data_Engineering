USE CompanyX;
SET NOCOUNT ON;

WITH vIndividualCustomer AS (
    SELECT
        p.BusinessEntityID,
        c.CustomerID,
        p.PersonType,
        p.FirstName,
        p.LastName,

        -- one, latest email for this person
        email.EmailAddress,
        p.EmailPromotion,

        -- one, latest address for this person (+ its region/country)
        addr.AddressLine1,
        addr.City,
        addr.StateProvinceName,
        addr.CountryRegionName,

        p.Demographics,

        -- Collect all ModifiedDate columns to compute StartDate
        c.ModifiedDate              AS CustomerModifiedDate,
        p.ModifiedDate              AS PersonModifiedDate,
        email.EmailModifiedDate     AS EmailModifiedDate,
        addr.AddressModifiedDate    AS AddressModifiedDate,
        addr.StateProvModifiedDate  AS StateProvinceModifiedDate,
        addr.CountryRegionModDate   AS CountryRegionModifiedDate
    FROM Person.Person p
    INNER JOIN Sales.Customer c
        ON c.PersonID = p.BusinessEntityID

    -- === pick the latest email (if any) ===
    OUTER APPLY (
        SELECT TOP (1)
               ea.EmailAddress,
               ea.ModifiedDate AS EmailModifiedDate
        FROM Person.EmailAddress ea
        WHERE ea.BusinessEntityID = p.BusinessEntityID
        ORDER BY ea.ModifiedDate DESC, ea.EmailAddress
    ) AS email

    -- === pick the latest address (if any), bringing region & country ===
    OUTER APPLY (
        SELECT TOP (1)
               a.AddressLine1,
               a.City,
               sp.Name  AS StateProvinceName,
               cr.Name  AS CountryRegionName,
               a.ModifiedDate  AS AddressModifiedDate,
               sp.ModifiedDate AS StateProvModifiedDate,
               cr.ModifiedDate AS CountryRegionModDate
        FROM Person.BusinessEntityAddress bea
        JOIN Person.Address a
          ON a.AddressID = bea.AddressID
        JOIN Person.StateProvince sp
          ON sp.StateProvinceID = a.StateProvinceID
        JOIN Person.CountryRegion cr
          ON cr.CountryRegionCode = sp.CountryRegionCode
        JOIN Person.AddressType atp
          ON atp.AddressTypeID = bea.AddressTypeID
        WHERE bea.BusinessEntityID = p.BusinessEntityID
        ORDER BY a.ModifiedDate DESC, a.AddressID
    ) AS addr

    WHERE c.StoreID IS NULL
),
vPersonDemographics AS (
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

INSERT INTO CompanyX.dbo.DimCustomer (
    CustomerID, PersonType, FirstName, LastName, EmailAddress, EmailPromotion,
    AddressLine1, City, StateProvinceName, CountryRegionName,
    BirthDate, MaritalStatus, Gender, Education, Occupation,
    HomeOwnerFlag, NumberCarsOwned, NumberChildrenAtHome, TotalChildren,
    TotalPurchaseYTD, YearlyIncome, DateFirstPurchase,
    StartDate, EndDate
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