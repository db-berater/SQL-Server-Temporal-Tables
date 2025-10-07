/*============================================================================
	File:		0130 - temporal tables and Dynamic Data Masking.sql

	Summary:	This script is part of the "temporal tables" session and
				demonstrates the behavior of DDM in conjunction with
				System Versioned Temporal Tables

	Date:		November 2020

	SQL Server Version: 2016 / 2017 / 2020
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

USE CustomerOrders;
GO

EXEC dbo.sp_prepare_workbench
	@create_tables = 1, -- bit
	@fill_data = 1;
GO

-- get data without masked data
SELECT	Id,
		Name,
		Phone,
		EMail,
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers;
GO

-- The PHONE number should be masked and is only allowed
-- to a dedicated group of people!
ALTER TABLE demo.Customers ALTER COLUMN [Phone]
ADD MASKED WITH (FUNCTION ='partial(2, "xxx", 5)');
GO

-- now we create a test user for the demonstration
CREATE USER demo_user WITHOUT LOGIN;
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON demo.Customers TO [demo_user];
GRANT SELECT ON history.Customers TO [demo_user];
GO

EXECUTE AS USER = 'demo_user';
GO

-- what data do we have in demo.Customers?
SELECT	Id,
		Name,
		Phone,
		EMail,
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers
WHERE	Id = 10;
GO

-- now we change the record to see what data will be stored in the history table
UPDATE	demo.Customers
SET		Name = 'db Berater GmbH'
WHERE	Id = 10;

SELECT	Id,
		Name,
		Phone,
		EMail,
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Id = 10;
GO

REVERT;
GO

-- clean the kitchen
ALTER TABLE demo.Customers
ALTER COLUMN [Phone] DROP MASKED;
GO

DROP USER demo_user;
GO

EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
	GO

IF EXISTS
(
	SELECT	*
	FROM	sys.database_principals AS DP
	WHERE	DP.name = N'demo_user'
)
	DROP USER [demo_user];
	GO
