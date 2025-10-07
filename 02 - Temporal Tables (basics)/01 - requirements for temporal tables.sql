/*============================================================================
	File:		01 - requirements for temporal tables.sql

	Summary:	This script demonstrates the requirements for tables in
				Microsoft SQL Server to become a system versioned temporal table 

				THIS SCRIPT IS PART OF THE TRACK: "SQL Server Temporal Tables - deep insides"

	Date:		October 2020
	Revion:		November 2024

	SQL Server Version: >= 2016
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

USE ERP_Demo;
GO

/*
	As for best practice it is recommended to have the temporal table on
	a separate filegroup!
*/
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = N'history')
	ALTER DATABASE ERP_Demo ADD FILEGROUP [history];
	GO

IF NOT EXISTS
(
	SELECT	*
	FROM	sys.master_files
	WHERE	name = N'TemporalHistory'
			AND database_id = DB_ID()
)
	ALTER DATABASE ERP_Demo
	ADD FILE
	(
		NAME = N'TemporalHistory',
		SIZE = 64MB,
		FILEGROWTH = 64MB,
		FILENAME = N'F:\MSSQL16.SQL_2022\MSSQL\DATA\TemporalHistory.ndf'
	) TO FILEGROUP [history];
GO

-- As there is no schema history in the database it will be created first!
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'history')
	EXEC sp_executesql N'CREATE SCHEMA [history] AUTHORIZATION dbo;';
GO

/* We want to make sure that no "old" objects exist! */
IF OBJECT_ID(N'history.suppliers', N'U') IS NOT NULL
BEGIN
	ALTER TABLE dbo.suppliers SET (SYSTEM_VERSIONING = OFF);
	DROP TABLE IF EXISTS history.suppliers;
END
GO

CREATE TABLE history.suppliers
(
	s_suppkey		INT				NOT NULL,
	s_nationkey		INT				NULL,
	s_comment		VARCHAR(102)	NULL,
	s_name			CHAR(25)		NULL,
	s_address		VARCHAR(40)		NULL,
	s_phone			CHAR(15)		NULL,
	s_acctbal		MONEY			NULL
) ON [history];
GO

/* first try to implement Temporal Tables */
ALTER TABLE dbo.suppliers
SET	(SYSTEM_VERSIONING = ON (HISTORY_TABLE = History.suppliers));
GO

-- ok - define the system period time for dbo.Addresses
ALTER TABLE dbo.suppliers
ADD
	s_starttime	DATETIME2(0) GENERATED ALWAYS AS ROW START NOT NULL
	CONSTRAINT df_suppliers_s_starttime DEFAULT (CAST('2024-01-01 00:00' AS DATETIME2(0))),
	
	s_endtime DATETIME2(0) GENERATED ALWAYS AS ROW END NOT NULL
	CONSTRAINT df_suppliers_s_endtime DEFAULT (CAST('9999-12-31 23:59:59' AS DATETIME2(0))),
	PERIOD FOR SYSTEM_TIME (s_starttime, s_endtime);
GO

/* second try to implement Temporary Tables */
ALTER TABLE dbo.suppliers
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = history.suppliers));
GO

/* ok - let's create a PRIMARY KEY */
ALTER TABLE dbo.suppliers ADD CONSTRAINT pk_suppliers
PRIMARY KEY CLUSTERED (s_suppkey)
WITH (DATA_COMPRESSION = PAGE);
GO

/* third try to implement Temporary Tables */
ALTER TABLE dbo.suppliers
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = history.suppliers));
GO

-- Different meta data are not allowed!
SELECT	column_id,
		name,
		max_length,
		is_hidden,
		is_masked
FROM	sys.columns
WHERE	object_id = OBJECT_ID(N'dbo.suppliers')
EXCEPT
SELECT	column_id,
		name,
		max_length,
		is_hidden,
		is_masked
FROM	sys.columns
WHERE	object_id = OBJECT_ID(N'history.suppliers');
GO

/* Add the missing attributes to the planned history table */
ALTER TABLE history.suppliers
ADD
	s_starttime	DATETIME2(0) NOT NULL,
	s_endtime	DATETIME2(0) NOT NULL;
GO

-- Do we have any more meta data differences?
SELECT	column_id,
		name,
		max_length,
		is_hidden,
		is_masked
FROM	sys.columns
WHERE	object_id = OBJECT_ID(N'dbo.suppliers')
EXCEPT
SELECT	column_id,
		name,
		max_length,
		is_hidden,
		is_masked
FROM	sys.columns
WHERE	object_id = OBJECT_ID(N'history.suppliers');
GO

