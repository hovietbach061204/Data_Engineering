USE CompanyX;
SET NOCOUNT ON;

DECLARE @WM DATETIME = '{{ watermark }}';

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
        sr.ModifiedDate > @WM OR
        sohr.ModifiedDate > @WM
)

SELECT
    CAST (SalesOrderID AS INTEGER) AS SalesOrderID,
    CAST (SalesReasonID AS INTEGER) AS SalesReasonID,
    Name,
    ReasonType,
    (
        SELECT MAX(v)
        FROM (VALUES
            (SalesReasonModifiedDate),
            (OrderReasonModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM vSalesReasonWithUsage;
