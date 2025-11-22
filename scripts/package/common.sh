#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
SPKSRC_DIR="$BUILD_DIR/spksrc"
DIST_DIR="$ROOT_DIR/dist"
LOG_DIR="$ROOT_DIR/build/logs"
TOOLS_BIN="$ROOT_DIR/.tools/bin"
PATH="$TOOLS_BIN:$PATH"
export PATH

ARCH="${ARCH:-geminilake}"
TCVERSION="${TCVERSION:-7.2}"
SYNO_SDK_IMAGE="${SYNO_SDK_IMAGE:-synologytoolkit/dsm7.2:7.2-64570}"
SPKSRC_GIT_REF="${SPKSRC_GIT_REF:-master}"

mkdir -p "$BUILD_DIR" "$DIST_DIR" "$LOG_DIR"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Missing required command: $1" >&2
    exit 1
  fi
}

pterodactyl_version() {
  awk -F'=' '/^SPK_VERS/{gsub(/[ \t]/, "", $2); print $2; exit}' "$ROOT_DIR/spk/pterodactyl/Makefile"
}

ensure_spksrc() {
  if [ -d "$SPKSRC_DIR/.git" ]; then
    return
  fi
  require_cmd git
  echo "[INFO] Cloning spksrc ($SPKSRC_GIT_REF) into $SPKSRC_DIR"
  git clone --depth 1 --branch "$SPKSRC_GIT_REF" https://github.com/SynoCommunity/spksrc.git "$SPKSRC_DIR" >/dev/null
}

sync_overlay() {
  ensure_spksrc
  require_cmd rsync
  local rel src dest
  for rel in cross native spk; do
    src="$ROOT_DIR/$rel"
    [ -d "$src" ] || continue
    while IFS= read -r -d '' dir; do
      dest="$SPKSRC_DIR/${dir#"$ROOT_DIR/"}"
      mkdir -p "$dest"
      rsync -a --delete "$dir/" "$dest/"
    done < <(find "$src" -mindepth 1 -maxdepth 1 -type d -print0)
  done
}

run_spksrc() {
  local quoted
  local use_docker="${SPKSRC_USE_DOCKER:-1}"
  if [ "$use_docker" = "1" ] && command -v docker >/dev/null 2>&1; then
    require_cmd docker
    printf -v quoted '%q ' "$@"
    docker run --rm \
      -e ARCH="$ARCH" \
      -e TCVERSION="$TCVERSION" \
      -v "$SPKSRC_DIR:/spksrc" \
      -v "$DIST_DIR:/dist" \
      -v "$LOG_DIR:/log" \
      "$SYNO_SDK_IMAGE" \
      bash -lc "cd /spksrc && $quoted"
  else
    (cd "$SPKSRC_DIR" && "$@")
  fi
}

collect_artifacts() {
  local name="$1"
  local -a files=()
  if [ -d "$SPKSRC_DIR/packages" ]; then
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find "$SPKSRC_DIR/packages" -maxdepth 1 -type f \( -name "${name}_*.spk" -o -name "${name}-*.spk" \) -print0)
  fi
  if [ ${#files[@]} -eq 0 ]; then
    echo "[WARN] No artifacts found for $name"
    return 1
  fi
  for file in "${files[@]}"; do
    cp "$file" "$DIST_DIR/"
    (cd "$DIST_DIR" && sha256sum "$(basename "$file")" > "$(basename "$file").sha256")
  done
}
