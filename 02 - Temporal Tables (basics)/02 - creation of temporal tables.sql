/*============================================================================
	File:		0040 - creation of temporal tables.sql

	Summary:	This script demonstrates the different ways to create/implement
				the system versioned temporal table concept

				- use the default naming convention of Microsoft SQL Server
				- use a dedicated schema and named (new) table
				- use a dedicated schema and an existing history table

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
SET LANGUAGE us_english;
GO

USE ERP_Demo;
GO

-- Example 1: Temporal Tables mit DEFAULT table by SQL Server!
-- The table dbo.customers will be implemented as a system versioned table

-- MAKE SURE A PRIMARY KEY EXISTS!
IF NOT EXISTS
(
	SELECT	KC.*
	FROM	sys.key_constraints AS KC
	WHERE	KC.parent_object_id = OBJECT_ID(N'dbo.customers', N'U')
			AND type = N'PK'
)
	EXEC dbo.sp_create_indexes_customers;
GO

-- Now the period columns have to be added
IF NOT EXISTS
(
	SELECT * FROM sys.columns
	WHERE	OBJECT_ID = OBJECT_ID(N'dbo.customers', N'U')
			AND name IN (N'c_starttime', N'c_endtime')
)
ALTER TABLE dbo.Customers
ADD
	[c_starttime] DATETIME2(0) GENERATED ALWAYS AS ROW START CONSTRAINT df_customers_c_starttime DEFAULT ('2024-01-01 00:00:00') NOT NULL,
	[c_endtime] DATETIME2(0) GENERATED ALWAYS AS ROW END CONSTRAINT df_customers_c_endtime DEFAULT ('9999-12-31 23:59:59') NOT NULL,
	PERIOD FOR SYSTEM_TIME(c_starttime, c_endtime);
GO

ALTER TABLE dbo.Customers
SET (SYSTEM_VERSIONING = ON);
GO

/*
	Microsoft SQL Server will automaticially use PAGE COMPRESSION
	for history tables if they do not exist and versioning gets
	activated!
*/
SELECT	OBJECT_NAME(p.object_id)	AS	object_name,
        p.index_id,
        p.rows,
        p.data_compression,
        p.data_compression_desc
FROM	sys.indexes AS i
		INNER JOIN sys.partitions AS p
		ON (i.object_id = p.object_id)
WHERE	i.object_id IN
		(
			SELECT	object_id
			FROM	sys.tables
			WHERE	object_id = OBJECT_ID(N'dbo.customers', N'U')

			UNION ALL

			SELECT	history_table_id
			FROM	sys.tables
			WHERE	object_id = OBJECT_ID(N'dbo.customers', N'U')
		);
GO

/* Relationship between table and history data in sys.tables */
;WITH root
AS
(
	SELECT	t.object_id,
			SCHEMA_NAME(t.schema_id)	AS	[SCHEMA],
			t.name,
			t.temporal_type,
			t.temporal_type_desc,
			t.history_table_id
	FROM	sys.tables AS t
	WHERE	OBJECT_ID = OBJECT_ID(N'dbo.Customers', N'U')

	UNION ALL

	SELECT	t.object_id,
			SCHEMA_NAME(T.schema_id)	AS	[SCHEMA],
			t.name,
			t.temporal_type,
			t.temporal_type_desc,
			t.history_table_id
	FROM	sys.tables AS t INNER JOIN root AS r
			ON (t.object_id = r.history_table_id)
)
SELECT	root.object_id,
		root.[SCHEMA],
		root.name,
		root.temporal_type,
		root.temporal_type_desc,
		root.history_table_id
FROM	root;
GO

/* clean the kitchen */
ALTER TABLE dbo.Customers SET (SYSTEM_VERSIONING = OFF);
GO
DROP TABLE dbo.MSSQL_TemporalHistoryFor_245575913;
GO

/*
	Example 2:	Using a named history table which does not exist
*/
IF SCHEMA_ID(N'history') IS NULL
	EXEC sp_executesql N'CREATE SCHEMA [history] AUTHORZIATION dbo;';
	GO

/* Create a dedicated schema for the history table(s) */
DROP TABLE IF EXISTS history.customers;
GO

ALTER TABLE dbo.customers SET
(
	SYSTEM_VERSIONING = ON
	(HISTORY_TABLE = history.customers)
);
GO

