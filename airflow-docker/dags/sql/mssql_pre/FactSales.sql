USE CompanyX;
SET NOCOUNT ON;

With baseTable as 
(select H.SalesOrderID,SalesOrderDetailID,H.SalesOrderID+SalesOrderDetailID as DateID,UnitPrice,UnitPriceDiscount,UnitPriceDiscount*OrderQty as ExtendedDiscount, P.StandardCost, P.StandardCost * OrderQty as ExtendedCost,LineTotal,H.OrderDate,H.DueDate,H.ShipDate,H.ModifiedDate
from (CompanyX.Sales.SalesOrderDetail D JOIN CompanyX.Sales.SalesOrderHeader H ON (D.SalesOrderID = H.SalesOrderID)) JOIN CompanyX.Production.Product P ON (D.ProductID = P.ProductID)),
ProductKey as
(select SalesOrderID,SalesOrderDetailID,P.ProductKey 
from CompanyX.Sales.SalesOrderDetail D JOIN dbo.DimProduct P ON (D.ProductID=P.ProductID)),
PromoKey as
(select SalesOrderID,SalesOrderDetailID,P.PromotionKey
from CompanyX.Sales.SalesOrderDetail D JOIN dbo.DimPromotion P ON (D.SpecialOfferID = P.SpecialOfferID)),
CustomerKey as
(select CustomerKey,SalesOrderID
from dbo.DimCustomer C JOIN CompanyX.Sales.SalesOrderHeader H ON (C.CustomerID = H.CustomerID)),
KeyAddersFirst3 as (select CK.SalesOrderID,PK.SalesOrderDetailID,CK.CustomerKey,PK.PromotionKey,PDK.ProductKey
from (CustomerKey CK JOIN PromoKey PK ON CK.SalesOrderID = PK.SalesOrderID)
JOIN ProductKey PDK ON (PDK.SalesOrderDetailID = PK.SalesOrderDetailID and PDK.SalesOrderID = PK.SalesOrderID)),
/* join sales header with territoryID */
TerritoryAdder as (
select SH.SalesOrderID,T.TerritoryID,T.TerritoryKey
from CompanyX.Sales.SalesOrderHeader SH join dbo.DimTerritory T on (SH.TerritoryID = T.TerritoryID)
),
/* join sales header with storeID*/
StoreAdder as (
select S.StoreKey,SH.SalesOrderID
from (CompanyX.Sales.Customer C join dbo.DimStore S on (C.StoreID = S.StoreID))
								right join CompanyX.Sales.SalesOrderHeader SH on (SH.CustomerID = C.CustomerID)
),
/* join with reason*/
ReasonAdder as (
select SH.SalesOrderID,R.ReasonKey
from CompanyX.Sales.SalesOrderHeader SH join dbo.DimSalesReason R on (SH.SalesOrderID = R.SalesOrderID)
),
/* join with ShipMethod */
ShipMethodAdder as (
select H.SalesOrderID,S.ShipMethodKey
from CompanyX.Sales.SalesOrderHeader H join dbo.DimShipMethod S on (H.ShipMethodID = S.ShipMethodID)
),
/*join first3 keys with territory keys together */
Key4 as (
select KA.*,TA.TerritoryKey
from KeyAddersFirst3 KA
						join TerritoryAdder TA on (KA.SalesOrderID = TA.SalesOrderID)
),
/* join first4 with ReasonKey */
Key5 as (
	select Key4.*,DimSalesReason.ReasonKey
	from Key4 left join dbo.DimSalesReason on (Key4.SalesOrderID = DimSalesReason.SalesOrderID)
),
/* join 5 keys with StoreKey*/
Key6 as (
	select distinct Key5.*,S.StoreKey
	from Key5 join StoreAdder S on (Key5.SalesOrderID = S.SalesOrderID)
),
OrderDateKeyAdder as (
	select D.DateKey, H.SalesOrderID
	from CompanyX.Sales.SalesOrderHeader H join dbo.DimDate D on (H.OrderDate = D.Date)
),
ShipDateKeyAdder as (
	select D.DateKey, H.SalesOrderID
	from CompanyX.Sales.SalesOrderHeader H join dbo.DimDate D on (H.ShipDate = D.Date)
),
DueDateKeyAdder as (
	select D.DateKey, H.SalesOrderID
	from CompanyX.Sales.SalesOrderHeader H join dbo.DimDate D on (H.DueDate = D.Date)
),
DateKeyAdder as (
	select OrderDateKeyAdder.SalesOrderID, OrderDateKeyAdder.DateKey as OrderDateKey, ShipDateKeyAdder.DateKey as ShipDateKey, DueDateKeyAdder.DateKey as DueDateKey
	from OrderDateKeyAdder join ShipDateKeyAdder on (OrderDateKeyAdder.SalesOrderID = ShipDateKeyAdder.SalesOrderID)
						   join DueDateKeyAdder  on (OrderDateKeyAdder.SalesOrderID = DueDateKeyAdder.SalesOrderID)
),
Key7 as (
	select distinct Key6.*,ShipMethodAdder.ShipMethodKey, OrderDateKey, ShipDateKey, DueDateKey
	from Key6 join ShipMethodAdder on (Key6.SalesOrderID = ShipMethodAdder.SalesOrderID)
			  join DateKeyAdder    on (Key6.SalesOrderID = DateKeyAdder.SalesOrderID)
)
insert into dbo.FactSales (
	SalesOrderID,SalesOrderDetail,ProductKey,PromotionKey,CustomerKey,TerritoryKey,StoreKey,SaleReasonKey,
	OrderQty,UnitPrice,UnitPriceDiscount,OrderDateKey,DueDateKey,ShipDateKey,
	Status,OnlineOrderFlag,TaxAllocated,Freight_Allocated,TotalDueTime,LineAmountSource,
	SalesInfoModifiedDate,ShipMethodKey
)
select distinct Key7.SalesOrderID,Key7.SalesOrderDetailID,Key7.ProductKey,Key7.PromotionKey,Key7.CustomerKey,Key7.TerritoryKey,Key7.StoreKey,Key7.ReasonKey,
D.OrderQty,D.UnitPrice,D.UnitPriceDiscount,Key7.OrderDateKey,Key7.DueDateKey,Key7.ShipDateKey,
H.Status,H.OnlineOrderFlag,H.TaxAmt,H.Freight,H.TotalDue,D.LineTotal,
(
        SELECT MAX(v)
        FROM (VALUES
                (H.ModifiedDate),
				(D.ModifiedDate)
             ) AS valueTable(v)
    ) AS ModifiedDate,
Key7.ShipMethodKey
from CompanyX.Sales.SalesOrderHeader H join CompanyX.Sales.SalesOrderDetail D on (H.SalesOrderID = D.SalesOrderID)
									   join Key7 on (H.SalesOrderID = Key7.SalesOrderID and D.SalesOrderDetailID = Key7.SalesOrderDetailID )

go
UPDATE dbo.FactSales
SET LineAmount_Gross = UnitPrice * OrderQty,
    LineDiscountAmount = UnitPrice * UnitPriceDiscount * OrderQty,
    LineAmount_Net = UnitPrice * (1-UnitPriceDiscount) * OrderQty;

UPDATE dbo.FactSales
Set TotalDue_Line = LineAmount_Net + TaxAllocated + Freight_Allocated