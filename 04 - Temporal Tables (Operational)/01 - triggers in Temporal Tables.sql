/*
	============================================================================
	File:		01 - handling NULL in temporal tables.sql

	Summary:	This script demonstrates the problems with triggers in a
				System Versioned Temporal Table

				THIS SCRIPT IS PART OF THE TRACK:
					"SQL Server Temporal Tables - deep insides"

	Date:		November 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE demo_db;
GO

/* create demo environment with data */
EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
    @fill_data = 1,
    @remove_all = 0;
GO

/*
	The business requires an additional column [c_update_user] in the
	Sytem Versioned Temporal Table for the storage of the user name
	who did inserts/updates/deletes on a row
*/
IF NOT EXISTS
(
	SELECT * FROM sys.columns
	WHERE	OBJECT_ID = OBJECT_ID(N'dbo.customers', N'U')
			AND name = 'c_update_user'
)
	ALTER TABLE dbo.customers
	ADD c_update_user sysname NOT NULL
	CONSTRAINT df_customers_c_update_user DEFAULT ('unknown');
	GO

SELECT	c_custkey,
        c_name,
        c_update_user,
		c_valid_from,
        c_valid_to
FROM	dbo.customers;
GO

/*
	The development teams tries to cover the request with a trigger
	which fires for an UPDATE...
*/
CREATE OR ALTER TRIGGER dbo.trg_customers_update
ON dbo.customers
AFTER UPDATE
AS
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	UPDATE	c
	SET		C.c_update_user = ORIGINAL_LOGIN()
	FROM	dbo.customers AS c INNER JOIN inserted AS i
			ON (c.c_custkey = i.c_custkey);
GO

-- Let's play with the data...
SELECT	c.c_custkey,
        c.c_mktsegment,
        c.c_nationkey,
        c.c_name,
        c.c_address,
        c.c_phone,
        c.c_email,
        c.c_acctbal,
        c.c_comment,
        c.c_update_user,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
WHERE	c.c_custkey = 10;
GO

/* Let's update the company name of the customer 10 */
UPDATE	dbo.customers
SET		c_name = 'db Berater GmbH'
WHERE	c_custkey = 10;
GO

/*
	How many records do you expect in the result set?
	Have a look into the pushdown predicate!
*/
SELECT	c.c_custkey,
        c.c_mktsegment,
        c.c_nationkey,
        c.c_name,
        c.c_address,
        c.c_phone,
        c.c_email,
        c.c_acctbal,
        c.c_comment,
        c.c_update_user,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
WHERE	c.c_custkey = 10;
GO

-- ... and how many records do we have in the history?
SELECT	c.c_custkey,
        c.c_mktsegment,
        c.c_nationkey,
        c.c_name,
        c.c_address,
        c.c_phone,
        c.c_email,
        c.c_acctbal,
        c.c_comment,
        c.c_update_user,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	history.customers AS c
WHERE	c_custkey = 10
ORDER BY
		ValidFrom DESC;
GO

/* Clean the kitchen before the next step! */
DROP TRIGGER dbo.trg_customers_update;
GO

/*
	INSTEAD OF Triggers are not allowed in System Versioned Temporal Tables!
	But with a view on the table it is possible to have INSTEAD OF Triggers
	working!
*/
CREATE OR ALTER VIEW dbo.v_customers
WITH SCHEMABINDING
AS
	SELECT	c.c_custkey,
            c.c_mktsegment,
            c.c_nationkey,
            c.c_name,
            c.c_address,
            c.c_phone,
            c.c_email,
            c.c_acctbal,
            c.c_comment,
            c.c_update_user,
            c.c_valid_from,
            c.c_valid_to
	FROM	dbo.customers AS c;
GO

-- Now we create an INSTEAD_OF Trigger on the view but not on the table
CREATE OR ALTER TRIGGER dbo.trg_v_customers_update
ON dbo.v_customers
INSTEAD OF UPDATE
AS
	SET NOCOUNT ON;

	UPDATE	c
	SET		c.c_mktsegment  =   i.c_mktsegment,
            c.c_nationkey   =   i.c_nationkey,
            c.c_name        =   i.c_name,
            c.c_address     =   i.c_address,
            c.c_phone       =   i.c_phone,
            c.c_email       =   i.c_email,
            c.c_acctbal     =   i.c_acctbal,
            c.c_comment     =   i.c_comment,
            c.c_update_user =	ORIGINAL_LOGIN()
	FROM	dbo.customers AS c
			INNER JOIN inserted AS i
			ON (c.c_custkey = i.c_custkey)
GO

-- Play with the data!
SELECT	c.c_custkey,
        c.c_mktsegment,
        c.c_nationkey,
        c.c_name,
        c.c_address,
        c.c_phone,
        c.c_email,
        c.c_acctbal,
        c.c_comment,
        c.c_update_user,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	dbo.customers AS c
WHERE	c_custkey = 11
ORDER BY
		ValidFrom DESC
GO

UPDATE	dbo.v_customers
SET		c_name = 'Microsoft GmbH'
WHERE	c_custkey = 11;
GO

-- What changes have been logged?
SELECT	c.c_custkey,
        c.c_name,
        c.c_update_user,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	dbo.customers AS c
WHERE	c_custkey = 11
ORDER BY
		ValidFrom DESC
GO

/* How many history entries do we have for customer 11? */
SELECT  c_custkey,
        c_mktsegment,
        c_nationkey,
        c_name,
        c_address,
        c_phone,
        c_email,
        c_acctbal,
        c_comment,
        c_valid_from,
        c_valid_to,
        c_update_user
FROM    history.Customers
WHERE   c_custkey = 11;
GO

-- Clean the kitchen
DROP VIEW IF EXISTS dbo.v_customers;
GO

EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
GO
