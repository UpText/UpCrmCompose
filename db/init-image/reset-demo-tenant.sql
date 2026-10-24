:On Error exit
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM crm.tenants WHERE name = N'demo')
BEGIN
    UPDATE crm.tenants SET active = 0 WHERE name = N'demo';

    DECLARE @DeleteStatus INT;
    EXEC @DeleteStatus = crmapi.tenants_delete @id = 'demo', @auth_tenant = N'admin';
    IF @DeleteStatus <> 204
        THROW 50000, 'Demo tenant deletion failed.', 1;
END;

-- Seed IDs are global. Refuse to overwrite another tenant's records.
IF EXISTS (SELECT 1 FROM crm.sales WHERE id BETWEEN 3 AND 9 AND tenant <> N'demo')
   OR EXISTS (SELECT 1 FROM crm.companies WHERE id BETWEEN 1 AND 55 AND tenant <> N'demo')
   OR EXISTS (SELECT 1 FROM crm.contacts WHERE id BETWEEN 1 AND 500 AND tenant <> N'demo')
   OR EXISTS (SELECT 1 FROM crm.deals WHERE id BETWEEN 1 AND 50 AND tenant <> N'demo')
    THROW 50000, 'Demo seed IDs may conflict with other tenant data. Reset rolled back.', 1;

:r /reset/seed-demo-tenant.sql

:r /reset/seed-demo-configuration.sql
INSERT INTO crm.buckets (tenant, bucket_id, is_public)
VALUES (N'demo', 'attachments', 0);

:r /reset/seed-demo-objects.sql
:r /reset/seed-demo-notes.sql

COMMIT TRANSACTION;
