USE CompanyX;

INSERT INTO CompanyX.dbo.DimSalesReason (
    SalesOrderID,
    SalesReasonID,
    Name,
    ReasonType,
    ModifiedDate
)
SELECT DISTINCT
    soh.SalesOrderID,
    sr.SalesReasonID,
    sr.Name,
    sr.ReasonType,
    CASE
        WHEN sr.ModifiedDate > soh.ModifiedDate THEN sr.ModifiedDate
        ELSE soh.ModifiedDate
    END AS ModifiedDate
FROM CompanyX.Sales.SalesReason AS sr
JOIN CompanyX.Sales.SalesOrderHeaderSalesReason AS soh
    ON sr.SalesReasonID = soh.SalesReasonID;
