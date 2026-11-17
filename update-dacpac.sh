#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cp "$repo_dir/../uptextcrm/sqlwebapi/dbProj/DbProjAtomicCrm/bin/Release/DbProjAtomicCrm.dacpac" \
  "$repo_dir/db/DbProjAtomicCrm.dacpac"
