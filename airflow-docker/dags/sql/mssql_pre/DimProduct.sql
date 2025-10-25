USE CompanyX;

WITH XMLNAMESPACES (
    'http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription' AS p1,
    'http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain' AS wm,
    'http://www.adventure-works.com/schemas/OtherFeatures' AS wf,
    'http://www.w3.org/1999/xhtml' AS html
),
AdditionalInfo AS (
    SELECT
        pm.Name AS ModelName,
        pm.ProductModelID,
        pm.CatalogDescription.value('(/p1:ProductDescription/p1:Features/wm:Warranty/wm:WarrantyPeriod)[1]', 'nvarchar(50)') AS WarrantyPeriod,
        pm.CatalogDescription.value('(/p1:ProductDescription/p1:Features/wm:Maintenance/wm:NoOfYears)[1]', 'nvarchar(50)') AS MaintenanceYears,
        pm.ModifiedDate AS ProductModelModifiedDate
    FROM CompanyX.Production.ProductModel pm
    WHERE pm.CatalogDescription IS NOT NULL
),
DetailedProduct AS (
    SELECT
        P.*,
        AI.WarrantyPeriod,
        AI.MaintenanceYears,
        AI.ModelName,
        AI.ProductModelModifiedDate,
        P.ModifiedDate AS ProductModifiedDate
    FROM AdditionalInfo AI
    RIGHT JOIN CompanyX.Production.Product P
        ON AI.ProductModelID = P.ProductModelID
),
FullProduct AS (
    SELECT
        P.*,
        Sc.Name AS SubCategoryName,
        C.Name AS CategoryName,
        Sc.ModifiedDate AS SubCategoryModifiedDate,
        C.ModifiedDate AS CategoryModifiedDate
    FROM (CompanyX.Production.ProductSubcategory Sc
          JOIN CompanyX.Production.ProductCategory C
              ON Sc.ProductCategoryID = C.ProductCategoryID)
    RIGHT JOIN DetailedProduct P
        ON P.ProductSubcategoryID = Sc.ProductSubcategoryID
)
INSERT INTO CompanyX.dbo.DimProduct (
    ProductID, Name, Color, Size, Weight, Style, ModelName,
    CategoryName, SubCategoryName, StandardCost, ListPrice,
    WarrantyPeriod, NoOfYears,
    StartDate, EndDate
)
SELECT
    ProductID,
    Name,
    Color,
    Size,
    Weight,
    Style,
    ModelName,
    CategoryName,
    SubCategoryName,
    StandardCost,
    ListPrice,
    WarrantyPeriod,
    FullProduct.MaintenanceYears AS NoOfYears,
    -- StartDate = Latest ModifiedDate from all four tables
    (
        SELECT MAX(v)
        FROM (VALUES
                (FullProduct.ProductModifiedDate),
                (FullProduct.ProductModelModifiedDate),
                (FullProduct.SubCategoryModifiedDate),
                (FullProduct.CategoryModifiedDate)
             ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM FullProduct;
