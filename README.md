# UpCrm Compose

This repo starts the full local stack with Docker Compose:

- SQL Server
- a one-shot database initializer that publishes the bundled CRM `dacpac`
- `uptext/upapi`
- `uptext/upcrm`

It is designed to work on a new Windows or Linux machine with Docker installed.
Git is only needed if you want to clone the repository. Once you have the files locally, running the stack only requires Docker.

## What is included

- [`compose.yaml`](/Users/ole/UpText/Repos/UpCrmCompose/compose.yaml)
- [`compose.external-sql.yaml`](/Users/ole/UpText/Repos/UpCrmCompose/compose.external-sql.yaml)
- [`db/DbProjAtomicCrm.dacpac`](/Users/ole/UpText/Repos/UpCrmCompose/db/DbProjAtomicCrm.dacpac)
- [`db/init-image/Dockerfile`](/Users/ole/UpText/Repos/UpCrmCompose/db/init-image/Dockerfile)
- [`db/init-image/init-db.sh`](/Users/ole/UpText/Repos/UpCrmCompose/db/init-image/init-db.sh)

The `db-init` helper image is built locally. The app containers are pulled from Docker Hub.

## Quick start

1. Copy `.env.example` to `.env`
2. Change at least `MSSQL_SA_PASSWORD`, `ADMIN_TENANT_PASSWORD`, `UPAPI_SQL_PASSWORD`, and `JWT_SECRET`
3. Start the stack:

```bash
docker compose up --build -d
```

4. Open:

