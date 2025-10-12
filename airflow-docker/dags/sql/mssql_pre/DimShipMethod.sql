Use CompanyX;
/* =======================================================================
   STEP 1) Stage ShipMethod data
   ======================================================================= */

IF OBJECT_ID('tempdb..#ShipMethodStage') IS NOT NULL DROP TABLE #ShipMethodStage;

;WITH ShipBaseData AS
(
    SELECT
        sm.ShipMethodID,
        sm.[Name],
        sm.ShipBase,
        sm.ModifiedDate
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
    sdd.ShipDate,
    sbd.ModifiedDate
INTO #ShipMethodStage
FROM ShipBaseData sbd
LEFT JOIN ShipDateData sdd
       ON sbd.ShipMethodID = sdd.ShipMethodID;
SELECT * FROM #ShipMethodStage;


INSERT INTO dbo.DimShipMethod
(
    ShipMethodID,
    [Name],
    ShipBase,
    ShipDate,
    ModifiedDate
)
SELECT
    ShipMethodID,
    [Name],
    ShipBase,
    ShipDate,
    ModifiedDate
FROM #ShipMethodStage;

