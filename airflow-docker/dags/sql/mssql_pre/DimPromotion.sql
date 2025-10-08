Use CompanyX;
INSERT INTO CompanyX.dbo.DimPromotion (
	SpecialOfferID,Description,Type,Category,DiscountPct,StartDate,EndDate,MinQty,MaxQty,ModifiedDate
)
select SpecialOfferID,Description,Type,Category,DiscountPct,StartDate,EndDate,MinQty,MaxQty,ModifiedDate
from CompanyX.Sales.SpecialOffer