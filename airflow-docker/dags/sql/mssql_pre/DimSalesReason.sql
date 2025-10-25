USE CompanyX;

INSERT INTO CompanyX.dbo.DimSalesReason (
    SalesOrderID,
    SalesReasonID,
    Name,
    ReasonType,
    StartDate,
    EndDate
)
SELECT DISTINCT
    soh.SalesOrderID,
    sr.SalesReasonID,
    sr.Name,
    sr.ReasonType,
    -- StartDate = Latest ModifiedDate from SalesReason or SalesOrderHeader
    CASE
        WHEN sr.ModifiedDate > soh.ModifiedDate THEN sr.ModifiedDate
        ELSE soh.ModifiedDate
    END AS StartDate,
    '9999-12-31' AS EndDate
FROM CompanyX.Sales.SalesReason AS sr
JOIN CompanyX.Sales.SalesOrderHeaderSalesReason AS soh
    ON sr.SalesReasonID = soh.SalesReasonID;