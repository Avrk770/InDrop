#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
APP_PLIST="$ROOT_DIR/dist/InDrop.app/Contents/Info.plist"
EXPECTED_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
EXPECTED_BUILD_NUMBER="${BUILD_NUMBER:-1}"
TMP_HOME="$ROOT_DIR/.tmp-home"
MODULE_CACHE_DIR="$ROOT_DIR/.build/module-cache"
CLANG_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"

run_step() {
  local name="$1"
  shift
  local log_file
  log_file="$(mktemp)"

  echo "$name..."
  if "$@" >"$log_file" 2>&1; then
    cat "$log_file"
    rm -f "$log_file"
    return 0
  fi

  local exit_code=$?
  cat "$log_file" >&2

  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    local details
    details="$(tail -n 20 "$log_file" | tr '\n' ' ' | sed 's/%/%25/g; s/\r/%0D/g; s/:/%3A/g')"
    echo "::error title=$name failed::$details" >&2
  fi

  rm -f "$log_file"
  return "$exit_code"
}

if [[ -z "$EXPECTED_VERSION" ]]; then
  echo "VERSION must not be empty" >&2
  exit 1
fi

cd "$ROOT_DIR"

export HOME="$TMP_HOME"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

mkdir -p "$TMP_HOME" "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

run_step "Running tests" swift test

run_step "Building app bundle" "$ROOT_DIR/Scripts/build-app.sh"

echo "Checking bundle metadata..."
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c Print:CFBundleShortVersionString "$APP_PLIST")"
ACTUAL_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c Print:CFBundleVersion "$APP_PLIST")"

if [[ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "Expected CFBundleShortVersionString $EXPECTED_VERSION, got $ACTUAL_VERSION" >&2
  exit 1
fi

if [[ "$ACTUAL_BUILD_NUMBER" != "$EXPECTED_BUILD_NUMBER" ]]; then
  echo "Expected CFBundleVersion $EXPECTED_BUILD_NUMBER, got $ACTUAL_BUILD_NUMBER" >&2
  exit 1
fi

run_step "Verifying code signature" codesign --verify --deep --strict "$ROOT_DIR/dist/InDrop.app"

echo "Release verification passed for InDrop $ACTUAL_VERSION ($ACTUAL_BUILD_NUMBER)."
