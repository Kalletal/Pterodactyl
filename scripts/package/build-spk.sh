#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

sync_overlay

VERSION="$(pterodactyl_version)"
ARCH_TARGET="spk-pterodactyl-${ARCH}-${TCVERSION}"
echo "[INFO] Building Pterodactyl ${VERSION} for DSM ${TCVERSION} (${ARCH})"
run_spksrc make ARCH="${ARCH}" TCVERSION="${TCVERSION}" "${ARCH_TARGET}"
collect_artifacts "pterodactyl_panel_${ARCH}-${TCVERSION}"

echo "[INFO] Build artifacts available in ${DIST_DIR}"
