#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPDIR="${ROOT_DIR}/rpmbuild"
SOURCES_DIR="${TOPDIR}/SOURCES"
SPECS_DIR="${TOPDIR}/SPECS"
RPMS_DIR="${TOPDIR}/RPMS"
SRPMS_DIR="${TOPDIR}/SRPMS"
OUT_DIR="${ROOT_DIR}/out"

usage() {
  cat <<'EOF'
Usage: build_rpm.sh [--version VERSION] [--ref REF] [--release RELEASE]
                    [--python-bin PYTHON_BIN]
                    [--python-package PYTHON_PACKAGE]
                    [--python-devel-package PYTHON_DEVEL_PACKAGE]
                    [--python-pip-package PYTHON_PIP_PACKAGE]

Builds source and binary RPMs for Seti Astro Suite Pro.

Options:
  --version   Package version (default: from upstream pyproject at --ref)
  --ref       Upstream git ref (default: main)
  --release   RPM release string without dist tag (default: 1)
  --python-bin            Python executable used to create the venv (default: python3)
  --python-package        Runtime/build RPM package for that Python (default: derived from --python-bin)
  --python-devel-package  Development RPM package for that Python (default: <python-package>-devel)
  --python-pip-package    pip RPM package for that Python (default: <python-package>-pip)
EOF
}

VERSION=""
REF="main"
RELEASE="1"
PYTHON_BIN="python3"
PYTHON_PACKAGE=""
PYTHON_DEVEL_PACKAGE=""
PYTHON_PIP_PACKAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --ref)
      REF="$2"
      shift 2
      ;;
    --release)
      RELEASE="$2"
      shift 2
      ;;
    --python-bin)
      PYTHON_BIN="$2"
      shift 2
      ;;
    --python-package)
      PYTHON_PACKAGE="$2"
      shift 2
      ;;
    --python-devel-package)
      PYTHON_DEVEL_PACKAGE="$2"
      shift 2
      ;;
    --python-pip-package)
      PYTHON_PIP_PACKAGE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PYTHON_PACKAGE" ]]; then
  PYTHON_PACKAGE="$PYTHON_BIN"
fi

if [[ -z "$PYTHON_DEVEL_PACKAGE" ]]; then
  PYTHON_DEVEL_PACKAGE="${PYTHON_PACKAGE}-devel"
fi

if [[ -z "$PYTHON_PIP_PACKAGE" ]]; then
  case "$PYTHON_PACKAGE" in
    python3|python3.*)
      PYTHON_PIP_PACKAGE="python3-pip"
      ;;
    *)
      PYTHON_PIP_PACKAGE="${PYTHON_PACKAGE}-pip"
      ;;
  esac
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd git
need_cmd rpmbuild
need_cmd sed
need_cmd grep
need_cmd tar
need_cmd "$PYTHON_BIN"

mkdir -p "$SOURCES_DIR" "$SPECS_DIR" "$RPMS_DIR" "$SRPMS_DIR" "$OUT_DIR"

if [[ -z "$VERSION" ]]; then
  TMP_CLONE="$(mktemp -d)"
  trap 'rm -rf "$TMP_CLONE"' EXIT

  git clone --depth 1 --branch "$REF" https://github.com/setiastro/setiastrosuitepro.git "$TMP_CLONE" 2>/dev/null || {
    git clone --depth 1 https://github.com/setiastro/setiastrosuitepro.git "$TMP_CLONE"
    git -C "$TMP_CLONE" checkout "$REF"
  }

  VERSION="$(grep -E '^version\s*=\s*"' "$TMP_CLONE/pyproject.toml" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
  if [[ -z "$VERSION" ]]; then
    echo "Unable to determine version from upstream pyproject.toml" >&2
    exit 1
  fi
fi

SOURCE_ARCHIVE="setiastrosuitepro-${VERSION}.tar.gz"
"${ROOT_DIR}/scripts/fetch_upstream_source.sh" \
  --version "$VERSION" \
  --ref "$REF" \
  --out "${SOURCES_DIR}/${SOURCE_ARCHIVE}"

cp "${ROOT_DIR}/packaging/setiastrosuitepro.desktop" "${SOURCES_DIR}/"
cp "${ROOT_DIR}/packaging/setiastrosuitepro-launcher.sh" "${SOURCES_DIR}/"

SPEC_TEMPLATE="${ROOT_DIR}/packaging/setiastrosuitepro.spec.in"
SPEC_FILE="${SPECS_DIR}/setiastrosuitepro.spec"

sed \
  -e "s/@VERSION@/${VERSION}/g" \
  -e "s/@RELEASE@/${RELEASE}/g" \
  -e "s/@PYTHON_BIN@/${PYTHON_BIN}/g" \
  -e "s/@PYTHON_PACKAGE@/${PYTHON_PACKAGE}/g" \
  -e "s/@PYTHON_DEVEL_PACKAGE@/${PYTHON_DEVEL_PACKAGE}/g" \
  -e "s/@PYTHON_PIP_PACKAGE@/${PYTHON_PIP_PACKAGE}/g" \
  "$SPEC_TEMPLATE" > "$SPEC_FILE"

rpmbuild -ba \
  --define "_topdir ${TOPDIR}" \
  "$SPEC_FILE"

cp -a "${RPMS_DIR}" "${OUT_DIR}/"
cp -a "${SRPMS_DIR}" "${OUT_DIR}/"

echo "Build complete. RPMs copied to ${OUT_DIR}/"
