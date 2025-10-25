-- T-SQL
USE CompanyX;
SET NOCOUNT ON;

-- Watermarks passed as parameters (Jinja2 templating)
DECLARE @WM_SpecialOffer DATETIME = '{{ watermark_dict["Sales.SpecialOffer"] }}';

SELECT
    SpecialOfferID,
    Description,
    DiscountPct,
    Type,
    Category,
    StartDate AS PromotionStartDate,
    EndDate AS PromotionEndDate,
    MinQty,
    MaxQty,
    -- StartDate = ModifiedDate
    ModifiedDate AS StartDate,
    '9999-12-31' AS EndDate
FROM Sales.SpecialOffer WITH (INDEX(IX_SpecialOffer_ModifiedDate))
WHERE ModifiedDate > @WM_SpecialOffer;
