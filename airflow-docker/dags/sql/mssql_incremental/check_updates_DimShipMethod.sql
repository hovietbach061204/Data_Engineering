USE CompanyX;
SET NOCOUNT ON;

DECLARE @WM DATETIME = '{{ watermark }}';

WITH vShipMethodWithUsage AS (
    SELECT DISTINCT
        sm.ShipMethodID,
        sm.Name,
        sm.ShipBase,
        sm.ShipRate,
        soh.ShipDate,
        sm.ModifiedDate AS ShipMethodModifiedDate,
        soh.ModifiedDate AS OrderModifiedDate
    FROM Purchasing.ShipMethod sm WITH (INDEX(IX_ShipMethod_ModifiedDate))
    LEFT JOIN Sales.SalesOrderHeader soh WITH (INDEX(IX_SalesOrderHeader_ModifiedDate))
        ON sm.ShipMethodID = soh.ShipMethodID
    WHERE
        sm.ModifiedDate > @WM OR
        soh.ModifiedDate > @WM
)

SELECT
    ShipMethodID,
    Name,
    ShipBase,
    ShipRate,
    ShipDate,
    (
        SELECT MAX(v)
        FROM (VALUES
            (ShipMethodModifiedDate),
            (OrderModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM vShipMethodWithUsage;
