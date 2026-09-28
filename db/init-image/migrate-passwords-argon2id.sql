-- Adapted from UpTextApi 20260928_crm_argon2id.sql.
-- Applied after the bundled DACPAC on every initialization. Procedure definition
-- fingerprints are omitted because the DACPAC restores its own definitions.
-- Run against the configured UpCrm database with a migration-capable account.
-- Coordinate with the API deployment; stop the old API before applying.
-- Existing hashes are preserved. Legacy SHA-256 accounts still require resets.
-- No plaintext password, connection credential, or stored hash is embedded here.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- The initializer selects SQL_DATABASE, which may have a custom name.

BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'crm.sales') AND name = N'PasswordHash'
          AND TYPE_NAME(user_type_id) = N'nvarchar' AND max_length IN (200, 512)
          AND is_nullable = 1
    ) THROW 51000, 'Unexpected crm.sales.PasswordHash schema; review before migrating.', 1;

    ALTER TABLE crm.sales ALTER COLUMN PasswordHash NVARCHAR(256) NULL;

    EXEC sys.sp_executesql N'
ALTER PROCEDURE [crmapi].[tenants_post](
    @tenant NVARCHAR(255),
    @admin_email NVARCHAR(255),
    @passwordHash NVARCHAR(256)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @normalized_tenant NVARCHAR(255) = LTRIM(RTRIM(@tenant));
    DECLARE @normalized_admin_email NVARCHAR(255) = LOWER(LTRIM(RTRIM(@admin_email)));

    IF @normalized_tenant IS NULL OR @normalized_tenant = N''''
    BEGIN
        RAISERROR(''Tenant is required.'', 16, 1);
        RETURN 400;
    END

    IF LEN(@normalized_tenant) < 3 OR LEN(@normalized_tenant) > 5
    BEGIN
        RAISERROR(''Tenant must be between 3 and 5 characters.'', 16, 1);
        RETURN 400;
    END

    IF @normalized_tenant COLLATE Latin1_General_BIN2 LIKE N''%[^a-z0-9-]%''
    BEGIN
        RAISERROR(''Tenant may only contain a-z, 0-9, and -.'', 16, 1);
        RETURN 400;
    END

    IF @normalized_admin_email IS NULL OR @normalized_admin_email = N''''
    BEGIN
        RAISERROR(''admin_email is required.'', 16, 1);
        RETURN 400;
    END

    IF @normalized_admin_email NOT LIKE N''%_@_%._%''
    BEGIN
        RAISERROR(''admin_email must be a valid email address.'', 16, 1);
        RETURN 400;
    END

    IF @passwordHash IS NULL OR @passwordHash NOT LIKE N''$argon2id$v=19$%''
    BEGIN
        RAISERROR(''An Argon2id password hash is required.'', 16, 1);
        RETURN 400;
    END

    IF EXISTS (SELECT 1 FROM crm.tenants WHERE name = @normalized_tenant)
    BEGIN
        RAISERROR(''Tenant already exists.'', 16, 1);
        RETURN 409;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM crm.configuration
        WHERE tenant = N''default''
          AND id = 1
    )
    BEGIN
        RAISERROR(''Default configuration was not found.'', 16, 1);
        RETURN 500;
    END

    BEGIN TRANSACTION;

    INSERT INTO crm.tenants (name, display_name)
    VALUES (@normalized_tenant, @normalized_tenant);

    INSERT INTO crm.configuration (tenant, id, config, updated_at, updated_by)
    SELECT
        @normalized_tenant,
        id,
        JSON_MODIFY(config, ''$.title'', @normalized_tenant + N'' CRM''),
        SYSUTCDATETIME(),
        N''system''
    FROM crm.configuration
    WHERE tenant = N''default''
      AND id = 1;

    INSERT INTO crm.sales (
        tenant,
        user_id,
        email,
        first_name,
        last_name,
        administrator,
        disabled,
        PasswordHash
    )
    VALUES (
        @normalized_tenant,
        N''admin'',
        @normalized_admin_email,
        N''Admin'',
        N''User'',
        1,
        0,
        @passwordHash
    );

    COMMIT TRANSACTION;

    SELECT
        t.name AS id,
        t.name AS tenant,
        t.display_name,
        t.active,
        t.activated_at,
        t.deactivated_at,
        t.created_at,
        s.id AS admin_id,
        s.email AS admin_email
    FROM crm.tenants t
    INNER JOIN crm.sales s
        ON s.tenant = t.name
       AND s.user_id = N''admin''
    WHERE t.name = @normalized_tenant;

    RETURN 201;
