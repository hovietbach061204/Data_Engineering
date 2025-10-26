USE CompanyX;
SET NOCOUNT ON;

DECLARE @WM DATETIME = '{{ watermark }}';

WITH XMLNAMESPACES (
    'http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription' AS p1,
    'http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain' AS wm
),
vProductAndDescription AS (
    SELECT
        p.ProductID,
        p.Name,
        p.Color,
        p.Size,
        p.Weight,
        p.Style,
        pm.Name AS ModelName,
        pc.Name AS CategoryName,
        ps.Name AS SubCategoryName,
        p.StandardCost,
        p.ListPrice,
        pm.CatalogDescription.value('(/p1:ProductDescription/p1:Features/wm:Warranty/wm:WarrantyPeriod)[1]', 'nvarchar(50)') AS WarrantyPeriod,
        pm.CatalogDescription.value('(/p1:ProductDescription/p1:Features/wm:Maintenance/wm:NoOfYears)[1]', 'nvarchar(50)') AS NoOfYears,
        p.ModifiedDate AS ProductModifiedDate,
        pm.ModifiedDate AS ProductModelModifiedDate,
        pc.ModifiedDate AS ProductCategoryModifiedDate,
        ps.ModifiedDate AS ProductSubcategoryModifiedDate
    FROM Production.Product p WITH (INDEX(IX_Product_ModifiedDate))
    LEFT JOIN Production.ProductModel pm WITH (INDEX(IX_ProductModel_ModifiedDate))
        ON p.ProductModelID = pm.ProductModelID
    LEFT JOIN Production.ProductSubcategory ps WITH (INDEX(IX_ProductSubcategory_ModifiedDate))
        ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory pc WITH (INDEX(IX_ProductCategory_ModifiedDate))
        ON ps.ProductCategoryID = pc.ProductCategoryID
    WHERE
        p.ModifiedDate > @WM OR
        pm.ModifiedDate > @WM OR
        ps.ModifiedDate > @WM OR
        pc.ModifiedDate > @WM
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
    NoOfYears,
    (
        SELECT MAX(v)
        FROM (VALUES
            (ProductModifiedDate),
            (ProductModelModifiedDate),
            (ProductCategoryModifiedDate),
            (ProductSubcategoryModifiedDate)
        ) AS valueTable(v)
    ) AS StartDate,
    '9999-12-31' AS EndDate
FROM vProductAndDescription;
