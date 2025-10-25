USE CompanyX;

INSERT INTO CompanyX.dbo.DimPromotion (
    SpecialOfferID, Description, Type, Category, DiscountPct,
    StartDate, EndDate, MinQty, MaxQty
)
SELECT
    SpecialOfferID,
    Description,
    Type,
    Category,
    DiscountPct,
    ModifiedDate AS StartDate,  -- StartDate from SpecialOffer
    '9999-12-31' AS EndDate,
    MinQty,
    MaxQty
FROM CompanyX.Sales.SpecialOffer;