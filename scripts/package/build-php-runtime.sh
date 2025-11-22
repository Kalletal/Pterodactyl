#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

sync_overlay

echo "[INFO] Building php83 runtime for DSM ${TCVERSION} (${ARCH})"
run_spksrc make ARCH="${ARCH}" TCVERSION="${TCVERSION}" spk/php83
collect_artifacts php83 || true
