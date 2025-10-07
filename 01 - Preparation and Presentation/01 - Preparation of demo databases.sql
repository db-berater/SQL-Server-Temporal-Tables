/*
	============================================================================
	File:		0001 - Preparation of demo databases.sql

	Summary:	This script restores the database ERP_Demo from
				the backup medium for distribution of data.
				
				THIS SCRIPT IS PART OF THE TRACK:
					"Workshop - Improve your DBA Skills"

	Version:	1.00.000

	Date:		October 2025
	Revion:		October 2025

	SQL Server Version: >= 2016
	============================================================================
*/
USE master;
GO

/*
	Make sure you've executed the script 0000 - sp_restore_erp_demo.sql
	before you run this code!
*/
EXEC master.dbo.sp_restore_ERP_demo @query_store = 1;
GO

/* reset the sql server default settings for the demos */
EXEC ERP_Demo.dbo.sp_set_sql_server_defaults;
GO

SELECT * FROM ERP_Demo.dbo.get_database_help_info();
SELECT * FROM ERP_Demo.dbo.get_object_help_info(NULL);
GO

/*
	To avoid the implementation of each stored procedure / workshop object
	we deploy it with the restore of the ERP_Demo Database
*/

USE master;
GO

RAISERROR ('Creating stored procedure [dbo].[sp_create_demo_db].', 0, 1) WITH NOWAIT;
GO

