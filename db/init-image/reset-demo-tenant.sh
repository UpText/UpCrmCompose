#!/usr/bin/env bash
set -euo pipefail

: "${SQL_SERVER:?SQL_SERVER is required}"
: "${SQL_DATABASE:?SQL_DATABASE is required}"
: "${SQL_ADMIN_USER:=sa}"
: "${SQL_PORT:=1433}"
if [[ -z "${SQL_ADMIN_PASSWORD:-}" ]]; then
  : "${SQL_ADMIN_PASSWORD_FILE:?SQL_ADMIN_PASSWORD or SQL_ADMIN_PASSWORD_FILE is required}"
  SQL_ADMIN_PASSWORD="$(tr -d '\r\n' < "${SQL_ADMIN_PASSWORD_FILE}")"
fi
: "${SQL_ADMIN_PASSWORD:?SQL admin password is empty}"
export SQLCMDPASSWORD="${SQL_ADMIN_PASSWORD}"
DEMO_PASSWORD_HASH="$(printf %s demo123+ | dotnet /app/password-hasher/UpCrm.PasswordHasher.dll)"
export DEMO_PASSWORD_HASH

echo "Resetting demo tenant in ${SQL_DATABASE} on ${SQL_SERVER}:${SQL_PORT}..."
sqlcmd -b -C -S "${SQL_SERVER},${SQL_PORT}" -U "${SQL_ADMIN_USER}" \
  -d "${SQL_DATABASE}" -i /reset/reset-demo-tenant.sql
echo "Demo tenant reinstalled. Login: demo@local.com / demo123+ (tenant: demo)."
