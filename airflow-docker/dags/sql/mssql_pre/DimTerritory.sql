USE CompanyX;

;WITH TerrLatest AS (
    SELECT
        st.TerritoryID,
        st.[Name],
        st.CountryRegionCode,
        st.[Group],
        st.SalesYTD,
        st.SalesLastYear,
        st.CostYTD,
        st.CostLastYear,
        st.ModifiedDate AS TerritoryModifiedDate,
        ROW_NUMBER() OVER (
            PARTITION BY st.TerritoryID
            ORDER BY st.ModifiedDate DESC, st.SalesYTD DESC
        ) AS rn
    FROM CompanyX.Sales.SalesTerritory AS st
),
TerrChosen AS (
    SELECT
        t.TerritoryID,
        t.[Name],
        t.CountryRegionCode,
        t.[Group],
        t.TerritoryModifiedDate,
        TRY_CONVERT(DECIMAL(19,4), t.SalesYTD)       AS SalesYTD,
        TRY_CONVERT(DECIMAL(19,4), t.SalesLastYear)  AS SalesLastYear,
        TRY_CONVERT(DECIMAL(19,4), t.CostYTD)        AS CostYTD,
        TRY_CONVERT(DECIMAL(19,4), t.CostLastYear)   AS CostLastYear
    FROM TerrLatest t
    WHERE t.rn = 1
)
SELECT
    tc.TerritoryID,
    tc.[Name],
    cr.[Name] AS CountryRegionName,
    tc.[Group],
    tc.SalesYTD,
    tc.SalesLastYear,
    tc.CostYTD,
    tc.CostLastYear,
    cr.ModifiedDate AS CountryRegionModifiedDate,
    tc.TerritoryModifiedDate
INTO #TerritoryStage
FROM TerrChosen tc
LEFT JOIN CompanyX.Person.CountryRegion cr
    ON cr.CountryRegionCode = tc.CountryRegionCode;

INSERT INTO dbo.DimTerritory (
    [Name],
    CountryRegionName,
    [Group],
    SalesYTD,
    SalesLastYear,
    CostYTD,
    CostLastYear,
    TerritoryID,
    StartDate,
    EndDate
)
SELECT
    s.[Name],
    s.CountryRegionName,
    s.[Group],
    s.SalesYTD,
    s.SalesLastYear,
    s.CostYTD,
    s.CostLastYear,
    s.TerritoryID,
    -- StartDate = Latest ModifiedDate from Territory or CountryRegion
    (
        SELECT MAX(v)
        FROM (VALUES
                (s.CountryRegionModifiedDate),
                (s.TerritoryModifiedDate)
             ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM #TerritoryStage AS s;

DROP TABLE #TerritoryStage;