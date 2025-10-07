/*============================================================================
	File:		0120 - temporal tables and security.sql

	Summary:	This script is part of the "temporal tables"

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
SET NOCOUNT ON;
GO

USE CustomerOrders;
GO

EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
	@fill_data = 1;
GO

-- Creation of a standard user for access to dbo.Customers
CREATE USER demo_user WITHOUT LOGIN;
GO

-- grant SELECT, INSERT, UPDATE, DELETE permissions
-- on the demo.Customer object
GRANT	SELECT,
		INSERT,
		UPDATE,
		DELETE
ON		demo.Customers
TO		demo_user;
GO

-- do some actions as demo_user 
EXECUTE AS USER = N'demo_user';
GO
	-- SELECT a dedicated customer from the dbo.Customer table
	SELECT * FROM demo.Customers WHERE Id = 10;
	GO

	-- Update the customer
	UPDATE	demo.Customers
	SET		Name = 'db Berater GmbH'
	WHERE	Id = 10;
	GO

	-- SELECT the customer again
	SELECT * FROM demo.Customers
	WHERE Id = 10;
	GO

	-- Now select the customers old status
	SELECT * FROM demo.Customers
	FOR SYSTEM_TIME ALL AS C
	WHERE	Id = 10;
	GO

REVERT;
GO

-- workaround #1: grant SELECT permission on the object
-- to the user :(
GRANT SELECT ON history.Customers
TO demo_user;
GO

-- Now select the customers old status
EXECUTE AS USER = N'demo_user';
GO

	SELECT * FROM demo.Customers
	FOR SYSTEM_TIME ALL AS C
	WHERE	Id = 10;
	GO

REVERT;
GO

REVOKE SELECT ON history.Customers TO demo_user;
GO

-- workaround #2: cover the access by a tvf
IF OBJECT_ID(N'demo.fn_Customers', N'IF') IS NOT NULL
	DROP FUNCTION demo.fn_Customers;
	GO

CREATE FUNCTION demo.fn_Customers(@Id INT, @SystemTime DATETIME2)
RETURNS TABLE
AS
RETURN
	(
		SELECT Id, NAME, Street, ZIP, City, Phone, EMail
		FROM demo.Customers
		FOR SYSTEM_TIME AS OF @SystemTime
		WHERE
		(
			Id = @Id OR
			0 = @Id
		)
	);
GO

GRANT SELECT ON demo.fn_Customers TO demo_user;
GO

-- do some actions as demo_user 
EXECUTE AS USER = N'demo_user';
GO
	-- SELECT a dedicated customer from the dbo.Customer table
	SELECT * FROM demo.fn_Customers(10, GETUTCDATE());
	GO

REVERT;
GO

-- clean the kitchen!
IF OBJECT_ID(N'demo.fn_Customers', N'IF') IS NOT NULL
	DROP FUNCTION demo.fn_Customers;
	GO

IF EXISTS (SELECT * FROM sys.database_principals AS DP WHERE name = N'demo_user')
	DROP USER [demo_user];
	GO

EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
GO