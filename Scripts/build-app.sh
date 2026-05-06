#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="InDrop"
VERSION_FILE="$ROOT_DIR/VERSION"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
TMP_HOME="$ROOT_DIR/.tmp-home"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
CLANG_CACHE_DIR="$BUILD_DIR/clang-module-cache"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICON_SOURCE="$ROOT_DIR/Sources/WhatsAppToInDesignConverter/Resources/AppIconSource.png"
ICON_SOURCE_ICNS="$ROOT_DIR/Sources/WhatsAppToInDesignConverter/Resources/AppIcon.icns"
ICON_ICNS="$RESOURCES_DIR/AppIcon.icns"

if [[ -z "$APP_VERSION" ]]; then
  echo "VERSION must not be empty" >&2
  exit 1
fi

export HOME="$TMP_HOME"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$TMP_HOME" "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"

ICON_RENDER_SOURCE="$ICON_SOURCE"
if [[ -f "$ICON_SOURCE_ICNS" ]]; then
  ICON_RENDER_SOURCE="$ICON_SOURCE_ICNS"
fi

swift "$ROOT_DIR/Scripts/render-app-icon.swift" "$ICON_RENDER_SOURCE" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$RESOURCES_DIR/" \;

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>InDrop</string>
    <key>CFBundleExecutable</key>
    <string>InDrop</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.codex.indrop</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>InDrop</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Created $APP_DIR"
