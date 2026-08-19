#!/usr/bin/env bash

set -euo pipefail

read_secret_file() {
  local variable_name="$1"
  local file_variable_name="${variable_name}_FILE"
  local file_path="${!file_variable_name:-}"

  if [[ -n "${!variable_name:-}" || -z "${file_path}" ]]; then
    return
  fi

  if [[ ! -f "${file_path}" ]]; then
    echo "${file_variable_name} points to missing file: ${file_path}" >&2
    exit 1
  fi

  printf -v "${variable_name}" '%s' "$(tr -d '\r\n' < "${file_path}")"
  export "${variable_name}"
}

read_secret_file SQL_ADMIN_PASSWORD
read_secret_file ADMIN_TENANT_PASSWORD
read_secret_file SERVICE_SQL_PASSWORD

: "${SQL_SERVER:?SQL_SERVER is required}"
: "${SQL_PORT:=1433}"
: "${SQL_ADMIN_USER:=sa}"
: "${SQL_ADMIN_PASSWORD:?SQL_ADMIN_PASSWORD is required}"
: "${SQL_DATABASE:?SQL_DATABASE is required}"
: "${ADMIN_TENANT_PASSWORD:?ADMIN_TENANT_PASSWORD is required}"
: "${SERVICE_SQL_USER:=upservice}"
: "${SERVICE_SQL_PASSWORD:?SERVICE_SQL_PASSWORD is required}"
: "${SQL_LOG_SCHEMA:=dbo}"
: "${SQL_LOG_TABLE:=log}"

wait_for_sql() {
  local timeout_seconds="${SQL_WAIT_TIMEOUT_SECONDS:-300}"
  local start_time="${SECONDS}"
  local last_status=0
  local last_error_file
  local next_status_at=10
  local elapsed_seconds=0

  last_error_file="$(mktemp)"

  echo "Waiting for SQL Server at ${SQL_SERVER}:${SQL_PORT}..."

  until sqlcmd -b -C -l 5 \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -Q "SELECT 1" >/dev/null 2>"${last_error_file}"; do
    last_status=$?

    elapsed_seconds=$((SECONDS - start_time))

    if (( elapsed_seconds >= timeout_seconds )); then
      echo "Timed out after ${timeout_seconds}s waiting for SQL Server at ${SQL_SERVER}:${SQL_PORT}." >&2
      echo "Last sqlcmd error:" >&2
      sed 's/^/  /' "${last_error_file}" >&2
      rm -f "${last_error_file}"
      exit "${last_status}"
    fi

    if (( elapsed_seconds >= next_status_at )); then
      echo "Still waiting for SQL Server at ${SQL_SERVER}:${SQL_PORT}; ${elapsed_seconds}s elapsed."
      next_status_at=$((next_status_at + 30))
    fi

    sleep 2
  done

  rm -f "${last_error_file}"
  echo "SQL Server is accepting connections."
}

create_database_if_missing() {
  echo "Ensuring database [${SQL_DATABASE}] exists..."

  sqlcmd -b -C \
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

seed_service_login() {
  echo "Ensuring SQL service login [${SERVICE_SQL_USER}] exists with EXECUTE on [crmapi] and metadata visibility on [crm]..."

  sqlcmd -b -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -d master \
    -v SERVICE_SQL_USER="${SERVICE_SQL_USER}" SERVICE_SQL_PASSWORD="${SERVICE_SQL_PASSWORD}" SQL_DATABASE="${SQL_DATABASE}" \
    -i /app/seed-service-login.sql
}

seed_sql_log() {
  echo "Ensuring SQL log table [${SQL_LOG_SCHEMA}].[${SQL_LOG_TABLE}] exists..."

  sqlcmd -b -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -d "${SQL_DATABASE}" \
    -v SERVICE_SQL_USER="${SERVICE_SQL_USER}" SQL_LOG_SCHEMA="${SQL_LOG_SCHEMA}" SQL_LOG_TABLE="${SQL_LOG_TABLE}" \
    -i /app/seed-sql-log.sql
}

seed_admin_users() {
  local admin_tenant_password_escaped
  admin_tenant_password_escaped="${ADMIN_TENANT_PASSWORD//\'/\'\'}"

  echo "Seeding tenant admin users..."

  sqlcmd -b -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -d "${SQL_DATABASE}" \
    -v ADMIN_TENANT_PASSWORD_ESCAPED="${admin_tenant_password_escaped}" \
    -i /app/seed-admin-users.sql
}

seed_tenant_settings() {
  echo "Seeding tenant settings..."

  sqlcmd -b -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -d "${SQL_DATABASE}" \
    -i /app/seed-tenant-settings.sql
}

seed_demo_tenant() {
  echo "Seeding demo tenant data..."

  sqlcmd -b -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -d "${SQL_DATABASE}" \
    -i /app/seed-demo-tenant.sql
}

seed_demo_objects() {
  echo "Seeding demo tenant objects..."

  sqlcmd -b -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -d "${SQL_DATABASE}" \
    -i /app/seed-demo-objects.sql
}

seed_demo_notes() {
  echo "Seeding demo notes..."

  sqlcmd -b -C \
    -S "${SQL_SERVER},${SQL_PORT}" \
    -U "${SQL_ADMIN_USER}" \
    -P "${SQL_ADMIN_PASSWORD}" \
    -d "${SQL_DATABASE}" \
    -i /app/seed-demo-notes.sql
}

wait_for_sql
create_database_if_missing
publish_dacpac
seed_service_login
seed_sql_log
seed_admin_users
seed_demo_tenant
seed_tenant_settings
seed_demo_objects
seed_demo_notes

echo "Database initialization completed."
