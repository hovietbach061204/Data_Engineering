-- Use target database
USE [CompanyX];
GO
SET NOCOUNT ON;

-- Ensure schema exists
IF SCHEMA_ID(N'dbo') IS NULL
BEGIN
    PRINT N'Schema [dbo] not found.';
    RETURN;
END

-- 1) Drop FKs that reference tables in schema dbo (from any schema)
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = COALESCE(@sql + CHAR(10), N'') +
       N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) +
       N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
FROM sys.foreign_keys AS fk
WHERE OBJECT_SCHEMA_NAME(fk.referenced_object_id) = N'dbo';

IF LEN(@sql) > 0
BEGIN
    PRINT N'Dropping foreign keys referencing [dbo]...';
    EXEC sp_executesql @sql;
END

-- 2) Drop all tables in schema dbo
SET @sql = N'';

SELECT @sql = COALESCE(@sql + CHAR(10), N'') +
       N'DROP TABLE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N';'
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'dbo';

IF LEN(@sql) > 0
BEGIN
    PRINT N'Dropping tables in schema [dbo]...';
    EXEC sp_executesql @sql;
END
ELSE
BEGIN
    PRINT N'No tables found in schema [dbo].';
END
