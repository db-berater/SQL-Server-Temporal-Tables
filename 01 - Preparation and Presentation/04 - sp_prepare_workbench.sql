/*============================================================================
	File:		2000 - stored procedure for preparing workbench.sql

	Summary:	This script creates a stored procedure for the default
				preparation of the workbench for the demos.
				It creates two schemas and - based on the para

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
SET XACT_ABORT ON;
GO

USE demo_db;
GO

IF OBJECT_ID(N'dbo.sp_prepare_workbench', N'P') IS NOT NULL
	DROP PROCEDURE dbo.sp_prepare_workbench;
	GO

CREATE OR ALTER PROCEDURE dbo.sp_prepare_workbench
	@create_tables	BIT	=	0,
	@fill_data		BIT	=	0,
	@remove_all		BIT	=	0
AS
BEGIN
	SET NOCOUNT ON;

	IF @create_tables = 1 AND @remove_all = 1
	BEGIN
		RAISERROR (N'contradiction for variables @create_tables and @remove_all', 0, 1) WITH NOWAIT;
		RETURN 1;
	END

	IF @create_tables = 1
	BEGIN
		/* Create a dedicated schema for the history data */
		IF SCHEMA_ID(N'history') IS NULL
			EXEC sp_executesql N'CREATE SCHEMA [history] AUTHORIZATION dbo;';

		/* Clear the workbench for the demos! */
		IF EXISTS
		(
			SELECT	*
			FROM	sys.tables AS T
			WHERE	T.object_id = OBJECT_ID(N'dbo.Customers', N'U')
					AND T.temporal_type = 2
		)
			ALTER TABLE dbo.Customers SET (SYSTEM_VERSIONING = OFF);

		DROP TABLE IF EXISTS dbo.customers;
		DROP TABLE IF EXISTS history.customers

		/* Create the demo table... */
		CREATE TABLE dbo.customers
		(
			c_custkey		BIGINT			NOT NULL,
			c_mktsegment	CHAR(10)		NULL,
			c_nationkey		INT				NOT NULL,
			c_name			VARCHAR(25)		NULL,
			c_address		VARCHAR(40)		NULL,
			c_phone			CHAR(15)		NULL,
			c_email			VARCHAR(255)	NULL,
			c_acctbal		MONEY			NULL,
			c_comment		VARCHAR(118)	NULL,
			c_valid_from	DATETIME2(0)	GENERATED ALWAYS AS ROW START	NOT NULL	DEFAULT ('1900-01-01T00:00:00'),
			c_valid_to		DATETIME2(0)	GENERATED ALWAYS AS ROW END		NOT NULL	DEFAULT ('9999-12-31T23:59:59'),

			CONSTRAINT pk_customers PRIMARY KEY CLUSTERED (c_custkey),
			PERIOD FOR SYSTEM_TIME (c_valid_from, c_valid_to)
		)
		WITH
		(
			DATA_COMPRESSION = PAGE,
			SYSTEM_VERSIONING = ON
			(HISTORY_TABLE = history.customers)
		);

		RAISERROR ('demo tables have been created...', 0, 1) WITH NOWAIT;
	END

	IF @fill_data = 1
	BEGIN
		DECLARE	@num_rows	INT;

		INSERT INTO dbo.customers WITH (TABLOCK)
		(c_custkey, c_mktsegment, c_nationkey, c_name, c_address, c_phone, c_acctbal, c_comment)
		SELECT	TOP (1000)
				c.c_custkey,
                c.c_mktsegment,
                c.c_nationkey,
                c.c_name,
                c.c_address,
                c.c_phone,
                c.c_acctbal,
                c.c_comment
		FROM	ERP_Demo.dbo.Customers AS c
		ORDER BY
				c_custkey;

		SET	@num_rows = @@ROWCOUNT;
		RAISERROR ('demo tables have been filled with %i records...', 0, 1, @num_rows) WITH NOWAIT;
	END

	IF @remove_all = 1
	BEGIN
		-- Clear the workbench for the demos!
		IF EXISTS
		(
			SELECT	*
			FROM	sys.tables AS T
			WHERE	T.object_id = OBJECT_ID(N'dbo.Customers', N'U')
					AND T.temporal_type = 2
		)
			ALTER TABLE dbo.Customers SET (SYSTEM_VERSIONING = OFF);

		DROP TABLE IF EXISTS history.customers;
		DROP TABLE IF EXISTS dbo.customers;

		RAISERROR ('Objects and schemas have been removed...', 0, 1) WITH NOWAIT;
	END
END
GO