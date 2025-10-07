/*
	============================================================================
	File:		04 - background update.sql

	Summary:	This script creates the environment for a permanent update
				of a table dbo.production_line. A stored procedure needs to
				be run with SQL Query Stress!

				The workload is located in the folder [70 - SQL Query Stress]

	Date:		October 2025
	Revion:		November 2025

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE master;
GO

RAISERROR ('Creating database [demo_db].', 0, 1) WITH NOWAIT;
EXEC master..sp_create_demo_db
	@num_of_files = 1,
    @initial_size_MB = 1024,
    @use_filegroups = 0;
GO

/* We create a table [dbo].[telegrams] for the regulary update of a status */
USE demo_db;
GO

RAISERROR ('Creating table dbo.productline with 1.000.000 rows.', 0, 1) WITH NOWAIT;
SELECT	TOP (1000000)
        o_orderkey					AS	production_id,
		o_orderdate					AS	production_date,
		o_custkey % 350				AS	production_station_id,
		o_custkey					AS	production_employee_id,
		CAST(0x00 AS VARBINARY(16))	AS	production_status_id
INTO	dbo.production_line
FROM	ERP_Demo.dbo.orders
ORDER BY
		o_orderkey;
GO

RAISERROR ('Creating clustered index on table dbo.productline.', 0, 1) WITH NOWAIT;
ALTER TABLE dbo.production_line
ADD CONSTRAINT pk_production_line
PRIMARY KEY CLUSTERED (production_id)
WITH
(
	DATA_COMPRESSION = PAGE,
	SORT_IN_TEMPDB = ON
);
GO

RAISERROR ('Creating nonclustered index on table dbo.productline.', 0, 1) WITH NOWAIT;
CREATE NONCLUSTERED INDEX nix_product_line_production_status_id
ON dbo.production_line (production_status_id)
WITH
(
	DATA_COMPRESSION = PAGE,
	SORT_IN_TEMPDB = ON
);
GO

RAISERROR ('adding temporal attributes to table dbo.productline.', 0, 1) WITH NOWAIT;
ALTER TABLE dbo.production_line
ADD
	valid_from	DATETIME2(0) GENERATED ALWAYS AS ROW START NOT NULL
	CONSTRAINT df_production_line_valid_from DEFAULT (CONVERT(DATETIME2(0), '2025-10-05 00:00:00')),
	valid_to	DATETIME2(0) GENERATED ALWAYS AS ROW END NOT NULL
	CONSTRAINT df_production_line_valid_to DEFAULT (CONVERT(DATETIME2(0), '9999-12-31 23:59:59')),
	PERIOD FOR SYSTEM_TIME (valid_from, valid_to);
GO

CREATE SCHEMA [history] AUTHORIZATION dbo;
GO

ALTER TABLE dbo.production_line
SET
	(
		SYSTEM_VERSIONING = ON
		(HISTORY_TABLE = history.production_line)
	);
GO

RAISERROR ('Creating stored procedure dbo.process_production_line (wrapper).', 0, 1) WITH NOWAIT;
GO
CREATE OR ALTER PROCEDURE dbo.process_production_line
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE	@production_id		BIGINT;
	DECLARE	@production_status_id	VARBINARY (16)

	BEGIN
		/* Grab one free production item with status 0 */
		;WITH l
		AS
		(
			SELECT TOP (1)
					production_id,
					production_status_id
			FROM	dbo.production_line WITH (UPDLOCK, READPAST)
			WHERE	production_status_id = 0x00
		)
		SELECT	@production_id = production_id,
				@production_status_id = l.production_status_id
		FROM	l;

		SELECT	@production_id, @production_status_id;

		WHILE	@production_status_id <= CAST(700 AS VARBINARY(16))
		BEGIN
			UPDATE	dbo.production_line
			SET		production_status_id = production_status_id + 1,
					production_station_id = production_station_id + ((production_status_id + 1) % 2)
			WHERE	production_id = @production_id;

			SET	@production_status_id += 1

			WAITFOR DELAY '00:00:02'
		END
	END
END
GO

RAISERROR ('Run the template [01 - Production Item Processing.json] in SQLStress.', 0, 1) WITH NOWAIT;
GO