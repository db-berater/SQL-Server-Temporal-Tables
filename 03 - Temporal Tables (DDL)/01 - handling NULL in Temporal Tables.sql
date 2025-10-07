/*
	============================================================================
	File:		01 - handling NULL in temporal tables.sql

	Summary:	This script demonstrates the different behaviors of temporal
				tables when meta data information will be changed!

				THIS SCRIPT IS PART OF THE TRACK:
					"SQL Server Temporal Tables - deep insides"

	Date:		November 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET LANGUAGE us_english;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE demo_db;
GO

/* prepare the demo environment without new data! */
EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
    @fill_data = 0,
    @remove_all = 0;
GO

/* 1. Demo: NULL becomes NOT NULL in an empty table */
BEGIN TRANSACTION;
GO
	ALTER TABLE dbo.customers
	ALTER COLUMN c_phone CHAR(15) NOT NULL;
	GO

	SELECT	DISTINCT SCHEMA_NAME(o.schema_id) + N'.' + O.name,
			dtl.request_mode,
			dtl.request_type,
			dtl.request_status
	FROM	sys.dm_tran_locks AS dtl
			INNER JOIN sys.objects AS o
			ON (dtl.resource_associated_entity_id = O.object_id)
	WHERE	dtl.request_session_id = @@SPID
			AND dtl.resource_type = N'OBJECT'
			AND o.is_ms_shipped = 0;
	GO
COMMIT TRANSACTION;
GO

/* Let's insert one row into the new - empty - table */
BEGIN
	INSERT INTO dbo.customers
	(c_custkey, c_mktsegment, c_nationkey, c_name, c_address, c_phone, c_email, c_acctbal, c_comment)
	SELECT	c_custkey						AS	c_custkey,
			'FURNITURE'						AS	c_mktsegment,
			6								AS	c_nationkey,
			'db Berater GmbH'				AS	c_name,
			'Büchenweg 4, 64390 Erzhausen'	AS	c_address,
			'06150-11122'					AS	c_phone,
			'info@db-berater.de'			AS	c_email,
			0.00							AS	c_acctbal,
			'newly entered record'			AS	c_comment
	FROM	ERP_Demo.dbo.customers
	WHERE	c_custkey = 1;

	SELECT	c_custkey,
            c_mktsegment,
            c_nationkey,
            c_name,
            c_address,
            c_phone,
			c_email,
            c_acctbal,
            c_comment,
            c_valid_from,
            c_valid_to
	FROM	dbo.customers;
END
GO

/* NOT NULL becomes NULL in a table with existing data */
ALTER TABLE dbo.customers ALTER COLUMN [c_email] VARCHAR(100) NULL;
GO

BEGIN
	INSERT INTO dbo.customers
	(c_custkey, c_mktsegment, c_nationkey, c_name, c_address, c_phone, c_email, c_acctbal, c_comment)
	SELECT	c_custkey						AS	c_custkey,
			'SOFTWARE'						AS	c_mktsegment,
			6								AS	c_nationkey,
			'Microsoft GmbH'				AS	c_name,
			'Walter Gropius Str. 10, M'		AS	c_address,
			'089-12312312'					AS	c_phone,
			NULL							AS	c_email,
			0.00							AS	c_acctbal,
			'newly entered record'			AS	c_comment
	FROM	ERP_Demo.dbo.customers
	WHERE	c_custkey = 2;

	SELECT	c_custkey,
            c_mktsegment,
            c_nationkey,
            c_name,
            c_address,
            c_phone,
			c_email,
            c_acctbal,
            c_comment,
            c_valid_from,
            c_valid_to
	FROM	dbo.customers;
END
GO

/* Trying to change the NULL to NOT NULL will fail! */
ALTER TABLE dbo.customers ALTER COLUMN [c_email] VARCHAR(100) NOT NULL;
GO

UPDATE	dbo.customers
SET		c_email = 'info@de.microsoft.com'
WHERE	c_custkey = 2;
GO

ALTER TABLE dbo.customers ALTER COLUMN [c_email] VARCHAR(100) NOT NULL;
GO

-- Why does it not work?
-- There is a record with a NULL "value" in the history!
SELECT	c.c_custkey,
        c.c_mktsegment,
        c.c_nationkey,
        c.c_name,
        c.c_address,
        c.c_phone,
        c.c_email,
        c.c_acctbal,
        c.c_comment,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS c_valid_from,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS c_valid_to
FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
WHERE	c_custkey = 2;
GO

/* Clean the kitchen */
EXEC dbo.sp_prepare_workbench
    @remove_all = 1;
GO