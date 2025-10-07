/*============================================================================
	File:		0160 - temporal tables and existing history data.sql

	Summary:	This script is part of the "temporal tables" session and
				demonstrates the behavior calculated columns in a
				System Versioned Temporal Table

	Date:		Dezember 2016

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

EXEC dbo.sp_prepare_workbench
	@create_tables = 1,
	@fill_data = 1;
	GO

-- stop system versioning and fill random data into the history table
ALTER TABLE demo.Customers SET (SYSTEM_VERSIONING = OFF);
ALTER TABLE demo.Customers DROP PERIOD FOR SYSTEM_TIME;
GO

-- Add ~ 1000 changes into the history table with random validation times
DECLARE	@I  INT = 1;
DECLARE	@Id INT = RAND() * 87500 + 1;
WHILE @I <= 10000
BEGIN
	INSERT INTO history.Customers
	(Id, Name, Street, ZIP, City, Phone, EMail, ValidFrom, ValidTo)
	SELECT	Id, Name, Street, ZIP, City, Phone, EMail,
			DATEADD(DAY, RAND() * -365, GETUTCDATE()),
			DATEADD(HOUR, RAND() * -24, GETUTCDATE())
	FROM	demo.Customers
	WHERE	Id = @Id;

	SET @Id = RAND() * 87500 + 1;
	SET @I += 1;
END
GO

-- show the number of history entries by Customers Id!
SELECT	Id,
		COUNT_BIG(*)
FROM	history.Customers
GROUP BY
		Id
HAVING	COUNT_BIG(*) > 1
ORDER BY
		COUNT_BIG(*) DESC,
		Id;
GO

SELECT * FROM history.Customers AS C
WHERE Id = 3049
ORDER BY
	ValidFrom,
	ValidTo;
GO

-- what we need is THIS!
SELECT	Id,
		ValidFrom,
		ValidTo,
		LEAD(ValidFrom, 1, ValidTo) OVER (PARTITION BY Id ORDER BY ValidFrom) AS NextDate 
FROM	history.Customers
WHERE	Id = 3049
ORDER BY
		ValidFrom,
		ValidTo;
GO

-- Try to make demo.Customers a System Versioned Table again!
ALTER TABLE demo.Customers ADD PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO
ALTER TABLE demo.Customers SET
(
	SYSTEM_VERSIONING = ON
	(HISTORY_TABLE = history.Customers)
);
GO

-- remove the constraint for the periods again!
ALTER TABLE demo.Customers DROP PERIOD FOR SYSTEM_TIME;
GO

-- System versioning will not work if you have
-- - dates in the future
-- - overlapping dates
-- Step 1: Make the history table system versioned conform
	-- remove all contradictional data from the history
	DELETE	history.Customers
	WHERE	ValidTo <= ValidFrom;
	GO

	WITH R
	AS
	(
		SELECT	Id,
				ValidFrom,
				LEAD(ValidFrom, 1, ValidTo) OVER (PARTITION BY Id ORDER BY ValidFrom) AS NextDate 
		FROM	history.Customers
	)
	UPDATE	C
	SET		ValidTo = R.NextDate
	FROM	history.Customers AS C INNER JOIN R
			ON
			(
				C.Id = R.Id
				AND	C.ValidFrom = R.ValidFrom
			);
	GO

	SELECT * FROM history.Customers
	WHERE	Id = 3049;
	GO

	SELECT	Id, MAX(ValidTo) AS ValidTo
	FROM	history.Customers
	GROUP BY
			Id
	ORDER BY
			Id;
	GO

	-- the next step requires an update of [ValidFrom] in the demo.Customers
	WITH R
	AS
	(
		SELECT	Id, MAX(ValidTo) AS ValidTo
		FROM	history.Customers
		GROUP BY
				Id
	)
	UPDATE	C
	SET		C.ValidFrom = R.ValidTo
	FROM	demo.Customers AS C INNER JOIN R
			ON (C.Id = R.Id)
	GO

-- Now we try to acivate temporal tables again!
ALTER TABLE demo.Customers ADD PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO

ALTER TABLE demo.Customers SET
(
	SYSTEM_VERSIONING = ON
	(HISTORY_TABLE = history.Customers)
);
GO

-- Test
SELECT * FROM demo.Customers FOR SYSTEM_TIME ALL AS C
WHERE	C.Id = 3049;
GO

-- Update the company name
UPDATE	demo.Customers
SET		Name = 'db Berater GmbH'
WHERE	Id = 3049;
GO

SELECT * FROM demo.Customers FOR SYSTEM_TIME ALL AS C
WHERE	C.Id = 3049;
GO

-- Clean the kitchen
EXEC dbo.sp_prepare_workbench
	@remove_all = 1;
	GO
