-- Create watermark tracking table
CREATE SCHEMA IF NOT EXISTS metadata;

CREATE TABLE IF NOT EXISTS metadata.watermarks (
    table_name     varchar(100) PRIMARY KEY,
    last_watermark timestamp NOT NULL,
    updated_at     timestamp DEFAULT CURRENT_TIMESTAMP
);

-- Seed once (safe to re-run)
INSERT INTO metadata.watermarks (table_name, last_watermark)
VALUES
  ('Sales.Customer',                '1900-01-01'),
  ('Person.Person',                 '1900-01-01'),
  ('Person.BusinessEntityAddress',  '1900-01-01'),
  ('Person.AddressType',            '1900-01-01'),
  ('Person.EmailAddress',           '1900-01-01'),
  ('Person.Address',                '1900-01-01'),
  ('Person.StateProvince',          '1900-01-01'),
  ('Person.CountryRegion',          '1900-01-01'),
  ('Production.Product',            '1900-01-01'),
  ('Production.ProductCategory',    '1900-01-01'),
  ('Production.ProductSubcategory', '1900-01-01'),
  ('Production.ProductModel',       '1900-01-01'),
  ('Sales.SpecialOffer',            '1900-01-01'),
  ('Sales.SalesReason',             '1900-01-01'),
  ('Purchasing.ShipMethod',         '1900-01-01'),
  ('Sales.Store',                   '1900-01-01'),
  ('Sales.SalesTerritory',          '1900-01-01'),
  ('Sales.SalesOrderHeader',        '1900-01-01'),
  ('Sales.SalesOrderDetail',        '1900-01-01')
ON CONFLICT (table_name) DO NOTHING;

-- Update function
CREATE OR REPLACE FUNCTION metadata.update_watermark(
    p_table_name varchar(100),
    p_new_watermark timestamp
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE metadata.watermarks
       SET last_watermark = p_new_watermark,
           updated_at     = CURRENT_TIMESTAMP
     WHERE table_name     = p_table_name;
END;
$$;

-- Get function
CREATE OR REPLACE FUNCTION metadata.get_watermark(
    p_table_name varchar(100)
) RETURNS timestamp
LANGUAGE plpgsql
AS $$
DECLARE
    v_watermark timestamp;
BEGIN
    SELECT last_watermark INTO v_watermark
      FROM metadata.watermarks
     WHERE table_name = p_table_name;

    RETURN COALESCE(v_watermark, '1900-01-01'::timestamp);
END;
$$;