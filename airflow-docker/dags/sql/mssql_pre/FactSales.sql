USE CompanyX;
SET NOCOUNT ON;

;WITH
-- 1) map detail lines to surrogate product key
ProductKey AS (
    SELECT
        d.SalesOrderID,
        d.SalesOrderDetailID,
        p.ProductKey
    FROM CompanyX.Sales.SalesOrderDetail AS d
    JOIN dbo.DimProduct                 AS p ON p.ProductID = d.ProductID
),

-- 2) map detail lines to surrogate promotion key
PromoKey AS (
    SELECT
        d.SalesOrderID,
        d.SalesOrderDetailID,
        pr.PromotionKey
    FROM CompanyX.Sales.SalesOrderDetail AS d
    JOIN dbo.DimPromotion               AS pr ON pr.SpecialOfferID = d.SpecialOfferID
),

-- 3) map order header to surrogate customer key
CustomerKey AS (
    SELECT
        c.CustomerKey,
        h.SalesOrderID
    FROM dbo.DimCustomer                AS c
    JOIN CompanyX.Sales.SalesOrderHeader AS h ON h.CustomerID = c.CustomerID
),

-- 4) combine product/promo/customer keys
Keys3 AS (
    SELECT
        ck.SalesOrderID,
        pk.SalesOrderDetailID,
        ck.CustomerKey,
        pk.PromotionKey,
        prk.ProductKey
    FROM CustomerKey AS ck
    JOIN PromoKey    AS pk  ON pk.SalesOrderID       = ck.SalesOrderID
    JOIN ProductKey  AS prk ON prk.SalesOrderID      = pk.SalesOrderID
                           AND prk.SalesOrderDetailID = pk.SalesOrderDetailID
),

-- 5) add territory (from header)
TerritoryMap AS (
    SELECT
        sh.SalesOrderID,
        t.TerritoryID,
        t.TerritoryKey
    FROM CompanyX.Sales.SalesOrderHeader AS sh
    JOIN dbo.DimTerritory                AS t  ON t.TerritoryID = sh.TerritoryID
),

-- 6) add store (via customer -> header)
StoreMap AS (
    SELECT
        s.StoreKey,
        sh.SalesOrderID
    FROM CompanyX.Sales.Customer         AS c
    JOIN dbo.DimStore                    AS s  ON s.StoreID     = c.StoreID
    RIGHT JOIN CompanyX.Sales.SalesOrderHeader AS sh ON sh.CustomerID = c.CustomerID
),

-- 7) add sales reason (per order)
ReasonMap AS (
    SELECT
        sh.SalesOrderID,
        r.SalesReasonKey
    FROM CompanyX.Sales.SalesOrderHeader AS sh
    JOIN dbo.DimSalesReason              AS r  ON r.SalesOrderID = sh.SalesOrderID
),

-- 8) add ship method (from header)
ShipMethodMap AS (
    SELECT
        h.SalesOrderID,
        sm.ShipMethodKey
    FROM CompanyX.Sales.SalesOrderHeader AS h
    JOIN dbo.DimShipMethod               AS sm ON sm.ShipMethodID = h.ShipMethodID
),

-- 9) combine Keys3 + territory
Keys4 AS (
    SELECT
        k3.*,
        tm.TerritoryKey
    FROM Keys3       AS k3
    JOIN TerritoryMap AS tm ON tm.SalesOrderID = k3.SalesOrderID
),

-- 10) add optional SalesReasonKey
Keys5 AS (
    SELECT
        k4.*,
        rs.SalesReasonKey
    FROM Keys4 AS k4
    LEFT JOIN dbo.DimSalesReason AS rs ON rs.SalesOrderID = k4.SalesOrderID
),

-- 11) add store
Keys6 AS (
    SELECT DISTINCT
        k5.*,
        s.StoreKey
    FROM Keys5   AS k5
    JOIN StoreMap AS s ON s.SalesOrderID = k5.SalesOrderID
),

