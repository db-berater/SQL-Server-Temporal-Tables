/*
	============================================================================
	File:		01 - handling NULL in temporal tables.sql

	Summary:	This script demonstrates the problem with concurrent transactions
				in Temporal Tables

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
	Let's start an explicit transaction to understand the problematic behavior
*/
BEGIN TRANSACTION update_customer;
GO
	SELECT	CAST('Transaction Start Date:' AS CHAR(24))	AS	Info,
			DTAT.transaction_begin_time
	FROM	sys.dm_tran_current_transaction AS DTCT
			INNER JOIN sys.dm_tran_active_transactions AS DTAT
			ON (DTCT.transaction_id = DTAT.transaction_id)
	WHERE	DTAT.name = 'update_customer';
	GO

	-- Here starts the looong running business process.

	-- 'til it comes to this statement!
	UPDATE	dbo.customers
	SET		c_name = 'Uwe Ricken'
	WHERE	c_custkey = 10;
	GO
COMMIT TRANSACTION update_customer;
GO

SELECT	c.c_custkey,
        c.c_name,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	dbo.customers FOR SYSTEM_TIME ALL AS c
WHERE	c_custkey = 10
ORDER BY
		ValidFrom DESC
GO


/*
	Use the following statement in a new session when the actual
	session has the transaction opened!

USE demo_db;
GO

BEGIN TRANSACTION UpdateCustomer;
GO
	SELECT	CAST('Transaction Start Date:' AS CHAR(24))	AS	Info,
			DTAT.transaction_begin_time
	FROM	sys.dm_tran_current_transaction AS DTCT
			INNER JOIN sys.dm_tran_active_transactions AS DTAT
			ON (DTCT.transaction_id = DTAT.transaction_id)
	WHERE	DTAT.name = 'UpdateCustomer';
	GO

	UPDATE	demo.Customers
	SET		name = 'Beate Ricken'
	WHERE	Id = 10;
	GO
COMMIT TRANSACTION UpdateCustomer;
GO

SELECT	c.c_custkey,
        c.c_name,
        c.c_valid_from	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
        c.c_valid_to	AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	dbo.customers AS c
WHERE	c_custkey = 10
ORDER BY
		ValidFrom DESC
GO
*/