END;
';

    EXEC sys.sp_executesql N'ALTER PROCEDURE [crmapi].[sales_Password_Put](
    @id VARCHAR(MAX),
    @passwordHash NVARCHAR(256),
    @auth_email VARCHAR(MAX),
    @auth_tenant NVARCHAR(255)
) AS
BEGIN
    DECLARE @user_id INT;
    DECLARE @IsAdmin BIT;

    SELECT @user_id = id, @IsAdmin = administrator
    FROM crm.sales
    WHERE email = @auth_email
      AND tenant = @auth_tenant;

    IF @user_id IS NULL
        RETURN 401;

    IF @IsAdmin = 0 AND @user_id != @id
    BEGIN
        RAISERROR(''Unauthorized'', 16, 1);
        RETURN 400;
    END

    IF @passwordHash IS NULL OR @passwordHash NOT LIKE N''$argon2id$v=19$%''
    BEGIN
        RAISERROR(''An Argon2id password hash is required.'', 16, 1);
        RETURN 400;
    END

    UPDATE crm.sales
    SET PasswordHash = @passwordHash
    WHERE id = @id
      AND tenant = @auth_tenant;
END';

    EXEC sys.sp_executesql N'ALTER PROCEDURE [crmapi].[sales_post](
    @user_id varchar(50) = NULL,
    @email nvarchar(320) = NULL,
    @first_name nvarchar(100) = NULL,
    @last_name nvarchar(100) = NULL,
    @administrator bit = NULL,
    @disabled bit = 0,
    @avatar_src nvarchar(2048) = NULL,
    @avatar_title nvarchar(255) = NULL,
    @avatar_path nvarchar(1024) = NULL,
    @avatar_type nvarchar(128) = NULL,
    @auth_tenant NVARCHAR(255) = NULL,
    @passwordhash NVARCHAR(256) = NULL
) AS
BEGIN
    IF @passwordHash IS NULL OR @passwordHash NOT LIKE N''$argon2id$v=19$%''
    BEGIN
        RAISERROR(''An Argon2id password hash is required.'', 16, 1);
        RETURN 400;
    END

    INSERT INTO crm.sales (
        tenant,
        user_id,
        email,
        first_name,
        last_name,
        administrator,
        disabled,
        avatar_src,
        avatar_title,
        avatar_path,
        avatar_type,
        PasswordHash
    )
    VALUES (
        @auth_tenant,
        @user_id,
        @email,
        @first_name,
        @last_name,
        @administrator,
        @disabled,
        @avatar_src,
        @avatar_title,
        @avatar_path,
        @avatar_type,
        @passwordhash
   );

    DECLARE @NEWID AS VARCHAR(max) = SCOPE_IDENTITY();
    EXEC crmapi.sales_get @ID = @NEWID, @auth_tenant = @auth_tenant;
    RETURN 200;
END';

    EXEC sys.sp_executesql N'ALTER PROCEDURE [crmapi].[Login_Post](
    @username NVARCHAR(255),
    @passwordHash NVARCHAR(256) = NULL OUTPUT,
    @tenant NVARCHAR(255)
) AS
BEGIN
    SET NOCOUNT ON;
    -- This procedure only looks up credentials. The API verifies the password
    -- before issuing a JWT. Do not add successful-login side effects here.
    SET @passwordHash = NULL;

    IF @tenant IS NULL OR LTRIM(RTRIM(@tenant)) = ''''
        RETURN 401;

    IF EXISTS (
        SELECT 1 FROM crm.tenants
        WHERE name = @tenant AND active = 0
    )
        RETURN 403;

    DECLARE @sales_id INT;
    DECLARE @disabled BIT;
    SELECT @sales_id = id, @disabled = disabled
    FROM crm.sales
    WHERE tenant = @tenant AND email = @username;

    IF @sales_id IS NULL RETURN 401;
    IF @disabled = 1 RETURN 403;

    SELECT @passwordHash = PasswordHash
    FROM crm.sales
    WHERE id = @sales_id AND tenant = @tenant AND disabled = 0;

    IF @passwordHash IS NULL RETURN 401;

    -- Preserve the existing claims; the hash is only an OUTPUT parameter.
    SELECT id, tenant, user_id, email, first_name, last_name, administrator, disabled
    FROM crm.sales
    WHERE id = @sales_id AND tenant = @tenant AND disabled = 0;

    RETURN 200;
END
';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'CRM Argon2id schema migration applied; existing hashes preserved.' AS migration_result;
