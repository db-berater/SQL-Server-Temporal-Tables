/*
	============================================================================
	File:		03 - drop columns in Temporal Tables.sql

	Summary:	This script demonstrates the handling of temporal tables
				when new columns will be added or existing columns will
				be dropped from a table.

	Date:		November 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE demo_db;
GO

/*
	HOW ABOUT DROPPING COLUMNS???
	DO NOT DO THIS IN PRODUCTION!!!
	DO NOT DO THIS IN PRODUCTION!!!
	DO NOT DO THIS IN PRODUCTION!!!	
*/
BEGIN
	IF EXISTS
	(
		SELECT * FROM sys.columns AS c
		WHERE	c.object_id = OBJECT_ID(N'dbo.customers', N'U')
				AND c.name = N'c_email'
	)
		ALTER TABLE dbo.customers DROP COLUMN [c_email];

	;WITH l (c_custkey)
	AS
	(
		SELECT	TOP (1)
				c.c_custkey
		FROM	history.customers AS c
		GROUP BY
				c.c_custkey
		ORDER BY
				COUNT_BIG(*) DESC
	)
	SELECT	c.c_custkey,
			c.c_name,
			c.c_fax,
			c.c_mobile,
			c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
			c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
	FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
			INNER JOIN l ON (c.c_custkey = l.c_custkey)
	ORDER BY
			c.c_valid_to DESC;
END
GO

/* Clean the kitchen */
EXEC dbo.sp_prepare_workbench
	@create_tables = 0,
	@fill_data = 0,
    @remove_all = 1;
	GO