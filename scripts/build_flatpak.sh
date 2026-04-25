#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/work/flatpak"
BUILD_DIR="${WORK_DIR}/build-dir"
REPO_DIR="${WORK_DIR}/repo"
OUT_DIR="${ROOT_DIR}/out/flatpak"
MANIFEST_TEMPLATE="${ROOT_DIR}/packaging/com.setiastro.SetiAstroSuitePro.yaml.in"
MANIFEST_FILE="${WORK_DIR}/com.setiastro.SetiAstroSuitePro.yaml"
DESKTOP_FILE="${ROOT_DIR}/packaging/setiastrosuitepro.desktop"
LAUNCHER_FILE="${ROOT_DIR}/packaging/setiastrosuitepro-flatpak-launcher.sh"
APP_ID="com.setiastro.SetiAstroSuitePro"

usage() {
  cat <<'EOF'
Usage: build_flatpak.sh [--version VERSION] [--ref REF] [--release RELEASE] [--branch BRANCH]

Builds a Flatpak bundle for Seti Astro Suite Pro.

Options:
  --version   Package version (default: from upstream pyproject at --ref)
  --ref       Upstream git ref (default: main)
  --release   Build release string to append to the bundle filename (default: 1)
  --branch    Flatpak branch name (default: stable)
EOF
}

VERSION=""
REF="main"
RELEASE="1"
BRANCH="stable"

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
    --branch)
      BRANCH="$2"
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

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd git
need_cmd sed
need_cmd grep
need_cmd flatpak
need_cmd flatpak-builder

mkdir -p "$WORK_DIR" "$OUT_DIR"
rm -rf "$BUILD_DIR" "$REPO_DIR"

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

SOURCE_ARCHIVE="${WORK_DIR}/setiastrosuitepro-${VERSION}.tar.gz"
"${ROOT_DIR}/scripts/fetch_upstream_source.sh" \
  --version "$VERSION" \
  --ref "$REF" \
  --out "$SOURCE_ARCHIVE"

sed \
  -e "s|@SOURCE_ARCHIVE_PATH@|${SOURCE_ARCHIVE}|g" \
  -e "s|@DESKTOP_PATH@|${DESKTOP_FILE}|g" \
  -e "s|@LAUNCHER_PATH@|${LAUNCHER_FILE}|g" \
  "$MANIFEST_TEMPLATE" > "$MANIFEST_FILE"

# In CI and other unprivileged environments, system Flatpak operations are not allowed.
FLATPAK_INSTALL_ARGS=()
if [[ "$(id -u)" -ne 0 ]]; then
  FLATPAK_INSTALL_ARGS+=(--user)
fi

flatpak "${FLATPAK_INSTALL_ARGS[@]}" remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak-builder \
  "${FLATPAK_INSTALL_ARGS[@]}" \
  --force-clean \
  --install-deps-from=flathub \
  --default-branch="$BRANCH" \
  --repo="$REPO_DIR" \
  "$BUILD_DIR" \
  "$MANIFEST_FILE"

BUNDLE_PATH="${OUT_DIR}/setiastrosuitepro-${VERSION}-${RELEASE}.flatpak"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_PATH" "$APP_ID" "$BRANCH"

echo "Build complete. Flatpak bundle copied to ${BUNDLE_PATH}"