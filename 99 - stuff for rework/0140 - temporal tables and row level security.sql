/*============================================================================
	File:		0140 - temporal tables and row level security.sql

	Summary:	This script is part of the "temporal tables" session and
				demonstrates the behavior of row level security in conjunction
				with System Versioned Temporal Tables

	Date:		November 2020

	SQL Server Version: 2016 / 2017 / 2019
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
	@create_tables = 1, -- bit
	@fill_data = 1;
GO

-- Now we create the environment for the demos
-- 3 database roles will be created for the alphabetic preselection of customers
CREATE ROLE [A-H] AUTHORIZATION [dbo];
CREATE ROLE [I-P] AUTHORIZATION [dbo];
CREATE ROLE [Q-Z] AUTHORIZATION [dbo];
GO

-- a demo user will be created who is member of the [A-H] group
CREATE USER demo_user WITHOUT LOGIN;
GO

ALTER ROLE [A-H] ADD MEMBER [demo_user];
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON demo.Customers TO [demo_user];
GRANT SELECT ON history.Customers TO [demo_user];
GO

-- now we add a new column to the demo.Customers for the group assignment
BEGIN TRANSACTION;
GO
	-- add a new column which will be used for the filter!
	ALTER TABLE demo.Customers ADD [dbRole] NCHAR(3) NULL;
	GO

	-- disable system versioning to update the rows without
	-- entering history data into the history.Customers table!
	ALTER TABLE demo.Customers SET (SYSTEM_VERSIONING = OFF);

	-- update the demo.Customers table...
	UPDATE	demo.Customers
	SET		[dbRole] =	CASE
							WHEN Name < 'I' THEN 'A-H'
							WHEN Name >= 'I' AND Name < 'Q' THEN 'I-P'
							ELSE 'Q-Z'
						END
	WHERE	[dbRole] IS NULL;
	GO

	-- Enable system versioning
	ALTER TABLE demo.Customers SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = history.Customers));
	GO
COMMIT TRANSACTION;
GO

-- Check the tables!
SELECT	Id,
		Name,
		[dbRole],
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers;
GO


-- Now we create the row level security function which MUST be
-- an INLINE Tablevalued function!
CREATE FUNCTION demo.fn_RowSelection(@dbRole NCHAR(3))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
	SELECT	1	AS Result
	WHERE	IS_MEMBER(@dbRole) = 1

	UNION

	SELECT	1	AS Result
	WHERE	IS_MEMBER(N'db_owner') = 1
);
GO

-- Activate the security role
CREATE SECURITY POLICY CustomerFilter
ADD FILTER PREDICATE demo.fn_RowSelection([dbRole])   
ON demo.Customers
WITH (STATE = ON);
GO

EXECUTE AS USER = 'demo_user';
GO

-- Select the data!
SELECT	Id,
		Name,
		[dbRole],
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers
ORDER BY
		Id ASC;
GO

-- Update a record
UPDATE	demo.Customers
SET		Name = 'Microsoft',
		dbRole = 'I-P'
WHERE	Id = 5;
GO

SELECT	Id,
		Name,
		[dbRole],
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Id = 5;
GO

REVERT;
GO

-- Now the admin changes a value!
UPDATE	demo.Customers
SET		Name = 'Xenon AG',
		dbRole = 'Q-Z'
WHERE	Id = 5;
GO

-- Now check what the demo_user can see in the history table
EXECUTE AS USER = 'demo_user';
GO

SELECT	Id,
		Name,
		[dbRole],
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Id = 5;

REVERT;
GO

-- we need to apply the security function to the history table, too!
CREATE SECURITY POLICY historyCustomerFilter
ADD FILTER PREDICATE demo.fn_RowSelection([dbRole])   
ON history.Customers
WITH (STATE = ON);
GO

EXECUTE AS USER = 'demo_user';
GO

SELECT	Id,
		Name,
		[dbRole],
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Id = 5;

REVERT;
GO


-- Clean the kitchen!
DROP SECURITY POLICY CustomerFilter
DROP SECURITY POLICY historyCustomerFilter
GO

DROP USER demo_user;
GO

DROP ROLE [A-H];
DROP ROLE [I-P];
DROP ROLE [Q-Z];
GO

DROP FUNCTION demo.fn_RowSelection;
GO

EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
