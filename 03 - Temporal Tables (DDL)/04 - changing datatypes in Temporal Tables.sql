/*
	============================================================================
	File:		04 - 04 - changing datatypes in temporal tables.sql

	Summary:	This script demonstrates the handling of temporal tables
				when data types will be changed..

	Date:		November 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE demo_db;
GO

EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
    @fill_data = 1,
    @remove_all = 0;
GO

/*
	get an overview from the columns in demo table!
*/
BEGIN
	SELECT	c.name,
			t.name			AS	data_type,
			c.max_length,
			c.collation_name
	FROM	sys.columns AS c INNER JOIN sys.types AS t
			ON
			(
				c.system_type_id = T.system_type_id
				AND c.user_type_id = T.user_type_id
			)
	WHERE	c.object_id = OBJECT_ID(N'dbo.customers', N'U')
	ORDER BY
			c.column_id;

	/*
		What is the max length for a company name and for a street name?
	*/
	SELECT	MAX(DATALENGTH(c_name))		AS	c_name,
			MAX(DATALENGTH(c_address))	AS	c_address,
			MAX(DATALENGTH(c_comment))	AS	c_comment
	FROM	dbo.customers;
END
GO

/*
	can we reduce the data length from c_name from 25 characters
	to 20 characters?
*/
BEGIN
	ALTER TABLE dbo.customers
	ALTER COLUMN c_name VARCHAR(20) NOT NULL;

	SELECT	c.name,
			t.name			AS	data_type,
			c.max_length,
			c.collation_name
	FROM	sys.columns AS c INNER JOIN sys.types AS t
			ON
			(
				c.system_type_id = T.system_type_id
				AND c.user_type_id = T.user_type_id
			)
	WHERE	c.object_id = OBJECT_ID(N'dbo.customers', N'U')
	ORDER BY
			c.column_id;

	/*
		What is the max length for a company name and for a street name?
	*/
	SELECT	MAX(DATALENGTH(c_name))		AS	c_name,
			MAX(DATALENGTH(c_address))	AS	c_address,
			MAX(DATALENGTH(c_comment))	AS	c_comment
	FROM	dbo.customers;
END
GO

/*
	What will happen if we have an longer entry in the
	history.customers table?

	Step 1:	Expand the column length of c_name
			from 20 bytes to 100 bytes
*/
ALTER TABLE dbo.customers ALTER COLUMN c_name VARCHAR(100) NOT NULL;

/*
	Step 2:	we now change one customer name from 18 bytes
			to 60 bytes and afterwards we turn it back
			to 20 bytes.

			This will add the previous UPDATE into the history.customers
			table!
*/
UPDATE	dbo.customers
SET		c_name = REPLICATE('A', 60)
WHERE	c_custkey = 5;
GO

UPDATE	dbo.customers
SET		c_name = REPLICATE('B', 20)
WHERE	c_custkey = 5;
GO

SELECT	c.c_custkey,
        c.c_name,
        c.c_valid_from,
        c.c_valid_to
FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
WHERE	c_custkey = 5;
GO

/*
	now we try to turn back the length of c_name
	from 100 to 20 characters!
*/
ALTER TABLE dbo.customers
ALTER COLUMN c_name VARCHAR(20) NOT NULL;
GO

/*
	without releasing SYSTEM VERSIONING a change of the columns
	is not possible because of truncation of data
*/
BEGIN TRANSACTION
GO
	/* Disabling System Versioning */
	ALTER TABLE dbo.customers SET (SYSTEM_VERSIONING = OFF);
	GO
	
	/* Change the meta data of the user table */
	ALTER TABLE dbo.customers ALTER COLUMN c_name VARCHAR(20) NOT NULL;
	GO

	/* Change the meta data of the history table */
	UPDATE	history.customers
	SET		c_name = LEFT(c_name, 20)
	WHERE	LEN(c_name) > 20;
	GO

	ALTER TABLE history.customers ALTER COLUMN c_name VARCHAR(20) NOT NULL;
	GO

	/* Enabling System Versioning */
	ALTER TABLE dbo.customers
	SET
	(
		SYSTEM_VERSIONING = ON
		(HISTORY_TABLE = history.Customers)	
	);
	GO
COMMIT TRANSACTION
GO

/* See the results ... */
SELECT	c.c_custkey,
        c.c_name,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
WHERE	c.c_custkey = 5;
GO

/* Clean the kitchen! */
EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
	GO