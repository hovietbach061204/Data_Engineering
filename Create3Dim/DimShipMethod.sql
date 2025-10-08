/* =======================================================================
   STEP 1) Stage ShipMethod data
   ======================================================================= */

IF OBJECT_ID('tempdb..#ShipMethodStage') IS NOT NULL DROP TABLE #ShipMethodStage;

;WITH ShipBaseData AS
(
    SELECT
        sm.ShipMethodID,
        sm.[Name],
        sm.ShipBase
    FROM CompanyX.Purchasing.ShipMethod AS sm
),
ShipDateData AS
(
    -- Optional: Get the most recent ship date per ShipMethod
    SELECT
        soh.ShipMethodID,
        MAX(soh.ShipDate) AS ShipDate
    FROM CompanyX.Sales.SalesOrderHeader AS soh
    WHERE soh.ShipDate IS NOT NULL
    GROUP BY soh.ShipMethodID
)
SELECT
    sbd.ShipMethodID,
    sbd.[Name],
    sbd.ShipBase,
    sdd.ShipDate
INTO #ShipMethodStage
FROM ShipBaseData sbd
LEFT JOIN ShipDateData sdd
       ON sbd.ShipMethodID = sdd.ShipMethodID;
SELECT * FROM #ShipMethodStage;
/* =======================================================================
   STEP 2) Create Dim_ShipMethod
   ======================================================================= */

IF OBJECT_ID('dbo.DimShipMethod','U') IS NOT NULL
    DROP TABLE dbo.DimShipMethod;
GO

CREATE TABLE dbo.DimShipMethod
(
    ShipMethod_key   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ShipMethodID     INT              NOT NULL,
    [Name]           NVARCHAR(50)     NULL,
    ShipBase         DECIMAL(19,4)    NULL,
    ShipDate         DATE             NULL
);

-- Optional: enforce uniqueness on natural key
CREATE UNIQUE INDEX UX_Dim_ShipMethod_ShipMethodID ON dbo.DimShipMethod(ShipMethodID);
/* =======================================================================
   STEP 3) Load Dim_ShipMethod
   ======================================================================= */

INSERT INTO dbo.DimShipMethod
(
    ShipMethodID,
    [Name],
    ShipBase,
    ShipDate
)
SELECT
    ShipMethodID,
    [Name],
    ShipBase,
    ShipDate
FROM #ShipMethodStage;

SELECT TOP (20) *
FROM dbo.DimShipMethod
ORDER BY ShipMethod_key;

SELECT COUNT(*) AS TotalShipMethods FROM dbo.DimShipMethod;
