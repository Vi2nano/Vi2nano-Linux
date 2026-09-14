#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root on an Arch Linux build system."
  exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso is required. Install the archiso package first."
  exit 1
fi

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUTPUT_DIR=${1:-"$ROOT_DIR/out"}
PROFILE_DIR=$(mktemp -d)
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$PROFILE_DIR" "$WORK_DIR"' EXIT

cp -a /usr/share/archiso/configs/releng/. "$PROFILE_DIR/"
mkdir -p "$PROFILE_DIR/airootfs/root/vi2nano"
cp -a "$ROOT_DIR/etc" "$ROOT_DIR/sddm" "$ROOT_DIR/packages.x86_64" "$PROFILE_DIR/airootfs/root/vi2nano/"
install -m755 "$ROOT_DIR/install.sh" "$PROFILE_DIR/airootfs/root/vi2nano/install.sh"
install -m644 "$ROOT_DIR/README.md" "$PROFILE_DIR/airootfs/root/vi2nano/README.md"

mkdir -p "$OUTPUT_DIR"
mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" "$PROFILE_DIR"

echo "ISO written to $OUTPUT_DIR"