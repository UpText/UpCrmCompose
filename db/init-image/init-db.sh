#!/usr/bin/env bash

set -euo pipefail

: "${SQL_SERVER:?SQL_SERVER is required}"
: "${SQL_PORT:=1433}"
: "${SQL_ADMIN_USER:=sa}"
: "${SQL_ADMIN_PASSWORD:?SQL_ADMIN_PASSWORD is required}"
: "${SQL_DATABASE:?SQL_DATABASE is required}"

wait_for_sql() {
  echo "Waiting for SQL Server at ${SQL_SERVER}:${SQL_PORT}..."

  until sqlcmd -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -Q "SELECT 1" >/dev/null 2>&1; do
    sleep 2
  done
}

create_database_if_missing() {
  echo "Ensuring database [${SQL_DATABASE}] exists..."

  sqlcmd -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -Q "IF DB_ID(N'${SQL_DATABASE}') IS NULL BEGIN CREATE DATABASE [${SQL_DATABASE}]; END;"
}

publish_dacpac() {
  local connection_string
  connection_string="Server=${SQL_SERVER},${SQL_PORT};Initial Catalog=${SQL_DATABASE};User ID=${SQL_ADMIN_USER};Password=${SQL_ADMIN_PASSWORD};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"

  echo "Publishing DACPAC to [${SQL_DATABASE}]..."

  /opt/sqlpackage/sqlpackage \
    /Action:Publish \
    /SourceFile:/app/DbProjAtomicCrm.dacpac \
    "/TargetConnectionString:${connection_string}" \
    /p:BlockOnPossibleDataLoss=False \
    "/v:DeployVersion=${DEPLOY_VERSION:-local-compose}" \
    "/v:GitCommit=${GIT_COMMIT:-manual}" \
    "/v:DeployedBy=${DEPLOYED_BY:-docker-compose}" \
    "/v:DeploymentTarget=${DEPLOYMENT_TARGET:-docker-compose}"
}

wait_for_sql
create_database_if_missing
publish_dacpac

echo "Database initialization completed."
