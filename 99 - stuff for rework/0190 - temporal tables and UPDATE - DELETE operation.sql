/*============================================================================
	File:		0190 - temporal tables and UPDATE - DELETE operation.sql

	Summary:	This script demonstrates all different situations when
				an object in a temporal relationship will be renamed:
				- System Versioned Temporal Table
				- History Table
				- Column Name

	Date:		November 2016

	SQL Server Version: 2016
------------------------------------------------------------------------------
	Written by Uwe Ricken, db Berater GmbH

	This script is intended only as a supplement to demos and lectures
	given by Uwe Ricken.  
  
	THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
	TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.
============================================================================*/
USE CustomerOrders;
GO

EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
	@fill_data = 1;
GO

BEGIN TRANSACTION;
GO
	-- When did the transaction start?
	SELECT	DTAT.transaction_id,
			DTAT.name,
			DTAT.transaction_begin_time
	FROM	sys.dm_tran_current_transaction AS DTCT
			INNER JOIN sys.dm_tran_active_transactions AS DTAT
			ON (DTCT.transaction_id = DTAT.transaction_id);

	UPDATE	demo.Customers
	SET		name = 'db Berater GmbH'
	WHERE	Id = 12;
	GO

	SELECT * FROM sys.dm_tran_locks
	WHERE	request_session_id = @@SPID;
	GO

	DELETE	demo.Customers
	WHERE	Id = 12;
	GO

	SELECT * FROM sys.dm_tran_locks
	WHERE	request_session_id = @@SPID;
	GO

	SELECT [Current LSN], Operation, Context, AllocUnitName, AllocUnitId, [Slot ID], [Page ID]
	FROM sys.fn_dblog(NULL, NULL)

	SELECT * FROM history.Customers;
COMMIT TRANSACTION;
GO

SELECT * FROM history.Customers
WHERE	Id = 12;
GO

SELECT * FROM demo.Customers FOR SYSTEM_TIME ALL
WHERE	Id = 12;
GO
