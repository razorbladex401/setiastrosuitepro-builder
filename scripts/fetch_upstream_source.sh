#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: fetch_upstream_source.sh --version VERSION --ref REF --out OUTFILE

Creates a source tarball named by the caller with a deterministic top-level
folder setiastrosuitepro-VERSION.

Arguments:
  --version   RPM/package version to embed in the tarball folder name
  --ref       Upstream git ref (tag, branch, or commit)
  --out       Output tarball path (usually rpmbuild/SOURCES/*.tar.gz)
EOF
}

VERSION=""
REF=""
OUTFILE=""

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
    --out)
      OUTFILE="$2"
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

if [[ -z "$VERSION" || -z "$REF" || -z "$OUTFILE" ]]; then
  usage >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

SRC_DIR="$WORKDIR/src"
git clone --depth 1 --branch "$REF" https://github.com/setiastro/setiastrosuitepro.git "$SRC_DIR" 2>/dev/null || {
  git clone --depth 1 https://github.com/setiastro/setiastrosuitepro.git "$SRC_DIR"
  git -C "$SRC_DIR" checkout "$REF"
}

PREFIX="setiastrosuitepro-${VERSION}"
mkdir -p "$(dirname "$OUTFILE")"

tar \
  --exclude-vcs \
  --exclude='.github' \
  --transform "s#^.#${PREFIX}#" \
  -czf "$OUTFILE" \
  -C "$SRC_DIR" .

echo "Created $OUTFILE from ref $REF"
