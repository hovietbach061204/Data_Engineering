USE CompanyX;
SET NOCOUNT ON;

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
        c.ModifiedDate AS CustomerModifiedDate   -- <-- carry ModifiedDate from Sales.Customer
    FROM Person.Person p
    INNER JOIN Sales.Customer c
        ON c.PersonID = p.BusinessEntityID
    INNER JOIN Person.BusinessEntityAddress bea
        ON bea.BusinessEntityID = p.BusinessEntityID
    INNER JOIN Person.Address a
        ON a.AddressID = bea.AddressID
    INNER JOIN Person.StateProvince sp
        ON sp.StateProvinceID = a.StateProvinceID
    INNER JOIN Person.CountryRegion cr
        ON cr.CountryRegionCode = sp.CountryRegionCode
    INNER JOIN Person.AddressType atp
        ON atp.AddressTypeID = bea.AddressTypeID
    LEFT JOIN Person.EmailAddress ea
        ON ea.BusinessEntityID = p.BusinessEntityID
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
    TotalPurchaseYTD, YearlyIncome, DateFirstPurchase, ModifiedDate
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
    ic.CustomerModifiedDate   -- <-- use original ModifiedDate from Sales.Customer
FROM vIndividualCustomer AS ic
LEFT JOIN vPersonDemographics AS pd
    ON ic.BusinessEntityID = pd.BusinessEntityID;