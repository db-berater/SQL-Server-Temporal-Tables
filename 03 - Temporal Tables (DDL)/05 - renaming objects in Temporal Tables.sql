/*
	============================================================================
	File:		05 - renaming objects in Temporal Tables.sql

	Summary:	This script demonstrates all different situations when
				an object in a temporal relationship will be renamed:
				- System Versioned Temporal Table
				- History Table
				- Column Name

	Date:		November 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE demo_db;
GO

DROP TABLE IF EXISTS dbo.new_customers;
GO

EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
    @fill_data = 1,
    @remove_all = 0;
GO

/* what is the relation between both tables */
SELECT	object_id,
		QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name)	AS	table_name,
		temporal_type,
		temporal_type_desc,
		history_table_id
FROM	sys.tables AS t
WHERE	object_id = OBJECT_ID(N'dbo.customers', N'U')

UNION ALL

SELECT	object_id,
		QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name)	AS	table_name,
		temporal_type,
		temporal_type_desc,
		history_table_id
FROM	sys.tables
WHERE	object_id = OBJECT_ID(N'history.customers', N'U');
GO

/* Now we try to rename the SYSTEM_VERSIONED_TEMPORAL_TABLE! */
EXEC sp_rename
	@objname = N'dbo.customers',
	@newname = N'new_customers',
	@objtype = N'OBJECT';
GO

-- what is the relation between both tables
SELECT	object_id,
		QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name)	AS	table_name,
		temporal_type,
		temporal_type_desc,
		history_table_id
FROM	sys.tables AS t
WHERE	object_id = OBJECT_ID(N'dbo.new_customers', N'U')

UNION ALL

SELECT	object_id,
		QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name)	AS	table_name,
		temporal_type,
		temporal_type_desc,
		history_table_id
FROM	sys.tables
WHERE	object_id = OBJECT_ID(N'history.customers', N'U');
GO

/* what about renaming the history table? */
EXEC sp_rename
	@objname = N'history.customers',
	@newname = N'new_customers',
	@objtype = N'OBJECT';
GO

/* what is the relation between both tables */
SELECT	object_id,
		QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name)	AS	TableName,
		temporal_type,
		temporal_type_desc,
		history_table_id
FROM	sys.tables
WHERE	object_id = OBJECT_ID(N'dbo.new_customers', N'U')

UNION ALL

SELECT	object_id,
		QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name)	AS	TableName,
		temporal_type,
		temporal_type_desc,
		history_table_id
FROM	sys.tables
WHERE	object_id = OBJECT_ID(N'history.new_customers', N'U');
GO

/*
	What about the renaming of columns in a SYSTEM_VERSIONED_TEMPORAL_TABLE?
*/
EXEC sp_rename
	@objname = N'dbo.new_customers.c_name',
	@newname = N'c_company_name',
	@objtype = N'COLUMN';
GO

-- will it work with renaming a column in the history table?
EXEC sp_rename
	@objname = N'history.new_customers.c_address',
	@newname = N'c_company_address',
	@objtype = N'COLUMN';
GO

-- Clean the kitchen!
ALTER TABLE dbo.new_customers SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS history.new_customers;
DROP TABLE IF EXISTS dbo.new_customers;
GO