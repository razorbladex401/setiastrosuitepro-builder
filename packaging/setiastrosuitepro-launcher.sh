#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/setiastrosuitepro"
VENV_BIN="${APP_ROOT}/venv/bin"

if [[ ! -x "${VENV_BIN}/setiastrosuitepro" ]]; then
  echo "setiastrosuitepro executable not found in ${VENV_BIN}" >&2
  exit 1
fi

exec "${VENV_BIN}/setiastrosuitepro" "$@"
