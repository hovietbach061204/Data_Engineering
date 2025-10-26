USE CompanyX;
SET NOCOUNT ON;

DECLARE @WM DATETIME = '{{ watermark }}';

SELECT
    SpecialOfferID,
    Description,
    DiscountPct,
    Type,
    Category,
    StartDate AS PromotionStartDate,
    EndDate AS PromotionEndDate,
    CAST(MinQty AS INTEGER) AS MinQty,
    CAST(MaxQty AS INTEGER) AS MaxQty,
    ModifiedDate AS StartDate,
    '9999-12-31' AS EndDate
FROM Sales.SpecialOffer WITH (INDEX(IX_SpecialOffer_ModifiedDate))
WHERE ModifiedDate > @WM;
