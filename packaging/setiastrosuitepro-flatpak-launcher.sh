#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/app"
VENV_PYTHON="${APP_ROOT}/venv/bin/python3"

if [[ ! -x "${VENV_PYTHON}" ]]; then
  echo "Python runtime not found at ${VENV_PYTHON}" >&2
  exit 1
fi

exec "${VENV_PYTHON}" -m setiastro.saspro "$@"
