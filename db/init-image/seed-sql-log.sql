SET NOCOUNT ON;

DECLARE @service_user SYSNAME = N'$(SERVICE_SQL_USER)';
DECLARE @log_schema SYSNAME = N'$(SQL_LOG_SCHEMA)';
DECLARE @log_table SYSNAME = N'$(SQL_LOG_TABLE)';
DECLARE @sql NVARCHAR(MAX);

IF @service_user IS NULL OR LTRIM(RTRIM(@service_user)) = N''
BEGIN
    RAISERROR('SERVICE_SQL_USER is required.', 16, 1);
    RETURN;
END;

IF @log_schema IS NULL
    OR LTRIM(RTRIM(@log_schema)) = N''
    OR @log_schema LIKE N'%[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]%' COLLATE Latin1_General_BIN2
BEGIN
    RAISERROR('SQL_LOG_SCHEMA must contain only letters, numbers, and underscores.', 16, 1);
    RETURN;
END;

IF @log_table IS NULL
    OR LTRIM(RTRIM(@log_table)) = N''
    OR @log_table LIKE N'%[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]%' COLLATE Latin1_General_BIN2
BEGIN
    RAISERROR('SQL_LOG_TABLE must contain only letters, numbers, and underscores.', 16, 1);
    RETURN;
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @service_user)
BEGIN
    RAISERROR('Service database user does not exist.', 16, 1);
    RETURN;
END;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @log_schema)
BEGIN
    SET @sql = N'CREATE SCHEMA ' + QUOTENAME(@log_schema) + N';';
    EXEC (@sql);
END;

SET @sql = N'
IF OBJECT_ID(N''' + QUOTENAME(@log_schema) + N'.' + QUOTENAME(@log_table) + N''', N''U'') IS NULL
BEGIN
    CREATE TABLE ' + QUOTENAME(@log_schema) + N'.' + QUOTENAME(@log_table) + N'(
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [ApiName] [nvarchar](max) NULL,
        [SwaServer] [nvarchar](max) NULL,
        [MsUsed] [int] NULL,
        [TimeStamp] [datetime] DEFAULT GETDATE(),
        [ReturnValue] [int] NULL,
        [RequestBody] [nvarchar](max) NULL,
        [ReturnBody] [nvarchar](max) NULL,
        [ExecString] [nvarchar](max) NULL,
        [jwt] [nvarchar](max) NULL,
        [UnexpectedError] [nvarchar](max) NULL,
        CONSTRAINT ' + QUOTENAME(N'PK_' + @log_table) + N' PRIMARY KEY CLUSTERED ([Id] ASC)
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N''' + QUOTENAME(@log_schema) + N'.' + QUOTENAME(@log_table) + N''')
      AND name = N''IX_' + REPLACE(@log_table, '''', '''''') + N'_TimeStamp''
)
BEGIN
    CREATE INDEX ' + QUOTENAME(N'IX_' + @log_table + N'_TimeStamp') + N'
        ON ' + QUOTENAME(@log_schema) + N'.' + QUOTENAME(@log_table) + N' ([TimeStamp]);
END;

GRANT SELECT, INSERT, DELETE ON ' + QUOTENAME(@log_schema) + N'.' + QUOTENAME(@log_table) + N'
    TO ' + QUOTENAME(@service_user) + N';
';

EXEC (@sql);
