-- T-SQL
USE CompanyX;
SET NOCOUNT ON;

-- Watermarks passed as parameters (Jinja2 templating)
DECLARE @WM_ShipMethod DATETIME = '{{ watermark_dict["Purchasing.ShipMethod"] }}';
DECLARE @WM_SalesOrderHeader DATETIME = '{{ watermark_dict["Sales.SalesOrderHeader"] }}';

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
        sm.ModifiedDate > @WM_ShipMethod OR
        soh.ModifiedDate > @WM_SalesOrderHeader
)

SELECT
    ShipMethodID,
    Name,
    ShipBase,
    ShipRate,
    ShipDate,
    -- StartDate = Latest ModifiedDate from contributing tables
    (
        SELECT MAX(v)
        FROM (VALUES
            (ShipMethodModifiedDate),
            (OrderModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM vShipMethodWithUsage;
