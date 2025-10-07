/*============================================================================
	File:		0050 - querying temporal tables.sql

	Summary:	This script shows different ways 

				THIS SCRIPT IS PART OF THE TRACK: 
					"SQL Server Temporal Tables - deep insides"

	Info:		Handling the indexes of temporal table is a complex topic.
				Izik Ben-Gan has written a remarkable blog post about it here:
				http://sqlmag.com/sql-server/first-look-system-versioned-temporal-tables-part-2-querying-data-and-optimization-conside

	Date:		October 2024
	Revion:		October 2025

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
SET XACT_ABORT ON;
GO

USE demo_db;
GO

/*
	IMPORTANT: All examples require the previous start of the script
	[01 - Preparation and Presentation]\[04 - background update.sql]
*/

/*
	Show ALL data changes for a specific employee
	e_validfrom and e_validto are stored for UTC time zone!
*/
SET STATISTICS IO, TIME ON;
GO

;WITH l
AS
(
	SELECT	TOP (1)
			production_id
	FROM	dbo.production_line WITH (READPAST)
	WHERE	production_status_id > 0x00
	ORDER BY
			NEWID()
)
SELECT	pl.production_id,
        pl.production_date,
        pl.production_station_id,
        pl.production_employee_id,
        pl.production_status_id,
        pl.valid_from	AT TIME ZONE 'Central European Standard Time'	AS	valid_from,
        pl.valid_to		AT TIME ZONE 'Central European Standard Time'	AS	valid_to
FROM	dbo.production_line FOR SYSTEM_TIME ALL AS pl
WHERE	EXISTS
		(
			SELECT	*
			FROM	l
			WHERE	l.production_id = pl.production_id
		)
ORDER BY
		pl.valid_from DESC
OPTION	(RECOMPILE, QUERYTRACEON 9130);
GO

/*
	Show the record as it was valid 15 mins ago!
	use RECOMPILE to use the histogram!
*/
DECLARE	@ValidDate	DATETIME2(0) = DATEADD(MINUTE, -15, GETUTCDATE());

;WITH l
AS
(
	SELECT	TOP (1)
			production_id
	FROM	dbo.production_line WITH (READPAST)
	WHERE	production_status_id > 0x00
	ORDER BY
			NEWID()
)
SELECT	pl.production_id,
        pl.production_date,
        pl.production_station_id,
        pl.production_employee_id,
        pl.production_status_id,
        pl.valid_from	AT TIME ZONE 'Central European Standard Time'	AS	valid_from,
        pl.valid_to		AT TIME ZONE 'Central European Standard Time'	AS	valid_to
FROM	dbo.production_line FOR SYSTEM_TIME AS OF @ValidDate AS pl
WHERE	EXISTS
		(
			SELECT	*
			FROM	l
			WHERE	l.production_id = pl.production_id
		)
ORDER BY
		pl.valid_from DESC
OPTION	(RECOMPILE, QUERYTRACEON 9130);
GO

/*
	We can optimize the query by adding an index which covers
	production_id and the time range
*/
CREATE NONCLUSTERED INDEX nix_production_line_production_id
ON history.production_line
(
	production_id,
	valid_to,
	valid_from
)
WITH
(
	DATA_COMPRESSION = PAGE,
	SORT_IN_TEMPDB = ON,
	ONLINE = ON
);
GO

/*
	Show the record as it was valid 15 mins ago!
	use RECOMPILE to use the histogram!
*/
DECLARE	@ValidDate	DATETIME2(0) = DATEADD(MINUTE, -15, GETUTCDATE());

;WITH l
AS
(
	SELECT	TOP (1)
			production_id
	FROM	dbo.production_line WITH (READPAST)
	WHERE	production_status_id > 0x00
	ORDER BY
			NEWID()
)
SELECT	pl.production_id,
        pl.production_date,
        pl.production_station_id,
        pl.production_employee_id,
        pl.production_status_id,
        pl.valid_from	AT TIME ZONE 'Central European Standard Time'	AS	valid_from,
        pl.valid_to		AT TIME ZONE 'Central European Standard Time'	AS	valid_to
FROM	dbo.production_line FOR SYSTEM_TIME AS OF @ValidDate AS pl
WHERE	EXISTS
		(
			SELECT	*
			FROM	l
			WHERE	l.production_id = pl.production_id
		)
ORDER BY
		pl.valid_from DESC
OPTION	(RECOMPILE, QUERYTRACEON 9130);
GO


/* Show record changes in a time range */
DECLARE @startdate	DATETIME2(0) = DATEADD(MINUTE, -10, GETUTCDATE());
DECLARE @enddate	DATETIME2(0) = DATEADD(MINUTE, -5, GETUTCDATE());

;WITH l
AS
(
	SELECT	TOP (1)
			production_id
	FROM	dbo.production_line WITH (READPAST)
	WHERE	production_status_id > 0x00
	ORDER BY
			NEWID()
)
SELECT	pl.production_id,
        pl.production_date,
        pl.production_station_id,
        pl.production_employee_id,
        pl.production_status_id,
        pl.valid_from	AT TIME ZONE 'Central European Standard Time'	AS	valid_from,
        pl.valid_to		AT TIME ZONE 'Central European Standard Time'	AS	valid_to
FROM	dbo.production_line FOR SYSTEM_TIME FROM @startdate TO @enddate AS pl
WHERE	EXISTS
		(
			SELECT	*
			FROM	l
			WHERE	l.production_id = pl.production_id
		)
ORDER BY
		pl.valid_from DESC
OPTION	(RECOMPILE, QUERYTRACEON 9130);
GO

/* Show contained record changes in a time range */
DECLARE @startdate	DATETIME2(0) = DATEADD(MINUTE, -15, GETUTCDATE());
DECLARE @enddate	DATETIME2(0) = DATEADD(MINUTE, -5, GETUTCDATE());

;WITH l
AS
(
	SELECT	TOP (1)
			production_id
	FROM	dbo.production_line WITH (READPAST)
	WHERE	production_status_id > 0x00
	ORDER BY
			NEWID()
)
SELECT	pl.production_id,
        pl.production_date,
        pl.production_station_id,
        pl.production_employee_id,
        pl.production_status_id,
        pl.valid_from	AT TIME ZONE 'Central European Standard Time'	AS	valid_from,
        pl.valid_to		AT TIME ZONE 'Central European Standard Time'	AS	valid_to
FROM	dbo.production_line FOR SYSTEM_TIME CONTAINED IN (@startdate, @enddate) AS pl
WHERE	EXISTS
		(
			SELECT	*
			FROM	l
			WHERE	l.production_id = pl.production_id
		)
ORDER BY
		pl.valid_from DESC
OPTION	(RECOMPILE, QUERYTRACEON 9130);
GO