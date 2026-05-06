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

if [[ -z "$EXPECTED_VERSION" ]]; then
  echo "VERSION must not be empty" >&2
  exit 1
fi

cd "$ROOT_DIR"

export HOME="$TMP_HOME"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

mkdir -p "$TMP_HOME" "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

echo "Running tests..."
swift test

echo "Building app bundle..."
"$ROOT_DIR/Scripts/build-app.sh"

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

codesign --verify --deep --strict "$ROOT_DIR/dist/InDrop.app"

echo "Release verification passed for InDrop $ACTUAL_VERSION ($ACTUAL_BUILD_NUMBER)."
