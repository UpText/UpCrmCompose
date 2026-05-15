SET NOCOUNT ON;

DECLARE @TenantSettings TABLE
(
    tenant NVARCHAR(255) NOT NULL,
    config_id INT NOT NULL,
    config NVARCHAR(MAX) NOT NULL,
    updated_by NVARCHAR(255) NOT NULL
);

INSERT INTO @TenantSettings
(
    tenant,
    config_id,
    config,
    updated_by
)
VALUES
(
    N'admin',
    1,
    N'{"title":"Admin CRM"}',
    N'system'
),
(
    N'default',
    1,
    N'{"title":"Default CRM"}',
    N'system'
),
(
    N'demo',
    1,
    N'{"title":"Demo CRM"}',
    N'system'
);

MERGE crm.configuration AS target
USING @TenantSettings AS source
    ON target.tenant = source.tenant
   AND target.id = source.config_id
WHEN MATCHED THEN
    UPDATE SET
        config = source.config,
        updated_at = SYSUTCDATETIME(),
        updated_by = source.updated_by
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        tenant,
        id,
        config,
        updated_by
    )
    VALUES
    (
        source.tenant,
        source.config_id,
        source.config,
        source.updated_by
    );

DECLARE @TenantBuckets TABLE
(
    tenant NVARCHAR(255) NOT NULL,
    bucket_id VARCHAR(50) NOT NULL,
    is_public BIT NOT NULL
);

INSERT INTO @TenantBuckets
(
    tenant,
    bucket_id,
    is_public
)
VALUES
(
    N'admin',
    'attachments',
    0
),
(
    N'default',
    'attachments',
    0
),
(
    N'demo',
    'attachments',
    0
);

MERGE crm.buckets AS target
USING @TenantBuckets AS source
    ON target.tenant = source.tenant
   AND target.bucket_id = source.bucket_id
WHEN MATCHED THEN
    UPDATE SET
        is_public = source.is_public
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        tenant,
        bucket_id,
        is_public
    )
    VALUES
    (
        source.tenant,
        source.bucket_id,
        source.is_public
    );
