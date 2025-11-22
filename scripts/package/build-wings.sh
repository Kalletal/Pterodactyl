#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

sync_overlay

echo "[INFO] Building wings cross package"
run_spksrc make ARCH="${ARCH}" TCVERSION="${TCVERSION}" cross/wings
