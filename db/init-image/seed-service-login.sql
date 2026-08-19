SET NOCOUNT ON;

DECLARE @service_user SYSNAME = N'$(SERVICE_SQL_USER)';
DECLARE @service_password NVARCHAR(256) = N'$(SERVICE_SQL_PASSWORD)';
DECLARE @database_name SYSNAME = N'$(SQL_DATABASE)';
DECLARE @sql NVARCHAR(MAX);

IF @service_user IS NULL OR LTRIM(RTRIM(@service_user)) = N''
BEGIN
    RAISERROR('SERVICE_SQL_USER is required.', 16, 1);
    RETURN;
END;

IF @service_password IS NULL OR LTRIM(RTRIM(@service_password)) = N''
BEGIN
    RAISERROR('SERVICE_SQL_PASSWORD is required.', 16, 1);
    RETURN;
END;

IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = @service_user)
BEGIN
    SET @sql =
        N'CREATE LOGIN ' + QUOTENAME(@service_user) +
        N' WITH PASSWORD = ' + QUOTENAME(REPLACE(@service_password, '''', ''''''), '''') +
        N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';

    EXEC (@sql);
END
ELSE
BEGIN
    SET @sql =
        N'ALTER LOGIN ' + QUOTENAME(@service_user) +
        N' WITH PASSWORD = ' + QUOTENAME(REPLACE(@service_password, '''', ''''''), '''') + N';';

    EXEC (@sql);
END;

SET @sql = N'
USE ' + QUOTENAME(@database_name) + N';

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''' + REPLACE(@service_user, '''', '''''') + N''')
BEGIN
    CREATE USER ' + QUOTENAME(@service_user) + N' FOR LOGIN ' + QUOTENAME(@service_user) + N';
END;

ALTER USER ' + QUOTENAME(@service_user) + N' WITH DEFAULT_SCHEMA = [crmapi];

IF IS_ROLEMEMBER(N''db_owner'', N''' + REPLACE(@service_user, '''', '''''') + N''') = 1
    ALTER ROLE [db_owner] DROP MEMBER ' + QUOTENAME(@service_user) + N';
IF IS_ROLEMEMBER(N''db_ddladmin'', N''' + REPLACE(@service_user, '''', '''''') + N''') = 1
    ALTER ROLE [db_ddladmin] DROP MEMBER ' + QUOTENAME(@service_user) + N';
IF IS_ROLEMEMBER(N''db_datareader'', N''' + REPLACE(@service_user, '''', '''''') + N''') = 1
    ALTER ROLE [db_datareader] DROP MEMBER ' + QUOTENAME(@service_user) + N';
IF IS_ROLEMEMBER(N''db_datawriter'', N''' + REPLACE(@service_user, '''', '''''') + N''') = 1
    ALTER ROLE [db_datawriter] DROP MEMBER ' + QUOTENAME(@service_user) + N';

GRANT CONNECT TO ' + QUOTENAME(@service_user) + N';
GRANT EXECUTE ON SCHEMA::[crmapi] TO ' + QUOTENAME(@service_user) + N';
GRANT VIEW DEFINITION ON SCHEMA::[crm] TO ' + QUOTENAME(@service_user) + N';
';

EXEC (@sql);
