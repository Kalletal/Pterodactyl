#!/usr/bin/env bash
set -euo pipefail

ROOT="${VERIFY_ROOT:-/}"
USER="${VERIFY_USER:-root}"
GROUP="${VERIFY_GROUP:-root}"

TARGET="$ROOT/var/packages/pterodactyl"
VAR_DIR="$TARGET/var"
APP_DIR="$TARGET/target"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

[ -d "$VAR_DIR" ] || fail "Missing var directory at $VAR_DIR"
[ -d "$APP_DIR" ] || fail "Missing target directory at $APP_DIR"

ENV_FILE="$VAR_DIR/panel.env"
[ -f "$ENV_FILE" ] || fail "Missing env file at $ENV_FILE"

if [ "$(stat -c %U "$ENV_FILE")" != "$USER" ]; then
  fail "Unexpected owner for $ENV_FILE"
fi

if [ "$(stat -c %a "$ENV_FILE")" != "600" ]; then
  fail "panel.env must be chmod 600"
fi

DATA_DIR="$VAR_DIR/data"
for dir in panel wings database redis logs; do
  path="$DATA_DIR/$dir"
  [ -d "$path" ] || fail "Missing data directory $path"
  owner="$(stat -c %U "$path")"
  group="$(stat -c %G "$path")"
  if [ "$owner" != "$USER" ] || [ "$group" != "$GROUP" ]; then
    fail "Unexpected ownership for $path (expected $USER:$GROUP, got $owner:$group)"
  fi
  perms="$(stat -c %a "$path")"
  case "$dir" in
    logs)
      [ "$perms" = "750" ] || fail "logs dir must be 750"
      ;;
    *)
      [ "$perms" = "770" ] || fail "${dir} dir must be 770"
      ;;
  esac
 done

if [ "${VERIFY_COMPOSER:-0}" = "1" ]; then
  if ! command -v composer >/dev/null 2>&1; then
    fail "composer command not found while VERIFY_COMPOSER=1"
  fi
  composer_info="$(composer --version 2>/dev/null || true)"
  if ! [[ "$composer_info" =~ ^Composer\ version\ 2\. ]]; then
    fail "Composer v2 required (verify detected: ${composer_info:-unknown})"
  fi
fi

echo "[PASS] Permission layout verified"