-- 12) date keys
OrderDateKey AS (
    SELECT d.DateKey, h.SalesOrderID
    FROM CompanyX.Sales.SalesOrderHeader AS h
    JOIN dbo.DimDate                     AS d ON d.[Date] = h.OrderDate
),
ShipDateKey AS (
    SELECT d.DateKey, h.SalesOrderID
    FROM CompanyX.Sales.SalesOrderHeader AS h
    JOIN dbo.DimDate                     AS d ON d.[Date] = h.ShipDate
),
DueDateKey AS (
    SELECT d.DateKey, h.SalesOrderID
    FROM CompanyX.Sales.SalesOrderHeader AS h
    JOIN dbo.DimDate                     AS d ON d.[Date] = h.DueDate
),

DateKeys AS (
    SELECT
        od.SalesOrderID,
        od.DateKey AS OrderDateKey,
        sd.DateKey AS ShipDateKey,
        dd.DateKey AS DueDateKey
    FROM OrderDateKey AS od
    JOIN ShipDateKey  AS sd ON sd.SalesOrderID = od.SalesOrderID
    JOIN DueDateKey   AS dd ON dd.SalesOrderID = od.SalesOrderID
),

-- 13) final key set: add ship method + all date keys
KeysFinal AS (
    SELECT DISTINCT
        k6.*,
        sm.ShipMethodKey,
        dk.OrderDateKey,
        dk.ShipDateKey,
        dk.DueDateKey
    FROM Keys6        AS k6
    JOIN ShipMethodMap AS sm ON sm.SalesOrderID = k6.SalesOrderID
    JOIN DateKeys      AS dk ON dk.SalesOrderID = k6.SalesOrderID
)

-- 14) load FactSales
INSERT INTO dbo.FactSales (
      SalesOrderID
    , SalesOrderDetail
    , ProductKey
    , PromotionKey
    , CustomerKey
    , TerritoryKey
    , StoreKey
    , SalesReasonKey
    , OrderQty
    , UnitPrice
    , UnitPriceDiscount
    , OrderDateKey
    , DueDateKey
    , ShipDateKey
    , Status
    , OnlineOrderFlag
    , TaxAllocated
    , Freight_Allocated
    , TotalDueTime
    , LineAmountSource
    , SalesInfoModifiedDate
    , ShipMethodKey
)
SELECT DISTINCT
      kf.SalesOrderID
    , kf.SalesOrderDetailID
    , kf.ProductKey
    , kf.PromotionKey
    , kf.CustomerKey
    , kf.TerritoryKey
    , kf.StoreKey
    , kf.SalesReasonKey
    , d.OrderQty
    , d.UnitPrice
    , d.UnitPriceDiscount
    , kf.OrderDateKey
    , kf.DueDateKey
    , kf.ShipDateKey
    , h.Status
    , h.OnlineOrderFlag
    , h.TaxAmt
    , h.Freight
    , h.TotalDue
    , d.LineTotal
    , (
        SELECT MAX(v)
        FROM (VALUES (h.ModifiedDate), (d.ModifiedDate)) AS vt(v)
      ) AS SalesInfoModifiedDate
    , kf.ShipMethodKey
FROM CompanyX.Sales.SalesOrderHeader AS h
JOIN CompanyX.Sales.SalesOrderDetail AS d
      ON d.SalesOrderID = h.SalesOrderID
JOIN KeysFinal AS kf
      ON kf.SalesOrderID      = h.SalesOrderID
     AND kf.SalesOrderDetailID = d.SalesOrderDetailID;
GO

-- 15) post-load derived amounts
UPDATE dbo.FactSales
SET
    LineAmount_Gross    = UnitPrice * OrderQty,
    LineDiscountAmount  = UnitPrice * UnitPriceDiscount * OrderQty,
    LineAmount_Net      = UnitPrice * (1 - UnitPriceDiscount) * OrderQty;

UPDATE dbo.FactSales
SET
    TotalDue_Line = LineAmount_Net + TaxAllocated + Freight_Allocated;