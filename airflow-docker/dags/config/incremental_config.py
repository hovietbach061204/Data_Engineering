"""Config for incremental updates (dimensions: SCD1/2, facts: insert-only)."""

from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Literal, Dict

# --- connections / schemas ---
MSSQL_CONN_ID   = "MSSQL_SRC"
PG_CONN_ID      = "PG_DWH"
STAGING_SCHEMA  = "staging"
DWH_SCHEMA      = "dwh"

# --- SQL file roots ---
BASE_SQL              = Path("/opt/airflow/dags/sql")
MSSQL_INCREMENTAL_DIR = BASE_SQL / "mssql_incremental"
POSTGRES_MERGE_DIR    = BASE_SQL / "postgres"

Kind = Literal["dimension", "fact"]

@dataclass(frozen=True)
class TableConfig:
    name: str
    kind: Kind                       # "dimension" | "fact"
    business_key: Optional[str]      # None for facts
    sources: List[str]               # MSSQL source tables used for watermarking
    watermark_column: str = "StartDate"
    scd_type: Optional[int] = None   # 1 or 2 for dims, None for facts
    check_sql: Path = Path()         # MSSQL: change detection / extract delta
    merge_sql: Path  = Path()        # Postgres: merge from staging -> dwh

def _cfg(
    name: str,
    kind: Kind,
    *,
    business_key: Optional[str],
    sources: List[str],
    watermark_column: str = "StartDate",
    scd_type: Optional[int] = None,
) -> TableConfig:
    return TableConfig(
        name=name,
        kind=kind,
        business_key=business_key,
        sources=sources,
        watermark_column=watermark_column,
        scd_type=scd_type,
        check_sql=MSSQL_INCREMENTAL_DIR / f"check_updates_{name}.sql",
        merge_sql=POSTGRES_MERGE_DIR / f"merge_{name}.sql",
    )

# --- all tables in one dict ---
CONFIG: Dict[str, TableConfig] = {
    # Dimensions (SCD2 unless noted)
    "DimCustomer": _cfg(
        "DimCustomer", "dimension",
        business_key="customerid",
        sources=[
            "Sales.Customer","Person.Person","Person.EmailAddress","Person.Address",
            "Person.StateProvince","Person.CountryRegion","Person.BusinessEntityAddress",
            "Person.AddressType",
        ],
        scd_type=2,
    ),
    "DimProduct": _cfg(
        "DimProduct", "dimension",
        business_key="productid",
        sources=["Production.Product","Production.ProductModel","Production.ProductCategory","Production.ProductSubcategory"],
        scd_type=2,
    ),
    "DimPromotion": _cfg(
        "DimPromotion", "dimension",
        business_key="specialofferid",
        sources=["Sales.SpecialOffer"],
        scd_type=2,
    ),
    "DimSalesReason": _cfg(
        "DimSalesReason", "dimension",
        business_key="salesreasonid",
        sources=["Sales.SalesReason","Sales.SalesOrderHeaderSalesReason"],
        scd_type=2,
    ),
    "DimTerritory": _cfg(
        "DimTerritory", "dimension",
        business_key="territoryid",
        sources=["Sales.SalesTerritory","Person.CountryRegion"],
        scd_type=2,
    ),
    "DimShipMethod": _cfg(
        "DimShipMethod", "dimension",
        business_key="shipmethodid",
        sources=["Purchasing.ShipMethod","Sales.SalesOrderHeader"],
        scd_type=2,
    ),
    "DimStore": _cfg(
        "DimStore", "dimension",
        business_key="storeid",
        sources=[
            "Sales.Store","Person.BusinessEntityAddress","Person.Address","Person.StateProvince",
            "Person.CountryRegion","Person.AddressType",
        ],
        scd_type=2,
    ),
    # "DimDate": _cfg(
    #     "DimDate", "dimension",
    #     business_key="datekey",
    #     sources=["Sales.SalesOrderHeader"],  # use orders as watermark ref
    #     watermark_column="datekey",          # or whatever you emit in your delta
    #     scd_type=1,                          # SCD1 (no historization)
    # ),

    # Facts (insert-only)
    "FactSales": _cfg(
        "FactSales", "fact",
        business_key=None,
        sources=[
            # put the minimal set you watermark against for facts if you use it
            "Sales.SalesOrderHeader", "Sales.SalesOrderDetail"
        ],
        scd_type=None,
    ),
}

# convenience lists
DIM_TABLES  = [t for t, cfg in CONFIG.items() if cfg.kind == "dimension"]
FACT_TABLES = [t for t, cfg in CONFIG.items() if cfg.kind == "fact"]