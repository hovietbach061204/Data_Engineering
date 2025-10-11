USE CompanyX;
DECLARE @cols NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);

-- Define permanent (or staging) table once
IF OBJECT_ID('ExtractedDemographic') IS NOT NULL
    DROP TABLE ExtractedDemographic;

CREATE TABLE ExtractedDemographic(
    BusinessEntityID INT,
    BirthDate datetime,
    CommuteDistance nvarchar(50),
    DateFirstPurchase datetime,
    Education nvarchar(30),
    Gender nvarchar(2),
    HomeOwnerFlag bit,
    MaritalStatus nvarchar(2),
    NumberCarsOwned int,
    NumberChildrenAtHome int,
    Occupation nvarchar(30),
    TotalChildren int,
    TotalPurchaseYTD float,
    YearlyIncome nvarchar(40)
);

-- Build the pivot column list
WITH XMLNAMESPACES (
    'http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey' AS ns
)
SELECT @cols = STRING_AGG(QUOTENAME(ElementName), ',')
FROM (
    SELECT DISTINCT x.value('local-name(.)', 'nvarchar(100)') AS ElementName
    FROM [CompanyX].[Person].[Person] P
    CROSS APPLY P.Demographics.nodes('/ns:IndividualSurvey/ns:*') AS T(x)
    WHERE P.Demographics IS NOT NULL
) AS Names;

-- Build dynamic SQL to insert into ExtractedDemographic
SET @sql = '
WITH XMLNAMESPACES (
    ''http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey'' AS ns
)
, Shredded AS (
    SELECT
        P.BusinessEntityID,
        x.value(''local-name(.)'', ''nvarchar(100)'') AS ElementName,
        x.value(''.'', ''nvarchar(200)'') AS ElementValue
    FROM [CompanyX].[Person].[Person] P
    CROSS APPLY P.Demographics.nodes(''/ns:IndividualSurvey/ns:*'') AS T(x)
    WHERE P.Demographics IS NOT NULL
)
INSERT INTO ExtractedDemographic (
    BusinessEntityID, ' + @cols + '
)
SELECT BusinessEntityID, ' + @cols + '
FROM Shredded
PIVOT (
    MAX(ElementValue) FOR ElementName IN (' + @cols + ')
) AS Pivoted;
';

-- Execute dynamic SQL
EXEC sp_executesql @sql;

-- Idempotent target
IF OBJECT_ID('dbo.DimCustomer','U') IS NULL
    RAISERROR('dbo.DimCustomer does not exist – run DimCreateTable.sql first', 16, 1);

TRUNCATE TABLE dbo.DimCustomer;

-- Now query your table
SELECT * FROM ExtractedDemographic;

/**/
/* join to get addressID from sales header*/
WITH SalesAndAdress AS (
	select S.CustomerID,P.AddressID
	from CompanyX.Sales.SalesOrderHeader S JOIN CompanyX.Person.Address P ON (S.ShipToAddressID=P.AddressID)
),
/* join with customer fom sales header*/
customerSalesHeader AS (
	select C.CustomerID,C.PersonID,TerritoryID,S.AddressID,C.ModifiedDate
	from SalesAndAdress S JOIN CompanyX.Sales.Customer C ON (S.CustomerID = C.CustomerID)
	where C.PersonID IS NOT NULL
),
/*join person and personDemographic and CustomerSalesHeader*/
CustomerPersonSalesHeader AS (
	select distinct S.CustomerID,S.ModifiedDate,P.PersonType,P.FirstName,P.LastName,P.EmailPromotion,S.AddressID,S.TerritoryID,D.*
	from (CompanyX.Person.Person P JOIN customerSalesHeader S ON (S.PersonID = P.BusinessEntityID)) JOIN CompanyX.dbo.ExtractedDemographic D ON (P.BusinessEntityID = D.BusinessEntityID)
),
/*join stateprovince id with CountryRegion and with Address*/
StateAndRegion AS (
    select distinct A.AddressID,A.AddressLine1,A.City,P.Name as ProvinceName, R.Name as CountryRegionName
    from (CompanyX.Person.StateProvince P JOIN CompanyX.Person.CountryRegion R ON (P.CountryRegionCode = R.CountryRegionCode)) JOIN CompanyX.Person.Address A ON (A.StateProvinceID = P.StateProvinceID)
),
/* join stateName, addressline, city and CountryName with CustomerPersonSalesHeader with email address */
CustomerPersonSalesHeaderEmail AS (
    select CPSH.*,SR.AddressLine1,SR.City,SR.CountryRegionName,SR.ProvinceName,E.EmailAddress
    from (CustomerPersonSalesHeader CPSH JOIN StateAndRegion SR ON (CPSH.AddressID = SR.AddressID)) JOIN CompanyX.Person.EmailAddress E ON (CPSH.BusinessEntityID = E.BusinessEntityID)
)
insert into CompanyX.dbo.DimCustomer (
    CustomerID,PersonType,FirstName,LastName,EmailAddress,EmailPromotion,AddressLine1,City,ProvinceName,CountryRegionName,TotalPurchaseYTD,DateFirstPurchase,BirthDate,YearlyIncome,MaritalStatus,Gender,TotalChildren,NumberChildrenAtHome,Education,Occupation,HomeOwnerFlag,NumberCarsOwned,CommuteDistance,ModifiedDate
)
select CustomerID,PersonType,FirstName,LastName,EmailAddress,EmailPromotion,AddressLine1,City,ProvinceName,CountryRegionName,TotalPurchaseYTD,DateFirstPurchase,BirthDate,YearlyIncome,MaritalStatus,Gender,TotalChildren,NumberChildrenAtHome,Education,Occupation,HomeOwnerFlag,NumberCarsOwned,CommuteDistance,ModifiedDate
from CustomerPersonSalesHeaderEmail