-- what indexes have been created in the history table?
SELECT	OBJECT_NAME(p.object_id)	AS	object_name,
        p.index_id,
        p.rows,
        p.data_compression,
        p.data_compression_desc
FROM	sys.indexes AS i
		INNER JOIN sys.partitions AS p
		ON (i.object_id = p.object_id)
WHERE	i.object_id IN
		(
			SELECT	object_id
			FROM	sys.tables
			WHERE	object_id = OBJECT_ID(N'dbo.customers', N'U')

			UNION ALL

			SELECT	history_table_id
			FROM	sys.tables
			WHERE	object_id = OBJECT_ID(N'dbo.customers', N'U')
		);
GO

/* Relationship between table and history data in sys.tables */
;WITH root
AS
(
	SELECT	t.object_id,
			SCHEMA_NAME(t.schema_id)	AS	[SCHEMA],
			t.name,
			t.temporal_type,
			t.temporal_type_desc,
			t.history_table_id
	FROM	sys.tables AS t
	WHERE	OBJECT_ID = OBJECT_ID(N'dbo.Customers', N'U')

	UNION ALL

	SELECT	t.object_id,
			SCHEMA_NAME(T.schema_id)	AS	[SCHEMA],
			t.name,
			t.temporal_type,
			t.temporal_type_desc,
			t.history_table_id
	FROM	sys.tables AS t INNER JOIN root AS r
			ON (t.object_id = r.history_table_id)
)
SELECT	root.object_id,
		root.[SCHEMA],
		root.name,
		root.temporal_type,
		root.temporal_type_desc,
		root.history_table_id
FROM	root;
GO


/* Example 3:	Usage of given history table name */
ALTER TABLE dbo.customers SET (SYSTEM_VERSIONING = OFF);
GO
DROP TABLE history.customers;
GO

CREATE TABLE history.Customers
(
	c_custkey		BIGINT			NOT NULL,
	c_mktsegment	CHAR(10)		NULL,
	c_nationkey		INT				NULL,
	c_name			VARCHAR(25)		NULL,
	c_address		VARCHAR(40)		NULL,
	c_phone			CHAR(15)		NULL,
	c_acctbal		MONEY			NULL,
	c_comment		VARCHAR(118)	NULL,
	c_starttime		DATETIME2(0)	NOT NULL,
	c_endtime		DATETIME2(0)	NOT NULL
);
GO

ALTER TABLE dbo.Customers SET
(
	SYSTEM_VERSIONING = ON
	(HISTORY_TABLE = history.Customers)
);
GO

-- UPS - NO INDEXES for the history table!!!
SELECT	OBJECT_NAME(P.object_id)	AS	object_name,
        P.index_id,
        P.rows,
        P.data_compression,
        P.data_compression_desc
FROM	sys.indexes AS I
		INNER JOIN sys.partitions AS P
		ON (I.object_id = P.object_id)
WHERE	I.object_id IN
		(
			SELECT	object_id
			FROM	sys.tables
			WHERE	object_id = OBJECT_ID(N'dbo.Customers', N'U')

			UNION ALL

			SELECT	history_table_id
			FROM	sys.tables
			WHERE	object_id = OBJECT_ID(N'dbo.Customers', N'U')
		);
GO

/* Example 4:	Usage of HIDDEN period columns */
SELECT * FROM dbo.Customers;
GO

ALTER TABLE dbo.customers ALTER COLUMN c_starttime ADD HIDDEN;
ALTER TABLE dbo.customers ALTER COLUMN c_endtime ADD HIDDEN;
GO

SELECT * FROM dbo.Customers;
GO

/* you can address these attributes by naming it in the SELECT */
SELECT *,
       c_starttime,
       c_endtime
FROM dbo.Customers;
GO

/* clean the kitchen */
ALTER TABLE dbo.Customers SET (SYSTEM_VERSIONING = OFF);
GO
DROP TABLE history.Customers;
GO

ALTER TABLE dbo.customers DROP CONSTRAINT df_Customers_c_starttime;
ALTER TABLE dbo.customers DROP CONSTRAINT df_Customers_c_endtime;
GO

ALTER TABLE dbo.customers DROP PERIOD FOR SYSTEM_TIME;
GO

ALTER TABLE dbo.customers DROP COLUMN c_starttime;
ALTER TABLE dbo.customers DROP COLUMN c_endtime;
GO

/* Drop the PK-Constraint */
EXEC dbo.sp_drop_indexes
	@table_name = N'dbo.customers',
    @check_only = 0;
GO