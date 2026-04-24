#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/setiastrosuitepro"
VENV_BIN="${APP_ROOT}/venv/bin"
VENV_PYTHON="${VENV_BIN}/python3"

if [[ ! -x "${VENV_PYTHON}" ]]; then
  echo "Python runtime not found in ${VENV_BIN}" >&2
  exit 1
fi

# Run the module directly so startup does not depend on pip-generated wrapper
# scripts that may contain build-time absolute paths.
exec "${VENV_PYTHON}" -m setiastro.saspro "$@"
