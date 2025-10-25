-- T-SQL
USE CompanyX;
SET NOCOUNT ON;

-- Watermarks passed as parameters (Jinja2 templating)
DECLARE @WM_SalesOrderHeader DATETIME = '{{ watermark_dict["Sales.SalesOrderHeader"] }}';
DECLARE @WM_SalesOrderDetail DATETIME = '{{ watermark_dict["Sales.SalesOrderDetail"] }}';

WITH vSalesOrders AS (
    SELECT
        sod.SalesOrderID,
        sod.SalesOrderDetailID AS SalesOrderDetail,
        sod.ProductID,
        sod.SpecialOfferID AS PromotionID,
        soh.CustomerID,
        soh.TerritoryID,
        soh.ShipToAddressID AS StoreID,  -- Assuming ShipTo = Store
        -- Note: SalesReasonID needs to be joined from SalesOrderHeaderSalesReason
        NULL AS SaleReasonID,  -- Will be populated if needed
        soh.ShipMethodID,
        sod.OrderQty,
        sod.UnitPrice,
        sod.UnitPriceDiscount,
        CAST(FORMAT(soh.OrderDate, 'yyyyMMdd') AS INT) AS OrderDateKey,
        CAST(FORMAT(soh.DueDate, 'yyyyMMdd') AS INT) AS DueDateKey,
        CAST(FORMAT(soh.ShipDate, 'yyyyMMdd') AS INT) AS ShipDateKey,
        soh.Status,
        soh.OnlineOrderFlag,
        -- Calculate allocated tax and freight per line
        (soh.TaxAmt * sod.LineTotal / soh.SubTotal) AS TaxAllocated,
        (soh.Freight * sod.LineTotal / soh.SubTotal) AS Freight_Allocated,
        soh.TotalDue AS TotalDueTime,
        sod.LineTotal AS LineAmountSource,
        -- Metadata
        GREATEST(soh.ModifiedDate, sod.ModifiedDate) AS SalesInfoModifiedDate,
        -- Calculated amounts
        (sod.OrderQty * sod.UnitPrice) AS LineAmount_Gross,
        (sod.OrderQty * sod.UnitPrice * sod.UnitPriceDiscount) AS LineDiscountAmount,
        sod.LineTotal AS LineAmount_Net,
        (sod.LineTotal + (soh.TaxAmt * sod.LineTotal / soh.SubTotal) + (soh.Freight * sod.LineTotal / soh.SubTotal)) AS TotalDue_Line,
        soh.ModifiedDate AS HeaderModifiedDate,
        sod.ModifiedDate AS DetailModifiedDate
    FROM Sales.SalesOrderDetail sod WITH (INDEX(IX_SalesOrderDetail_ModifiedDate))
    INNER JOIN Sales.SalesOrderHeader soh WITH (INDEX(IX_SalesOrderHeader_ModifiedDate))
        ON sod.SalesOrderID = soh.SalesOrderID
    WHERE
        soh.ModifiedDate > @WM_SalesOrderHeader OR
        sod.ModifiedDate > @WM_SalesOrderDetail
)

SELECT
    SalesOrderID,
    SalesOrderDetail,
    ProductID,
    PromotionID,
    CustomerID,
    TerritoryID,
    StoreID,
    SaleReasonID,
    ShipMethodID,
    OrderQty,
    UnitPrice,
    UnitPriceDiscount,
    OrderDateKey,
    DueDateKey,
    ShipDateKey,
    Status,
    OnlineOrderFlag,
    TaxAllocated,
    Freight_Allocated,
    TotalDueTime,
    LineAmountSource,
    SalesInfoModifiedDate,
    LineAmount_Gross,
    LineDiscountAmount,
    LineAmount_Net,
    TotalDue_Line,
    -- StartDate = Latest ModifiedDate from contributing tables
    (
        SELECT MAX(v)
        FROM (VALUES
            (HeaderModifiedDate),
            (DetailModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate
FROM vSalesOrders
ORDER BY SalesOrderID, SalesOrderDetail;
