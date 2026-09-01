# Create a New UpApi Service Named `myapi`

This guide describes the steps needed to expose a second SQL-backed API service named `myapi` through UpApi.

UpApi routes requests by service name:

```text
/{service}/{resource}
/{service}/{resource}/{id}

```

For `myapi`, stored procedures are created in the SQL schema `[myapi]`, and requests call those procedures by resource and HTTP verb. For example:

```text
GET /swa/myapi/ping
```

executes:

```sql
[myapi].[ping_get]
```

## 1. Create the SQL schema

Run this in the target UpCrm database as an admin login.

```sql
USE [UpCrm];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'myapi')
BEGIN
    EXEC(N'CREATE SCHEMA [myapi] AUTHORIZATION [dbo];');
END;
GO
```

If `myapi` should expose procedures over tables in a separate table schema, create that table schema too. If it should use the existing CRM tables, keep the table schema as `[crm]`.

```sql
USE [UpCrm];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'mydata')
BEGIN
    EXEC(N'CREATE SCHEMA [mydata] AUTHORIZATION [dbo];');
END;
GO
```

## 2. Add `upservice` access

The compose stack uses the dedicated SQL login from `UPAPI_SQL_USER`, which defaults to `upservice`. Grant it permission to connect and execute procedures in the new API schema.

```sql

GRANT EXECUTE ON SCHEMA::[myapi] TO [upservice];

GRANT VIEW DEFINITION ON SCHEMA::[myapi] TO [upservice];
GO
```

If this should be part of local bootstrap, add the same grants to [`db/init-image/seed-service-login.sql`](/Users/ole/UpText/Repos/UpCrmCompose/db/init-image/seed-service-login.sql), or add a separate seed script and call it from [`db/init-image/init-db.sh`](/Users/ole/UpText/Repos/UpCrmCompose/db/init-image/init-db.sh).

## 3. Add stored procedures

Create stored procedures in `[myapi]` using the naming convention:

```text
<resource>_<verb>
<resource>_<details>_<verb>
```

Supported verbs are `get`, `post`, `put`, and `delete`.

Minimal health-check procedure:

```sql
USE [UpCrm];
GO

CREATE OR ALTER PROCEDURE [myapi].[ping_get]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        service = N'myapi',
        status = N'ok',
        checked_at = SYSUTCDATETIME();
END;
GO
```

Example authenticated procedure:

```sql
USE [UpCrm];
GO

CREATE OR ALTER PROCEDURE [myapi].[profile_get]
(
    @auth_tenant NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tenant = @auth_tenant,
        message = N'Bearer token was accepted';
END;
GO
```

Parameters named `@auth_*` are filled from JWT claims and mark the endpoint as protected in generated OpenAPI.

## 4. Add UpApi settings

UpApi binds services from the `Services` configuration section. Add a `myapi` service entry with:

- `SqlSchema`: the schema containing the stored procedures, here `myapi`
- `TableSchema`: the schema used by SQL generator metadata, here `mydata` if you created the new table schema above, or `crm` if `myapi` reads existing CRM tables
- `SqlConnectionString`: the SQL connection string for `upservice`

In [`compose.yaml`](/Users/ole/UpText/Repos/UpCrmCompose/compose.yaml), add these environment variables under the `upapi` service:

```yaml
SQLWEBAPI__SWAGGER: ${UPCRM_SERVICE:-crmapi},myapi
Services__myapi__SqlSchema: myapi
Services__myapi__TableSchema: ${MYAPI_TABLE_SCHEMA:-mydata}
Services__myapi__SqlConnectionString: Server=sqlserver,1433;Initial Catalog=${MSSQL_DB:-UpCrm};User ID=${UPAPI_SQL_USER:-upservice};Password={{secret:upapi_sql_password}};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;
```

If you use [`compose.external-sql.yaml`](/Users/ole/UpText/Repos/UpCrmCompose/compose.external-sql.yaml), add this under its `upapi.environment` block too:

```yaml
Services__myapi__SqlConnectionString: Server=${EXTERNAL_SQL_SERVER:?Set EXTERNAL_SQL_SERVER in .env},${EXTERNAL_SQL_PORT:-1433};Initial Catalog=${MSSQL_DB:-UpCrm};User ID=${UPAPI_SQL_USER:-upservice};Password={{secret:upapi_sql_password}};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;
```

Add the optional table-schema setting to [`.env.example`](/Users/ole/UpText/Repos/UpCrmCompose/.env.example) and `.env` if you want it configurable:

```env
MYAPI_TABLE_SCHEMA=mydata
```

Important: `.env` values only provide variable values to Compose. They do not become UpApi configuration unless [`compose.yaml`](/Users/ole/UpText/Repos/UpCrmCompose/compose.yaml) references them in the `upapi.environment` block. If you only add `MYAPI_TABLE_SCHEMA=mydata` to `.env`, UpApi still returns `{"message":"Unknown service"}` because no `Services__myapi__...` configuration exists inside the container.

For a non-Compose UpApi install, the equivalent `appsettings.json` shape is:

```json
{
  "SQLWEBAPI": {
    "SWAGGER": "crmapi,myapi"
  },
  "Services": {
    "myapi": {
      "SqlSchema": "myapi",
      "TableSchema": "mydata",
      "SqlConnectionString": "Server=sqlserver,1433;Initial Catalog=UpCrm;User ID=upservice;Password={{secret:upapi_sql_password}};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
    }
  }
}
```

## 5. Restart and validate

On the Ubuntu server, confirm Compose is rendering the `myapi` settings before restarting:

```bash
docker compose config | grep -A3 -B1 'Services__myapi'
```

You should see:

```yaml
Services__myapi__SqlSchema: myapi
Services__myapi__TableSchema: mydata
Services__myapi__SqlConnectionString: Server=sqlserver,1433;...
```

Recreate UpApi after changing configuration:

```bash
docker compose up -d --force-recreate upapi
```

Validate the endpoint:

```bash
curl "http://localhost:8880/swa/myapi/ping"
```

Expected response:

```json
[
  {
    "service": "myapi",
    "status": "ok",
    "checked_at": "<current UTC timestamp>"
  }
]
```

Open generated docs:

```text
http://localhost:8880/docs/myapi
http://localhost:8880/swa/myapi/swagger.json
```

## Troubleshooting `Unknown service`

This response comes from UpApi before it tries to execute SQL:

```json
{"message":"Unknown service"}
```

It means the running UpApi container does not have a service entry named `myapi`. Check the live container environment on the Ubuntu server:

```bash
docker compose exec upapi printenv | grep 'Services__myapi'
```

If nothing prints, update [`compose.yaml`](/Users/ole/UpText/Repos/UpCrmCompose/compose.yaml), not just `.env`, then recreate the container:

```bash
docker compose up -d --force-recreate upapi
```

If the service is configured but the procedure or SQL permissions are missing, the response will change from `Unknown service` to a database error.
