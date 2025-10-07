/*
	============================================================================
	File:		02 - add columns in temporal tables.sql

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

-- prepare the workbench!
EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
	@fill_data = 1;
GO

/*
	now we change a few records by adding an email address to it
	The reason is to have a few history entries in history.customers.
*/
;WITH l
AS
(
	SELECT	TOP (10)
			c_custkey
	FROM	dbo.customers
	ORDER BY
			NEWID()
)
UPDATE	c
SET		c_email = 'this_is_a_test@online.de'
FROM	dbo.customers AS c INNER JOIN l
		ON (c.c_custkey = l.c_custkey)
GO

/*
	what will happen to the history table relationship
	when new columns will be added?
*/
ALTER TABLE dbo.customers ADD c_fax VARCHAR(20) NULL;
GO

/* update a few customers */
BEGIN
	;WITH l
	AS
	(
		SELECT	TOP (100)
				c_custkey
		FROM	dbo.customers
		ORDER BY
				NEWID()
	)
	UPDATE	c
	SET		c.c_fax = '0800-900800'
	FROM	dbo.customers AS c

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
			c.c_email,
			c.c_fax,
			c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
			c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
	FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
			INNER JOIN l ON (c.c_custkey = l.c_custkey)
	ORDER BY
			c.c_valid_to DESC;
END
GO

/*
	now we add a new NOT NULLable column to the table
	with a DEFAULT constraint.
*/
ALTER TABLE dbo.customers
ADD	[c_mobile] VARCHAR(20) NOT NULL
CONSTRAINT df_Customers_c_mobile DEFAULT ('not given');
GO

BEGIN
	;WITH l
	AS
	(
		SELECT	TOP (1000)
				c_custkey
		FROM	dbo.customers
		ORDER BY
				NEWID()
	)
	UPDATE	c
	SET		c.c_mobile = '0170-12312390'
	FROM	dbo.customers AS c

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
			c.c_email,
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


/*
	add a new NOT NULLable column with NO default...
	This will not work because of existing rows in
	history.customers.
*/
ALTER TABLE dbo.customers
ADD	[c_pager] VARCHAR(20) NOT NULL;
GO