CREATE OR ALTER PROCEDURE dbo.sp_create_demo_db
	@num_of_files		SMALLINT	= 1,
	@initial_size_MB	INT			= 1024,
	@use_filegroups		BIT			= 0
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	/*
		If the initial size is smaller than the default we quit the procedure
	*/
	DECLARE	@default_size_mb	INT;
	SELECT	@default_size_mb = size / 128
	FROM	sys.master_files
	WHERE	database_id = DB_ID(N'model')
			AND file_id = 1;

	IF (@initial_size_MB < @default_size_mb)
	BEGIN
		RAISERROR ('The initial_size_mb must be at least %i MB', 0, 1, @default_size_mb) WITH NOWAIT;
		RETURN 1;
	END

	DECLARE	@data_path	NVARCHAR(256)	= CAST(SERVERPROPERTY(N'InstanceDefaultDataPath') AS NVARCHAR(256));
	DECLARE	@log_path	NVARCHAR(256)	= CAST(SERVERPROPERTY(N'InstanceDefaultLogPath') AS NVARCHAR(256));

	IF DB_ID(N'demo_db') IS NOT NULL
	BEGIN
		RAISERROR ('dropping existing database [demo_db]', 0, 1) WITH NOWAIT;
		ALTER DATABASE [demo_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DROP DATABASE [demo_db];
		EXECUTE msdb..sp_delete_database_backuphistory @database_name = 'demo_db';
	END

	DECLARE	@sql_cmd			NVARCHAR(MAX);
	DECLARE	@file_specs			NVARCHAR(4000) = N'';
	DECLARE	@const_file_name	NVARCHAR(128) = N'demo_db_%';
	DECLARE	@var_file_name		NVARCHAR(128);
	DECLARE	@counter			INT = 1;

	/*
		If no dedicated filegroups should be used and the number of files is larger than 1
	*/
	IF @use_filegroups = 0 AND @num_of_files > 1
	BEGIN
		SET	@sql_cmd = N'CREATE DATABASE [demo_db]
	ON PRIMARY
	';

		WHILE @counter <= @num_of_files
		BEGIN
			SET	@var_file_name = REPLACE(@const_file_name, '%', CAST(@counter AS NVARCHAR(3)));
			SET	@file_specs = N'(NAME = ' + QUOTENAME(@var_file_name, '''') + N', SIZE = ' + CAST(@initial_size_MB AS NVARCHAR(16)) + N'MB, FILENAME = ''' + @data_path + @var_file_name + N'.mdf''),'

			SET	@sql_cmd = @sql_cmd + @file_specs + CHAR(10)
			SET	@counter += 1;
		END

		SET	@sql_cmd = LEFT(@sql_cmd, LEN(@sql_cmd) - 2) + CHAR(10);

		/* Add the log file information */
		SET	@sql_cmd = @sql_cmd + N'LOG ON
	(
		NAME = ''demo_db'',
		SIZE = 256MB,
		FILENAME = ''' + @log_path + N'demo_db.ldf''
	);'

		PRINT @sql_cmd;
		BEGIN TRY
			EXEC sp_executesql @sql_cmd;

			EXEC sp_executesql N'ALTER DATABASE [demo_db] SET RECOVERY SIMPLE;';
			EXEC sp_executesql N'ALTER AUTHORIZATION ON DATABASE::[demo_db] TO sa;';
		END TRY
		BEGIN CATCH
			SELECT	ERROR_NUMBER()	AS	ERROR_NUMBER,
					ERROR_MESSAGE()	AS	ERROR_MESSAGE;

			RETURN 1;
		END CATCH
	END
	ELSE
	BEGIN
		/* Let's create the inital database with a file in the PRIMARY filegroup */
		RAISERROR ('Creating database [demo_db]...', 0, 1) WITH NOWAIT;
		SET	@sql_cmd = N'CREATE DATABASE [demo_db] ON PRIMARY';
		SET	@var_file_name = REPLACE(@const_file_name, '%', '0');
		SET	@file_specs = N'(NAME = ' + QUOTENAME(@var_file_name, '''') + N', SIZE = ' + CAST(@initial_size_MB AS NVARCHAR(16)) + N'MB, FILENAME = ''' + @data_path + @var_file_name + N'.mdf'')'
			SET	@sql_cmd = @sql_cmd + @file_specs + CHAR(10)

		/* Add the log file information */
		SET	@sql_cmd = @sql_cmd + N'LOG ON
	(
		NAME = ''demo_db'',
		SIZE = 256MB,
		FILENAME = ''' + @log_path + N'demo_db.ldf''
	);'
		
		PRINT @sql_cmd;
		BEGIN TRY
			EXEC sp_executesql @sql_cmd;

			EXEC sp_executesql N'ALTER DATABASE [demo_db] SET RECOVERY SIMPLE;';
			EXEC sp_executesql N'ALTER AUTHORIZATION ON DATABASE::[demo_db] TO sa;';
		END TRY
		BEGIN CATCH
			SELECT	ERROR_NUMBER()	AS	ERROR_NUMBER,
					ERROR_MESSAGE()	AS	ERROR_MESSAGE;

			RETURN 1;
		END CATCH

		/* ... and add aditional filegroups/files to the database */
		IF @num_of_files > 1
		BEGIN
			RAISERROR ('Adding additional %i filegroup to database [demo_db]', 0, 1, @num_of_files) WITH NOWAIT;

			SET	@counter = 1
			WHILE @counter <= @num_of_files
			BEGIN
				SET	@sql_cmd = N'ALTER DATABASE [demo_db] ADD FILEGROUP [filegroup_xx];'
				SET	@sql_cmd = REPLACE(@sql_cmd, N'xx', RIGHT('00' + CAST(@counter AS NVARCHAR(2)), 2));
				PRINT @sql_cmd;

				EXEC sp_executesql @sql_cmd;
				SET	@counter += 1;
			END

			SET	@counter = 1
			WHILE @counter <= @num_of_files
			BEGIN
				SET @sql_cmd = N'ALTER DATABASE [demo_db] ADD FILE
				(
					NAME		= N' + QUOTENAME(N'demo_db_' + RIGHT('00' + CAST(@counter AS NVARCHAR(2)), 2), '''') + N',
					FILENAME	= N' + QUOTENAME(@data_path + N'demo_db_' + RIGHT('00' + CAST(@counter AS NVARCHAR(2)), 2) + N'.ndf', '''') + N',
					SIZE		= '  + CAST(@initial_size_MB AS NVARCHAR(16)) + N'MB
				)
				TO FILEGROUP ' + QUOTENAME(N'filegroup_' + RIGHT('00' + CAST(@counter AS NVARCHAR(2)), 2)) + N';'

				PRINT @sql_cmd;
				BEGIN TRY
					EXEC sp_executesql @sql_cmd;
				END TRY
				BEGIN CATCH
					SELECT	ERROR_NUMBER()	AS	ERROR_NUMBER,
							ERROR_MESSAGE()	AS	ERROR_MESSAGE;

					RETURN 1;
				END CATCH

				SET	@counter += 1;
			END
		END
	END


	RETURN 0;
END
GO

EXEC master..sp_ms_marksystemobject N'dbo.sp_create_demo_db';
GO


USE master;
GO

RAISERROR ('Creating stored procedure [dbo].[sp_reset_counters].', 0, 1) WITH NOWAIT;
GO

CREATE OR ALTER PROCEDURE dbo.sp_reset_counters
	@clear_wait_stats		SMALLINT = 1,
	@clear_user_counters	SMALLINT = 1
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF @clear_wait_stats = 1
	BEGIN
		RAISERROR ('Deleting global wait stats', 0, 1) WITH NOWAIT;
		DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
	END

	IF @clear_user_counters = 1
	BEGIN
		RAISERROR ('Deleting user counters', 0, 1) WITH NOWAIT;

		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 1', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 2', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 3', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 4', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 5', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 6', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 7', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 8', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 9', 0);
		DBCC SETINSTANCE('SQLServer:User Settable', 'Query', 'User counter 10', 0);
	END
END
GO

EXEC master..sp_ms_marksystemobject N'dbo.sp_reset_counters';
GO


USE master;
GO

RAISERROR ('Creating stored procedure [dbo].[ssp_read_event_locks].', 0, 1) WITH NOWAIT;
GO

CREATE OR ALTER PROCEDURE dbo.sp_read_xevent_locks
	@xevent_name		NVARCHAR(128),
	@filter_condition	NVARCHAR(1024) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	RAISERROR ('Catching the data from the ring_buffer for extended event [%s]', 0, 1, @xevent_name) WITH NOWAIT;
	SELECT	CAST(target_data AS XML) AS target_data
	INTO	#xe_data
	FROM	sys.dm_xe_session_targets AS t
			INNER JOIN sys.dm_xe_sessions AS s
			ON (t.event_session_address = s.address)
	WHERE	s.name = @xevent_name
			AND t.target_name = N'ring_buffer';

	RAISERROR ('Analyzing the data from the ring buffer', 0, 1) WITH NOWAIT;

	SELECT	x.event_data.value ('(action[@name="attach_activity_id"]/value)[1]', 'VARCHAR(40)')			AS	activity_id,
			x.event_data.value ('(@timestamp)[1]', N'DATETIME')											AS	[timestamp],
			x.event_data.value('(@name)[1]', 'VARCHAR(25)')												AS	event_name,
			x.event_data.value ('(data[@name="batch_text"]/value)[1]', 'VARCHAR(MAX)')					AS	batch_text,
			x.event_data.value('(data[@name="resource_type"]/text)[1]', 'VARCHAR(25)')					AS	resource_type,
			x.event_data.value('(data[@name="mode"]/text)[1]', 'VARCHAR(10)')							AS	lock_mode,
			x.event_data.value('(data[@name="resource_0"]/value)[1]', 'NVARCHAR(25)')					AS	resource_0,
			x.event_data.value('(data[@name="resource_1"]/value)[1]', 'NVARCHAR(25)')					AS	resource_1,
			x.event_data.value('(data[@name="resource_2"]/value)[1]', 'NVARCHAR(25)')					AS	resource_2,
			OBJECT_NAME
			(
				CASE WHEN ISNULL(x.event_data.value('(data[@name="object_id"]/value)[1]', 'INT'), 0) = 0
					 THEN i.object_id
					 ELSE x.event_data.value('(data[@name="object_id"]/value)[1]', 'INT')
				END
			)																					AS	object_name,
			x.event_data.value('(data[@name="associated_object_id"]/value)[1]', 'NVARCHAR(25)')	AS	associated_object_id,
			i.index_id,
			i.name																				AS	index_name
	INTO	#temp_result
	FROM	#xe_data AS txe
			CROSS APPLY txe.target_data.nodes('//RingBufferTarget/event') AS x (event_data)
			LEFT JOIN sys.partitions AS p
			ON
			(
				TRY_CAST(x.event_data.value('(data[@name="associated_object_id"]/value)[1]', 'NVARCHAR(25)') AS BIGINT) = p.hobt_id
			)
			LEFT JOIN sys.indexes AS i
			ON
			(
				p.object_id = i.object_id
				AND p.index_id = i.index_id
			)

	IF @filter_condition IS NOT NULL
	BEGIN
		DECLARE	@sql_stmt NVARCHAR(MAX) = N'SELECT	activity_id,
		[timestamp],
		event_name,
		batch_text,
		resource_type,
		lock_mode,
		resource_0,
		resource_1,
		resource_2,
		object_name,
		associated_object_id,
		index_id,
		index_name
FROM	#temp_result
WHERE ' + @filter_condition + N' 
ORDER BY
		timestamp,
		TRY_CAST(SUBSTRING(activity_id, 38, 255) AS INT);';
		EXEC sp_executesql @sql_stmt;
	END
	ELSE
		SELECT	activity_id,
				[timestamp],
				event_name,
				batch_text,
				resource_type,
				lock_mode,
				resource_0,
				resource_1,
				resource_2,
				object_name,
				associated_object_id,
				index_id,
				index_name
		FROM	#temp_result
		ORDER BY
				timestamp ASC,
				TRY_CAST(SUBSTRING(activity_id, 38, 255) AS INT);
END
GO

EXEC master..sp_ms_marksystemobject N'dbo.sp_read_xevent_locks';
GO

CREATE OR ALTER PROCEDURE dbo.sp_read_xevent_page_splits
	@xevent_name		NVARCHAR(128)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DROP TABLE IF EXISTS #event_data;

	RAISERROR ('Catching the data from the ring_buffer for extended event [%s]', 0, 1, @xevent_name) WITH NOWAIT;

	SELECT	CAST(target_data AS XML) AS target_data
	INTO	#event_data
	FROM	sys.dm_xe_session_targets AS t
			INNER JOIN sys.dm_xe_sessions AS s
			ON (t.event_session_address = s.address)
	WHERE	s.name = N'monitor_page_splits'
			AND t.target_name = N'ring_buffer';

	RAISERROR ('Analyzing the data from the ring buffer', 0, 1) WITH NOWAIT;

	WITH XE
	AS
	(
		SELECT	x.event_data.value('(@timestamp)[1]','datetime')								AS	[time],
				x.event_data.value('(@name)[1]', 'VARCHAR(128)')								AS	[Event_name],
				x.event_data.value('(data[@name="file_id"]/value)[1]','int')					AS	[file_id],
				x.event_data.value('(data[@name="page_id"]/value)[1]','int')					AS	[page_id],
				x.event_data.value('(data[@name="new_page_page_id"]/value)[1]','int')			AS	[new_page_id],
				x.event_data.value('(data[@name="database_id"]/value)[1]','int')				AS	[database_id],
				x.event_data.value('(data[@name="splitOperation"]/text)[1]','varchar(128)')	AS	[split_operation]
		FROM	#event_data AS ed
				CROSS APPLY ed.target_data.nodes('//RingBufferTarget/event') AS x (event_data)
	)
	SELECT	DISTINCT
			XE.Event_name,
			XE.split_operation,
			XE.page_id,
			XE.new_page_id,
			XE.new_page_id - XE.page_id	AS	split_jump
	FROM	XE
	WHERE	(XE.new_page_id - XE.page_id) > 1
			AND XE.Event_name = 'page_split';
END
GO

EXEC master..sp_ms_marksystemobject N'dbo.sp_read_xevent_page_splits';
GO