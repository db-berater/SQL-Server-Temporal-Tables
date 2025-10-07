/*============================================================================
	File:		0110 - variable primary keys in temporal tables.sql

	Summary:	This script demonstrates the problems with variable
				primary keys in a system versioned temporal table

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
SET LANGUAGE us_english;
GO

USE CustomerOrders;
GO

-- create demo environment with data
EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
    @fill_data = 1,
    @remove_all = 0;
GO

-- remove the "old" IDENTITY as PK
BEGIN TRANSACTION;
	ALTER TABLE demo.Customers ADD [Customer_Id] INT NOT NULL CONSTRAINT df_Customer_Id DEFAULT (0);
	GO

	-- make the [Customer_Id] the primary key
	ALTER TABLE demo.Customers SET (SYSTEM_VERSIONING = OFF);
	GO

	DROP TABLE history.Customers;
	GO


	UPDATE	demo.Customers
	SET		Customer_Id = Id;
	GO

	ALTER TABLE demo.Customers DROP CONSTRAINT pk_Customers_Id;
	GO

	ALTER TABLE demo.Customers DROP COLUMN Id;
	GO

	ALTER TABLE demo.Customers ADD CONSTRAINT pk_Customers_Id PRIMARY KEY ([Customer_Id]);
	GO

	ALTER TABLE demo.Customers SET
	(
		SYSTEM_VERSIONING = ON
		(HISTORY_TABLE = history.Customers)
	);
	GO
COMMIT TRANSACTION;
GO

SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	demo.Customers;
GO

-- some demo changes in the database
UPDATE	demo.Customers
SET		Name = 'db Berater GmbH',
		Street = 'Bahnstrasse 33',
		ZIP = '64390',
		City = 'Erzhausen'
WHERE	Customer_Id = 10;
GO

SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Customer_Id = 10;
GO

-- An update on phone and email occurs
UPDATE	demo.Customers
SET		Phone = '06150-123456',
		EMail = 'info@db-berater.de'
WHERE	Customer_Id = 10;
GO

SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Customer_Id = 10
ORDER BY
		ValidFrom DESC;
GO

-- Now we update the PK of the table demo.Customers
UPDATE	demo.Customers
SET		Customer_Id = Customer_Id + 100000
WHERE	Customer_Id = 10;
GO

DECLARE	@Date DATETIME2(0) = DATEADD(MINUTE, -0, GETUTCDATE());
SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	demo.Customers FOR SYSTEM_TIME AS OF @Date
WHERE	Customer_Id = 100000 + 10;
GO

UPDATE	demo.Customers
SET		Customer_Id = Customer_Id - 100000
WHERE	Customer_Id = 100000 + 10;
GO

DECLARE	@Date DATETIME2(0) = DATEADD(MINUTE, -0, GETUTCDATE());
SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	demo.Customers FOR SYSTEM_TIME AS OF @Date
WHERE	Customer_Id = 10;
GO

SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Customer_Id = 10
ORDER BY
		ValidFrom;
GO

SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	history.Customers
ORDER BY
		ValidFrom DESC;
GO

-- Delete the record with the ID = 10
DELETE	demo.Customers WHERE Customer_Id = 10;
GO

INSERT INTO demo.Customers
(Customer_Id, Name, Street, ZIP, City, Phone, EMail)
VALUES
(10, 'db Berater GmbH', 'Bahnstrasse 33', '64390', 'Erzhausen', '0173-1234567', NULL);
GO

SELECT	Customer_Id,
		Name,
		Street,
		ZIP,
		City,
		Phone,
		EMail,
		ValidFrom,
		ValidTo
FROM	demo.Customers FOR SYSTEM_TIME ALL
WHERE	Customer_Id = 10
ORDER BY
		ValidTo DESC;
GO

EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
GO