/* =======================================================================
   STEP 1) Stage SalesTerritory with CountryRegionName (1 row per TerritoryID)
   ======================================================================= */

IF OBJECT_ID('tempdb..#TerritoryStage') IS NOT NULL DROP TABLE #TerritoryStage;

;WITH TerrLatest AS
(
    SELECT
        st.TerritoryID,
        st.[Name],
        st.CountryRegionCode,
        st.[Group],
        st.SalesYTD,
        st.SalesLastYear,
        st.CostYTD,
        st.CostLastYear,
        st.ModifiedDate,
        ROW_NUMBER() OVER (
            PARTITION BY st.TerritoryID
            ORDER BY st.ModifiedDate DESC, st.SalesYTD DESC
        ) AS rn
    FROM CompanyX.Sales.SalesTerritory AS st
),
TerrChosen AS
(
    SELECT
        t.TerritoryID,
        t.[Name],
        t.CountryRegionCode,
        t.[Group],
        /* Normalize numeric types (AdventureWorks uses money) */
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
    tc.CostLastYear
INTO #TerritoryStage
FROM TerrChosen tc
LEFT JOIN CompanyX.Person.CountryRegion cr
       ON cr.CountryRegionCode = tc.CountryRegionCode;

SELECT * from #TerritoryStage;
/* =======================================================================
   STEP 2) Create Dim_Territory
   ======================================================================= */
IF OBJECT_ID('dbo.DimTerritory','U') IS NOT NULL
    DROP TABLE dbo.DimTerritory;
GO

CREATE TABLE dbo.DimTerritory
(
    Territory_key     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- surrogate key
    [Name]            NVARCHAR(100)     NULL,
    CountryRegionName NVARCHAR(100)     NULL,
    [Group]           NVARCHAR(50)      NULL,
    SalesYTD          DECIMAL(19,4)     NULL,
    SalesLastYear     DECIMAL(19,4)     NULL,
    CostYTD           DECIMAL(19,4)     NULL,
    CostLastYear      DECIMAL(19,4)     NULL,
    TerritoryID       INT               NOT NULL
);

-- Optional: keep one row per TerritoryID
CREATE UNIQUE INDEX UX_Dim_Territory_TerritoryID ON dbo.DimTerritory(TerritoryID);

/* =======================================================================
   STEP 3) Load Dim_Territory
   ======================================================================= */
INSERT INTO dbo.DimTerritory
(
    [Name],
    CountryRegionName,
    [Group],
    SalesYTD,
    SalesLastYear,
    CostYTD,
    CostLastYear,
    TerritoryID
)
SELECT
    s.[Name],
    s.CountryRegionName,
    s.[Group],
    s.SalesYTD,
    s.SalesLastYear,
    s.CostYTD,
    s.CostLastYear,
    s.TerritoryID
FROM #TerritoryStage AS s;

---------------------------------checking
-- Row count
SELECT COUNT(*) AS TerritoryRows FROM dbo.DimTerritory;

-- Spot check
SELECT TOP (20) * FROM dbo.DimTerritory ORDER BY Territory_key;

-- Ensure 1 row per TerritoryID
SELECT TerritoryID, COUNT(*) AS Cnt
FROM dbo.DimTerritory
GROUP BY TerritoryID
HAVING COUNT(*) > 1;

