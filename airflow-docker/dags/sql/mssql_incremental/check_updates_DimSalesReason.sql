-- T-SQL
USE CompanyX;
SET NOCOUNT ON;

-- Watermarks passed as parameters (Jinja2 templating)
DECLARE @WM_SalesReason DATETIME = '{{ watermark_dict["Sales.SalesReason"] }}';
DECLARE @WM_SalesOrderHeaderSalesReason DATETIME = '{{ watermark_dict["Sales.SalesOrderHeaderSalesReason"] }}';

WITH vSalesReasonWithUsage AS (
    SELECT DISTINCT
        sohr.SalesOrderID,
        sr.SalesReasonID,
        sr.Name,
        sr.ReasonType,
        sr.ModifiedDate AS SalesReasonModifiedDate,
        sohr.ModifiedDate AS OrderReasonModifiedDate
    FROM Sales.SalesReason sr WITH (INDEX(IX_SalesReason_ModifiedDate))
    JOIN Sales.SalesOrderHeaderSalesReason sohr WITH (INDEX(IX_SalesOrderHeaderSalesReason_ModifiedDate))
        ON sr.SalesReasonID = sohr.SalesReasonID
    WHERE
        sr.ModifiedDate > @WM_SalesReason OR
        sohr.ModifiedDate > @WM_SalesOrderHeaderSalesReason
)

SELECT
    CAST (SalesOrderID AS INTEGER) AS SalesOrderID,
    CAST (SalesReasonID AS INTEGER) AS SalesReasonID,
    Name,
    ReasonType,
    -- StartDate = Latest ModifiedDate from contributing tables
    (
        SELECT MAX(v)
        FROM (VALUES
            (SalesReasonModifiedDate),
            (OrderReasonModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM vSalesReasonWithUsage;
