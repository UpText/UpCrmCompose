SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;

DECLARE @AdminTenantPassword NVARCHAR(4000) = N'$(ADMIN_TENANT_PASSWORD_ESCAPED)';
DECLARE @AdminTenantPasswordHash NVARCHAR(100);

IF @AdminTenantPassword IS NULL OR LTRIM(RTRIM(@AdminTenantPassword)) = N''
BEGIN
    THROW 50000, 'ADMIN_TENANT_PASSWORD is required.', 1;
END;

SELECT @AdminTenantPasswordHash = CAST(N'' AS XML).value(
    'xs:base64Binary(xs:hexBinary(sql:column("hash_bytes_hex")))',
    'NVARCHAR(100)'
)
FROM
(
    SELECT CONVERT(
        VARCHAR(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(VARCHAR(MAX), @AdminTenantPassword) COLLATE Latin1_General_100_BIN2_UTF8
        ),
        2
    ) AS hash_bytes_hex
) AS password_hash_source;

DECLARE @Tenants TABLE
(
    name NVARCHAR(255) NOT NULL,
    display_name NVARCHAR(255) NOT NULL,
    active BIT NOT NULL,
    activated_at DATETIME2 NOT NULL,
    deactivated_at DATETIME2 NULL,
    created_at DATETIME2 NOT NULL
);

INSERT INTO @Tenants
(
    name,
    display_name,
    active,
    activated_at,
    deactivated_at,
    created_at
)
VALUES
(
    N'default',
    N'Default CRM',
    1,
    SYSUTCDATETIME(),
    NULL,
    SYSUTCDATETIME()
),
(
    N'admin',
    N'Admin CRM',
    1,
    SYSUTCDATETIME(),
    NULL,
    SYSUTCDATETIME()
);

MERGE crm.tenants AS target
USING @Tenants AS source
    ON target.name = source.name
WHEN MATCHED THEN
    UPDATE SET
        display_name = source.display_name,
        active = source.active,
        activated_at = source.activated_at,
        deactivated_at = source.deactivated_at
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        name,
        display_name,
        active,
        activated_at,
        deactivated_at,
        created_at
    )
    VALUES
    (
        source.name,
        source.display_name,
        source.active,
        source.activated_at,
        source.deactivated_at,
        source.created_at
    );

DECLARE @Users TABLE
(
    tenant NVARCHAR(255) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    email NVARCHAR(320) NOT NULL,
    first_name NVARCHAR(100) NOT NULL,
    last_name NVARCHAR(100) NOT NULL,
    administrator BIT NOT NULL,
    disabled BIT NOT NULL,
    password_hash NVARCHAR(100) NOT NULL
);

INSERT INTO @Users
(
    tenant,
    user_id,
    email,
    first_name,
    last_name,
    administrator,
    disabled,
    password_hash
)
VALUES
(
    N'default',
    'admin',
    N'admin@default.local',
    N'Admin',
    N'User',
    1,
    0,
    N'v2iQGkLtfSoCeLUyzrkzK9dE6TBQrOHS9KUlcZ0Fe7E='
),
(
    N'admin',
    'admin',
    N'admin@admin.local',
    N'Admin',
    N'User',
    1,
    0,
    @AdminTenantPasswordHash
);

MERGE crm.sales AS target
USING @Users AS source
    ON target.tenant = source.tenant
   AND target.user_id = source.user_id
WHEN MATCHED THEN
    UPDATE SET
        email = source.email,
        first_name = source.first_name,
        last_name = source.last_name,
        administrator = source.administrator,
        disabled = source.disabled,
        PasswordHash = source.password_hash,
        updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        tenant,
        user_id,
        email,
        first_name,
        last_name,
        administrator,
        disabled,
        PasswordHash
    )
    VALUES
    (
        source.tenant,
        source.user_id,
        source.email,
        source.first_name,
        source.last_name,
        source.administrator,
        source.disabled,
        source.password_hash
    );