/* 4 Try to implement Temporary Tables - SUCCESS! */
ALTER TABLE dbo.suppliers
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = history.suppliers));
GO

/* Let's play a little bit with the data... */
SELECT	s_suppkey,
        s_nationkey,
        s_comment,
        s_name,
        s_address,
        s_phone,
        s_acctbal,
		s_starttime		AS	[utc_datetime],
		DATEADD(MINUTE, DATEDIFF(MINUTE, GETUTCDATE(), GETDATE()), s_starttime)	AS	[local_datetime],
		s_endtime
FROM	dbo.suppliers
WHERE	s_suppkey = 2;
GO

/* Let's update the suppliers address */
UPDATE	dbo.suppliers
SET		s_address= 'anywhere in the big country'
WHERE	s_suppkey = 2;
GO

SELECT	s_suppkey,
        s_nationkey,
        s_comment,
        s_name,
        s_address,
        s_phone,
        s_acctbal,
		s_starttime		AS	[utc_starttime],
		DATEADD(MINUTE, DATEDIFF(MINUTE, GETUTCDATE(), GETDATE()), s_starttime)	AS	[local_datetime],
		s_endtime		AS	[utc_endtime]
FROM	dbo.suppliers
WHERE	s_suppkey = 2;
GO

/* What's inside the history table? */
UPDATE	dbo.suppliers
SET		s_address = 'Bahnstrasse 33, 64390 Erzhausen'
WHERE	s_suppkey = 1;
GO

/* Simple look into the history table by SELECT statement */
SELECT	s_suppkey,
        s_nationkey,
        s_comment,
        s_name,
        s_address,
        s_phone,
        s_acctbal,
        s_starttime		AS	[utc_starttime],
        s_endtime		AS	[utc_endtime]
FROM	history.suppliers
WHERE	s_suppkey= 1;
GO

;WITH history
AS
(
	SELECT	N'dbo.suppliers'		AS	table_name,
			s_suppkey,
            s_nationkey,
            s_comment,
            s_name,
            s_address,
            s_phone,
            s_acctbal,
            s_starttime,
            s_endtime
	FROM	dbo.suppliers
	WHERE	s_suppkey = 1

	UNION ALL

	SELECT	N'history.suppliers'	AS	table_name,
			s_suppkey,
            s_nationkey,
            s_comment,
            s_name,
            s_address,
            s_phone,
            s_acctbal,
            s_starttime,
            s_endtime
	FROM	history.suppliers
	WHERE	s_suppkey = 1
)
SELECT	*
FROM	history
ORDER BY
		s_starttime DESC;
GO

/* How is it working when record get deleted */
DELETE	dbo.suppliers
WHERE	s_suppkey = 4;
GO

;WITH history
AS
(
	SELECT	N'dbo.suppliers'		AS	table_name,
			s_suppkey,
            s_nationkey,
            s_comment,
            s_name,
            s_address,
            s_phone,
            s_acctbal,
            s_starttime,
            s_endtime
	FROM	dbo.suppliers
	WHERE	s_suppkey = 4

	UNION ALL

	SELECT	N'history.suppliers'	AS	table_name,
			s_suppkey,
            s_nationkey,
            s_comment,
            s_name,
            s_address,
            s_phone,
            s_acctbal,
            s_starttime		AS	[utc_starttime],
            s_endtime		AS	[utc_endtime]
	FROM	history.suppliers
	WHERE	s_suppkey = 4
)
SELECT	history.table_name,
        history.s_suppkey,
        history.s_nationkey,
        history.s_comment,
        history.s_name,
        history.s_address,
        history.s_phone,
        history.s_acctbal,
        history.s_starttime	AS	[utc_starttime],
        history.s_endtime	AS	[utc_endtime]
FROM	history
ORDER BY
		s_starttime DESC;
GO

/* Can we delete history entries from the database? */
DELETE history.suppliers;
GO

/* Now we clean the kitchen */
ALTER TABLE dbo.suppliers SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS history.suppliers;
GO

ALTER TABLE dbo.suppliers DROP PERIOD FOR SYSTEM_TIME;
ALTER TABLE dbo.suppliers DROP CONSTRAINT pk_suppliers;
ALTER TABLE dbo.suppliers DROP CONSTRAINT df_suppliers_s_starttime;
ALTER TABLE dbo.suppliers DROP CONSTRAINT df_suppliers_s_endtime;
ALTER TABLE dbo.suppliers DROP COLUMN [s_starttime];
ALTER TABLE dbo.suppliers DROP COLUMN [s_endtime];
GO