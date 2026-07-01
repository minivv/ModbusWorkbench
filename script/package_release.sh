#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ModbusWorkbench"
BUNDLE_ID="io.github.minivv.ModbusWorkbench"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  if git -C "$ROOT_DIR" describe --tags --abbrev=0 >/dev/null 2>&1; then
    VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 | sed 's/^v//')"
  else
    VERSION="0.1.0"
  fi
fi

BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
UNIVERSAL_BINARY="${UNIVERSAL_BINARY:-1}"

BUILD_ARGS=(-c release)
if [[ "$UNIVERSAL_BINARY" == "1" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
  ARCH_LABEL="${ARCH_LABEL:-macos-universal}"
else
  ARCH_LABEL="${ARCH_LABEL:-macos-$(uname -m)}"
fi

DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-$ARCH_LABEL.zip"
SHA_PATH="$ZIP_PATH.sha256"

ICON_PLIST_ENTRY=""
if [[ -f "$ICON_SOURCE" ]]; then
  ICON_PLIST_ENTRY="  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>"
fi

cd "$ROOT_DIR"

swift build "${BUILD_ARGS[@]}"
BUILD_BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$RELEASE_DIR"
rm -f "$RELEASE_DIR/$APP_NAME-$VERSION-"*.zip "$RELEASE_DIR/$APP_NAME-$VERSION-"*.zip.sha256
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
file "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
$ICON_PLIST_ENTRY
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 minivv</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -f "$ICON_SOURCE" ]]; then
  mkdir -p "$APP_RESOURCES"
  cp "$ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
fi

plutil -lint "$INFO_PLIST"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  codesign --force --timestamp --options runtime --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
  codesign --verify --strict --verbose=2 "$APP_BUNDLE"
else
  echo "CODESIGN_IDENTITY is not set; creating an unsigned app bundle." >&2
fi

make_zip() {
  local output="$1"
  rm -f "$output" "$output.sha256"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$output"
}

if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
  if [[ -z "$CODESIGN_IDENTITY" ]]; then
    echo "NOTARYTOOL_PROFILE requires CODESIGN_IDENTITY." >&2
    exit 2
  fi

  NOTARY_ZIP="$RELEASE_DIR/$APP_NAME-$VERSION-notary-upload.zip"
  make_zip "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$NOTARY_ZIP"
fi

make_zip "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" >"$SHA_PATH"

echo "Created:"
echo "  $ZIP_PATH"
echo "  $SHA_PATH"
