SET NOCOUNT ON;

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
    N'ZRkJ0398w5R0MYBx0/XgGSopK28yXLdPu6y/H74jq+Y='
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