- UpCRM: [http://localhost:8082](http://localhost:8082)
- UpApi home: [http://localhost:5092](http://localhost:5092)
- UpApi docs: [http://localhost:5092/docs](http://localhost:5092/docs)
- UpApi SQL log UI: [http://localhost:5092/sql-log-view](http://localhost:5092/sql-log-view)
- SQL Server: `localhost,1433`

Seeded tenant users:

- `default`: `admin@default.local` / `default123+`
- `admin`: `admin@admin.local` / value of `ADMIN_TENANT_PASSWORD`
- `demo`: `demo@local.com` / `demo123+`

The `demo` tenant is also seeded with sample companies, contacts, and sales records.
All three seeded tenants also get baseline configuration and an `attachments` bucket.
The `demo` tenant also gets an initial contact note so it opens on the dashboard instead of the onboarding stepper after login.
The stack also enables UpApi's SQL log feature. By default, `db-init` creates `dbo.log`, grants the `upservice` login `SELECT`, `INSERT`, and `DELETE` on that table, and UpApi writes log entries there.

If you change `UPAPI_PORT` or `UPCRM_PORT`, the default browser-facing URLs now follow those ports automatically. You only need to set `UPAPI_PUBLIC_URL` or `UPCRM_PUBLIC_URL` yourself if you want a different hostname than `localhost`.

## Secrets

Local secret values are set in `.env`. Compose exposes them to containers as Docker secrets instead of passing them directly as application environment values, so no separate `secrets/` directory is required.

- `sqlserver` reads `mssql_sa_password` from `/run/secrets/mssql_sa_password` before starting SQL Server.
- `db-init` reads `SQL_ADMIN_PASSWORD_FILE`, `ADMIN_TENANT_PASSWORD_FILE`, and `SERVICE_SQL_PASSWORD_FILE`.
- `upapi` reads `jwt_secret` from `/run/secrets/jwt_secret` before starting, and uses its secret resolver with `{{secret:upapi_sql_password}}` for SQL connection strings.

The top-level Compose secrets are sourced directly from these `.env` variables:

```env
MSSQL_SA_PASSWORD=...
ADMIN_TENANT_PASSWORD=...
UPAPI_SQL_PASSWORD=...
JWT_SECRET=...
EXTERNAL_SQL_ADMIN_PASSWORD=...
```

## UpApi SQL Log

The compose stack enables SqlLog through these UpApi settings:

```env
UPAPI_SQLLOG_SCHEMA=dbo
UPAPI_SQLLOG_TABLE=log
UPAPI_SQLLOG_RETENTION_DAYS=30
```

By default, the SQL log connection uses the same SQL Server, database, service login, and Docker secret-backed service password as `crmapi`.

Open the log UI at [http://localhost:5092/sql-log-view](http://localhost:5092/sql-log-view), or query the API directly:

```bash
curl "http://localhost:5092/SqlLog?service=crmapi&maxHours=24&FromRow=0&ToRow=100"
```

## Local UpApi Source Override

If you want the running `upapi` container to match your local source code instead of `docker.io/uptext/upapi:latest`, use the override file:

```bash
docker compose -f compose.yaml -f compose.local-upapi.yaml up --build -d
```

This builds `upapi` from your local repo at:

- `/Users/ole/UpText/Repos/UpApi/src`

That is useful when you want behavior such as the homepage in [`Home.cs`](/Users/ole/UpText/Repos/UpApi/src/UpApi/Endpoints/Home.cs) to match exactly what the container is serving.

## Use An Existing SQL Server

If you already have SQL Server installed and want to use that instead of the bundled `sqlserver` container, use the external-SQL override.

1. Copy `.env.example` to `.env` if you have not already done so.
2. Set at least these values in `.env`:

```env
EXTERNAL_SQL_SERVER=host.docker.internal
EXTERNAL_SQL_PORT=1433
EXTERNAL_SQL_ADMIN_USER=sa
EXTERNAL_SQL_ADMIN_PASSWORD=YourExistingSqlAdminPassword123!

MSSQL_DB=UpCrm
UPAPI_SQL_USER=upservice
UPAPI_SQL_PASSWORD=CrmExec_42!BlueStone
JWT_SECRET=YourLongRandomJwtSecretHere
UPAPI_PORT=8081
UPCRM_PORT=8080
UPAPI_PUBLIC_URL=http://localhost:8081
UPCRM_PUBLIC_URL=http://localhost:8080
```

3. Start only the app services with the external-SQL override:

```bash
docker compose -f compose.yaml -f compose.external-sql.yaml up --build -d db-init upapi upcrm
```

This does three things:

- `db-init` connects to the existing SQL Server and publishes the bundled `dacpac`
- `db-init` creates or updates the dedicated `upservice` login, grants it `EXECUTE` on the `crmapi` schema, and grants metadata visibility on the `crm` table schema for SQL generation
- `upapi` uses that `upservice` login instead of `sa`
- `db-init` creates and grants access to the configured SQL log table

Platform notes:

- Docker Desktop on Windows or Mac: `host.docker.internal` usually reaches SQL Server running on the host machine.
- Linux: `host.docker.internal` may not exist by default. Use the host machine IP address instead if needed.
- Remote SQL Server on another machine: set `EXTERNAL_SQL_SERVER` to that host name or IP.

Requirements for the existing SQL Server:

- SQL Server must accept TCP connections on the configured port
- SQL authentication must be enabled if you use `sa` or another SQL login
- the admin login in `EXTERNAL_SQL_ADMIN_USER` / `EXTERNAL_SQL_ADMIN_PASSWORD` must be allowed to create the database, publish schema changes, and create the `upservice` login
- the service password in `UPAPI_SQL_PASSWORD` must satisfy SQL Server password policy and must not contain the login name `upservice`

## Notes

- `UpCRM` is configured with `VITE_SQLWEBAPI_URL=http://localhost:5092`, not `http://upapi:8080`, because that setting runs in the browser.
- The published runtime images are currently used as `linux/amd64`. On ARM hosts, Docker will run them through emulation.
- SQL Server still listens on `1433` inside the Docker network. If `1433` is busy on the host, set `SQL_PORT=1434` in `.env`; `db-init` and `upapi` will still use the internal `sqlserver:1433` address.
- If `db-init` waits for SQL Server and then reports login failure for user `sa`, the existing `sqlserver-data` volume was probably created with a different `MSSQL_SA_PASSWORD`. Either restore the old password in `.env`, or rebuild the local database from scratch with `docker compose down -v` followed by `docker compose up --build -d`.
- `upapi` connects with the dedicated SQL login from `UPAPI_SQL_USER` / `UPAPI_SQL_PASSWORD`. The bootstrap creates that login, grants it `EXECUTE` on the `crmapi` schema, and grants metadata visibility on the `crm` table schema for SQL generation.
- SQL data is persisted in the named Docker volume `sqlserver-data`.
- If `1433`, `5092`, or `8082` is already in use on the host, change `SQL_PORT`, `UPAPI_PORT`, or `UPCRM_PORT` in `.env`.
- To rebuild the database from scratch, run:

```bash
docker compose down -v
docker compose up --build -d
```
