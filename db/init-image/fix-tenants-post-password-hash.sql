SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE [crmapi].[tenants_post](
    @tenant NVARCHAR(255),
    @admin_email NVARCHAR(255),
    @passwordHash NVARCHAR(100)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @normalized_tenant NVARCHAR(255) = LTRIM(RTRIM(@tenant));
    DECLARE @normalized_admin_email NVARCHAR(255) = LOWER(LTRIM(RTRIM(@admin_email)));

    IF @normalized_tenant IS NULL OR @normalized_tenant = N''
    BEGIN
        RAISERROR('Tenant is required.', 16, 1);
        RETURN 400;
    END

    IF LEN(@normalized_tenant) < 3 OR LEN(@normalized_tenant) > 5
    BEGIN
        RAISERROR('Tenant must be between 3 and 5 characters.', 16, 1);
        RETURN 400;
    END

    IF @normalized_tenant COLLATE Latin1_General_BIN2 LIKE N'%[^a-z0-9-]%'
    BEGIN
        RAISERROR('Tenant may only contain a-z, 0-9, and -.', 16, 1);
        RETURN 400;
    END

    IF @normalized_admin_email IS NULL OR @normalized_admin_email = N''
    BEGIN
        RAISERROR('admin_email is required.', 16, 1);
        RETURN 400;
    END

    IF @normalized_admin_email NOT LIKE N'%_@_%._%'
    BEGIN
        RAISERROR('admin_email must be a valid email address.', 16, 1);
        RETURN 400;
    END

    IF @passwordHash IS NULL OR LTRIM(RTRIM(@passwordHash)) = N''
    BEGIN
        RAISERROR('password is required.', 16, 1);
        RETURN 400;
    END

    IF EXISTS (SELECT 1 FROM crm.tenants WHERE name = @normalized_tenant)
    BEGIN
        RAISERROR('Tenant already exists.', 16, 1);
        RETURN 409;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM crm.configuration
        WHERE tenant = N'default'
          AND id = 1
    )
    BEGIN
        RAISERROR('Default configuration was not found.', 16, 1);
        RETURN 500;
    END

    BEGIN TRANSACTION;

    INSERT INTO crm.tenants (name, display_name)
    VALUES (@normalized_tenant, @normalized_tenant);

    INSERT INTO crm.configuration (tenant, id, config, updated_at, updated_by)
    SELECT
        @normalized_tenant,
        id,
        JSON_MODIFY(config, '$.title', @normalized_tenant + N' CRM'),
        SYSUTCDATETIME(),
        N'system'
    FROM crm.configuration
    WHERE tenant = N'default'
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
        N'admin',
        @normalized_admin_email,
        N'Admin',
        N'User',
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
       AND s.user_id = N'admin'
    WHERE t.name = @normalized_tenant;

    RETURN 201;
END;
GO
