USE CompanyX;

;WITH ShipBaseData AS (
    SELECT
        sm.ShipMethodID,
        sm.[Name],
        sm.ShipBase,
        sm.ShipRate,
        sm.ModifiedDate
    FROM CompanyX.Purchasing.ShipMethod AS sm
),
ShipDateData AS (
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
    sbd.ShipRate,
    sdd.ShipDate,
    sbd.ModifiedDate
INTO #ShipMethodStage
FROM ShipBaseData sbd
LEFT JOIN ShipDateData sdd
    ON sbd.ShipMethodID = sdd.ShipMethodID;

INSERT INTO dbo.DimShipMethod (
    ShipMethodID,
    [Name],
    ShipBase,
    ShipRate,
    ShipDate,
    StartDate,
    EndDate
)
SELECT
    ShipMethodID,
    [Name],
    ShipBase,
    ShipRate,
    ShipDate,
    ModifiedDate AS StartDate,  -- StartDate from ShipMethod
    '9999-12-31' AS EndDate
FROM #ShipMethodStage;

DROP TABLE #ShipMethodStage;
