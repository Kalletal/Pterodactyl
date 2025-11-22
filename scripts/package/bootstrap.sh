#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

ensure_spksrc
sync_overlay

echo "[INFO] spksrc workspace ready at $SPKSRC_DIR"
