USE CompanyX;
SET NOCOUNT ON;

IF OBJECT_ID('dbo.FactSales','U') IS NULL
    RAISERROR('dbo.FactSales does not exist – run DimCreateTable.sql first', 16, 1);

TRUNCATE TABLE dbo.FactSales;

With baseTable as 
(select H.SalesOrderID,SalesOrderDetailID,H.SalesOrderID+SalesOrderDetailID as DateID,UnitPrice,UnitPriceDiscount,UnitPriceDiscount*OrderQty as ExtendedDiscount, P.StandardCost, P.StandardCost * OrderQty as ExtendedCost,LineTotal,H.OrderDate,H.DueDate,H.ShipDate,H.ModifiedDate
from (CompanyX.Sales.SalesOrderDetail D JOIN CompanyX.Sales.SalesOrderHeader H ON (D.SalesOrderID = H.SalesOrderID)) JOIN CompanyX.Production.Product P ON (D.ProductID = P.ProductID)),
ProductKey as
(select SalesOrderID,SalesOrderDetailID,P.ProductKey 
from CompanyX.Sales.SalesOrderDetail D JOIN CompanyX.dbo.DimProduct P ON (D.ProductID=P.ProductID)),
PromoKey as 
(select SalesOrderID,SalesOrderDetailID,P.PromotionKey
from CompanyX.Sales.SalesOrderDetail D JOIN CompanyX.dbo.DimPromotion P ON (D.SpecialOfferID = P.SpecialOfferID)),
CustomerKey as
(select CustomerKey,SalesOrderID 
from CompanyX.dbo.DimCustomer C JOIN CompanyX.Sales.SalesOrderHeader H ON (C.CustomerID = H.CustomerID)),
KeyAddersFirst3 as (select CK.SalesOrderID,PK.SalesOrderDetailID,CK.CustomerKey,PK.PromotionKey,PDK.ProductKey
from (CustomerKey CK JOIN PromoKey PK ON CK.SalesOrderID = PK.SalesOrderID) 
JOIN ProductKey PDK ON (PDK.SalesOrderDetailID = PK.SalesOrderDetailID and PDK.SalesOrderID = PK.SalesOrderID)), 
/* join sales header with territoryID */
TerritoryAdder as (
select SH.SalesOrderID,T.TerritoryID,T.Territory_key
from CompanyX.Sales.SalesOrderHeader SH join CompanyX.dbo.DimTerritory T on (SH.TerritoryID = T.TerritoryID)
),
/* join sales header with storeID*/
StoreAdder as (
select S.Store_key,SH.SalesOrderID
from (CompanyX.Sales.Customer C join CompanyX.dbo.DimStore S on (C.StoreID = S.StoreID))
								right join CompanyX.Sales.SalesOrderHeader SH on (SH.CustomerID = C.CustomerID)
),
/* join with reason*/
ReasonAdder as (
select SH.SalesOrderID,R.ReasonKey
from CompanyX.Sales.SalesOrderHeader SH join CompanyX.dbo.DimSalesReason R on (SH.SalesOrderID = R.SalesOrderID)
),
/*join first3 keys with territory keys together */
Key4 as (
select KA.*,TA.Territory_key
from KeyAddersFirst3 KA 
						join TerritoryAdder TA on (KA.SalesOrderID = TA.SalesOrderID)		
),
/* join first4 with ReasonKey */
Key5 as (
	select Key4.*,DimSalesReason.ReasonKey
	from Key4 left join CompanyX.dbo.DimSalesReason on (Key4.SalesOrderID = DimSalesReason.SalesOrderID)
),
/* join 5 keys with StoreKey*/
Key6 as (
	select distinct Key5.*,S.Store_key
	from Key5 join StoreAdder S on (Key5.SalesOrderID = S.SalesOrderID)
)
insert into CompanyX.dbo.FactSales (
	SalesOrderID,SalesOrderDetail,ProductKey,PromotionKey,CustomerKey,TerritoryKey,StoreKey,SaleReasonKey,
	OrderQty,UnitPrice,UnitPriceDiscount,OrderDate,DueDate,ShipDate,
	Status,OnlineOrderFlag,TaxAllocated,Freight_Allocated,TotalDueTime,LineAmountSource,
	SalesInfoModifiedDate
)
select distinct Key6.SalesOrderID,Key6.SalesOrderDetailID,Key6.ProductKey,Key6.PromotionKey,Key6.CustomerKey,Key6.Territory_key,Key6.Store_key,Key6.ReasonKey,
D.OrderQty,D.UnitPrice,D.UnitPriceDiscount,H.OrderDate,H.DueDate,H.ShipDate,
H.Status,H.OnlineOrderFlag,H.TaxAmt,H.Freight,H.TotalDue,D.LineTotal,
(
        SELECT MAX(v)
        FROM (VALUES 
                (H.ModifiedDate),
				(D.ModifiedDate)
             ) AS valueTable(v)
    ) AS ModifiedDate
from CompanyX.Sales.SalesOrderHeader H join CompanyX.Sales.SalesOrderDetail D on (H.SalesOrderID = D.SalesOrderID) 
									   join Key6 on (H.SalesOrderID = Key6.SalesOrderID and D.SalesOrderDetailID = Key6.SalesOrderDetailID )

go
UPDATE CompanyX.dbo.FactSales
SET LineAmount_Gross = UnitPrice * OrderQty,
    LineDiscountAmount = UnitPrice * UnitPriceDiscount * OrderQty,
    LineAmount_Net = UnitPrice * (1-UnitPriceDiscount) * OrderQty;

UPDATE CompanyX.dbo.FactSales
Set TotalDue_Line = LineAmount_Net + TaxAllocated + Freight_Allocated