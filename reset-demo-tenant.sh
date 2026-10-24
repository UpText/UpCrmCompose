#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0 [docker compose options]"
  echo "Deletes and reinstalls demo, including all demo data. Uses the project's .env."
  echo "Example: $0 -f compose.yaml -f compose.external-sql.yaml"
  exit 0
fi
cd "${repo_dir}"
docker compose "$@" run --rm --no-deps --build \
  --volume "${repo_dir}/db/init-image:/reset:ro" \
  --entrypoint /bin/bash db-init /reset/reset-demo-tenant.sh
