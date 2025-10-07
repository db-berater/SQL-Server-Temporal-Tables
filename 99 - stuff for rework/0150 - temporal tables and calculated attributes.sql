/*============================================================================
	File:		0150 - temporal tables and calculated attributes.sql

	Summary:	This script is part of the "temporal tables" session and
				demonstrates the behavior calculated columns in a
				System Versioned Temporal Table

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
SET NOCOUNT ON;
USE CustomerOrders;
GO

EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
	@fill_data = 1;
GO

-- add a calculated column to the system versioned table!
ALTER TABLE demo.Customers
ADD FullAddress
AS
(
	ISNULL(Street + ', ', '') +
	ISNULL(ZIP + ' ', '') +
	ISNULL(City, '')
);
GO

-- 2nd approach to add a calculated column
BEGIN TRANSACTION
GO
	ALTER TABLE demo.Customers SET (SYSTEM_VERSIONING = OFF);
	GO

	-- add a calculated column to the system versioned table!
	ALTER TABLE demo.Customers
	ADD FullAddress
	AS
	(
		ISNULL(Street + ', ', '') +
		ISNULL(ZIP + ' ', '') +
		ISNULL(City, '')
	);
	GO

	-- try the same for the history table
	ALTER TABLE history.Customers
	ADD FullAddress
	AS
	(
		ISNULL(Street + ', ', '') +
		ISNULL(ZIP + ' ', '') +
		ISNULL(City, '')
	);
	GO

	-- reactivate system versioned temporal table
	ALTER TABLE demo.Customers SET
	(
		SYSTEM_VERSIONING = ON
		(HISTORY_TABLE = history.Customers)
	);
	GO

ROLLBACK TRANSACTION;
GO

-- 3rd approach with a fixed length column in the history table
BEGIN TRANSACTION
GO
	ALTER TABLE demo.Customers SET (SYSTEM_VERSIONING = OFF);
	GO

	-- add a calculated column to the system versioned table!
	ALTER TABLE demo.Customers
	ADD FullAddress
	AS
	(
		ISNULL(Street + ', ', '') +	-- VARCHAR(100) + 2 Bytes
		ISNULL(ZIP + ' ', '') +		-- CHAR(5) + 1 Byte(s)
		ISNULL(City, '')			-- VARCHAR(100)
	);
	GO

	-- try the same for the history table
	ALTER TABLE history.Customers
	ADD [FullAddress] VARCHAR(208) NOT NULL;
	GO

	-- reactivate system versioned temporal table
	ALTER TABLE demo.Customers SET
	(
		SYSTEM_VERSIONING = ON
		(HISTORY_TABLE = history.Customers)
	);
	GO

COMMIT TRANSACTION;
GO

-- Check the implementation!
UPDATE	demo.Customers
SET		Name = 'Uwe Ricken',
		Street = 'Büchenweg 4',
		ZIP = '64390',
		City = 'Erzhausen'
WHERE	Id = 10;
GO

SELECT	Id,
		Name,
		FullAddress,
		ValidFrom	AT TIME ZONE 'Central European Standard Time' AS ValidFrom,
		ValidTo		AT TIME ZONE 'Central European Standard Time' AS ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Id = 10
ORDER BY
		ValidFrom DESC;
GO

-- clean the kitchen
EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
	GO