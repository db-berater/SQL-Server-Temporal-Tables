USE master;
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