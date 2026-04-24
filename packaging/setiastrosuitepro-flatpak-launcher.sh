#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/app"
VENV_PYTHON="${APP_ROOT}/venv/bin/python3"
APP_ID="com.setiastro.SetiAstroSuitePro"

if [[ ! -x "${VENV_PYTHON}" ]]; then
  echo "Python runtime not found at ${VENV_PYTHON}" >&2
  exit 1
fi

# Keep temporary files and ML caches in a persistent, user-writable location.
: "${XDG_DATA_HOME:=${HOME}/.var/app/${APP_ID}/data}"
: "${XDG_CACHE_HOME:=${HOME}/.var/app/${APP_ID}/cache}"

MODEL_ROOT="${XDG_DATA_HOME}/setiastro/models"
TMP_ROOT="${XDG_CACHE_HOME}/tmp"

mkdir -p "${MODEL_ROOT}" "${TMP_ROOT}"

export TMPDIR="${TMP_ROOT}"
export TMP="${TMP_ROOT}"
export TEMP="${TMP_ROOT}"

export HF_HOME="${XDG_CACHE_HOME}/huggingface"
export HUGGINGFACE_HUB_CACHE="${HF_HOME}/hub"
export TRANSFORMERS_CACHE="${HF_HOME}/transformers"
export TORCH_HOME="${XDG_CACHE_HOME}/torch"
export NUMBA_CACHE_DIR="${XDG_CACHE_HOME}/numba"

exec "${VENV_PYTHON}" -m setiastro.saspro "$@"
