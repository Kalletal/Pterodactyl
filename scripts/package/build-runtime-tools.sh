#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

TOOLS_DIR="$BUILD_DIR/runtime-tools"
mkdir -p "$TOOLS_DIR"

if [ "${SKIP_RUNTIME_TOOLS_CHECK:-0}" = "1" ]; then
  echo "[WARN] SKIP_RUNTIME_TOOLS_CHECK=1; skipping host runtime tool detection"
  cat <<JSON > "$TOOLS_DIR/manifest.json"
{
  "node": "skipped",
  "pnpm": "skipped",
  "go": "skipped",
  "composer": "skipped",
  "docker": "skipped",
  "curl": "skipped",
  "tar": "skipped",
  "unzip": "skipped",
  "git": "skipped",
  "arch": "${ARCH}",
  "tcversion": "${TCVERSION}"
}
JSON
  exit 0
fi

missing=()
for tool in node pnpm go composer docker curl tar unzip git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("$tool")
  fi
done

if [ ${#missing[@]} -ne 0 ]; then
  echo "[ERROR] Missing required host tools: ${missing[*]}" >&2
  exit 1
fi

echo "[INFO] Host runtime toolchain detected"

node_ver="$(node --version 2>/dev/null | tr -d '\n')"
pnpm_ver="$(pnpm --version 2>/dev/null | tr -d '\n')"
go_ver="$(go version 2>/dev/null | tr -d '\n')"
composer_ver="$(composer --version 2>/dev/null | tr -d '\n')"
docker_ver="$(docker --version 2>/dev/null | tr -d '\n')"
curl_ver="$(curl --version 2>/dev/null | head -n 1 | tr -d '\n')"
tar_ver="$(tar --version 2>/dev/null | head -n 1 | tr -d '\n')"
unzip_ver="$(unzip -v 2>/dev/null | head -n 1 | tr -d '\n')"
git_ver="$(git --version 2>/dev/null | tr -d '\n')"

if ! [[ "$composer_ver" =~ ^Composer\ version\ 2\. ]]; then
  echo "[ERROR] Composer v2 is required (detected: ${composer_ver:-unknown})" >&2
  exit 1
fi

cat <<JSON > "$TOOLS_DIR/manifest.json"
{
  "node": "${node_ver}",
  "pnpm": "${pnpm_ver}",
  "go": "${go_ver}",
  "composer": "${composer_ver}",
  "docker": "${docker_ver}",
  "curl": "${curl_ver}",
  "tar": "${tar_ver}",
  "unzip": "${unzip_ver}",
  "git": "${git_ver}",
  "arch": "${ARCH}",
  "tcversion": "${TCVERSION}"
}
JSON

echo "[INFO] Tool manifest written to $TOOLS_DIR/manifest.json"
