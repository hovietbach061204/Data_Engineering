-- T-SQL
USE CompanyX;
SET NOCOUNT ON;

-- Watermarks passed as parameters (Jinja2 templating)
DECLARE @WM_SalesTerritory DATETIME = '{{ watermark_dict["Sales.SalesTerritory"] }}';
DECLARE @WM_CountryRegion DATETIME = '{{ watermark_dict["Person.CountryRegion"] }}';

WITH vTerritoryWithCountry AS (
    SELECT
        st.TerritoryID,
        st.Name,
        cr.Name AS CountryRegionName,
        st.[Group],
        st.SalesYTD,
        st.SalesLastYear,
        st.CostYTD,
        st.CostLastYear,
        st.ModifiedDate AS TerritoryModifiedDate,
        cr.ModifiedDate AS CountryRegionModifiedDate
    FROM Sales.SalesTerritory st WITH (INDEX(IX_SalesTerritory_ModifiedDate))
    LEFT JOIN Person.CountryRegion cr WITH (INDEX(IX_CountryRegion_ModifiedDate))
        ON st.CountryRegionCode = cr.CountryRegionCode
    WHERE
        st.ModifiedDate > @WM_SalesTerritory OR
        cr.ModifiedDate > @WM_CountryRegion
)

SELECT
    TerritoryID,
    Name,
    CountryRegionName,
    [Group],
    SalesYTD,
    SalesLastYear,
    CostYTD,
    CostLastYear,
    -- StartDate = Latest ModifiedDate from contributing tables
    (
        SELECT MAX(v)
        FROM (VALUES
            (TerritoryModifiedDate),
            (CountryRegionModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM vTerritoryWithCountry;
