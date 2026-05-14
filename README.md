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
- [`db/DbProjAtomicCrm.dacpac`](/Users/ole/UpText/Repos/UpCrmCompose/db/DbProjAtomicCrm.dacpac)
- [`db/init-image/Dockerfile`](/Users/ole/UpText/Repos/UpCrmCompose/db/init-image/Dockerfile)
- [`db/init-image/init-db.sh`](/Users/ole/UpText/Repos/UpCrmCompose/db/init-image/init-db.sh)

The `db-init` helper image is built locally. The app containers are pulled from Docker Hub.

## Quick start

1. Copy `.env.example` to `.env`
2. Change at least `MSSQL_SA_PASSWORD` and `JWT_SECRET`
3. Start the stack:

```bash
docker compose up --build -d
```

4. Open:

- UpCRM: [http://localhost:8082](http://localhost:8082)
- UpApi home: [http://localhost:5092](http://localhost:5092)
- UpApi docs: [http://localhost:5092/docs](http://localhost:5092/docs)
- SQL Server: `localhost,1433`

If you change `UPAPI_PORT` or `UPCRM_PORT`, the default browser-facing URLs now follow those ports automatically. You only need to set `UPAPI_PUBLIC_URL` or `UPCRM_PUBLIC_URL` yourself if you want a different hostname than `localhost`.

## Local UpApi Source Override

If you want the running `upapi` container to match your local source code instead of `docker.io/uptext/upapi:latest`, use the override file:

```bash
docker compose -f compose.yaml -f compose.local-upapi.yaml up --build -d
```

This builds `upapi` from your local repo at:

- `/Users/ole/UpText/Repos/UpApi/src`

That is useful when you want behavior such as the homepage in [`Home.cs`](/Users/ole/UpText/Repos/UpApi/src/UpApi/Endpoints/Home.cs) to match exactly what the container is serving.

## Notes

- `UpCRM` is configured with `VITE_SQLWEBAPI_URL=http://localhost:5092`, not `http://upapi:8080`, because that setting runs in the browser.
- The published runtime images are currently used as `linux/amd64`. On ARM hosts, Docker will run them through emulation.
- SQL Server still listens on `1433` inside the Docker network. If `1433` is busy on the host, set `SQL_PORT=1434` in `.env`; `db-init` and `upapi` will still use the internal `sqlserver:1433` address.
- SQL data is persisted in the named Docker volume `sqlserver-data`.
- If `1433`, `5092`, or `8082` is already in use on the host, change `SQL_PORT`, `UPAPI_PORT`, or `UPCRM_PORT` in `.env`.
- To rebuild the database from scratch, run:

```bash
docker compose down -v
docker compose up --build -d
```
