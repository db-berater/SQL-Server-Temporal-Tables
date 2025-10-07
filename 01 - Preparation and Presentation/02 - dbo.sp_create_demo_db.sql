USE master;
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