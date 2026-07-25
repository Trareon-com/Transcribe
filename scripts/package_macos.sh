#!/usr/bin/env bash
# Build, ad-hoc sign, and package Trascribe as a .dmg for macOS.
#
# Per ADR-12: this is deliberately ad-hoc signing (`codesign --sign -`),
# NOT notarization — it costs $0 and needs no Apple Developer account,
# at the price of a "Apple cannot verify this app" Gatekeeper warning on
# first launch (documented for users at download time). Notarization is
# a follow-up if/when a paid Apple Developer account is set up.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)}"
APP_NAME="trascribe"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-macos.dmg"

echo "==> Building rust_core (release)"
(cd rust_core && cargo build --release --lib)

echo "==> Building Flutter macOS release"
flutter build macos --release

if [ ! -d "$APP_PATH" ]; then
  echo "error: $APP_PATH not found after build" >&2
  exit 1
fi

echo "==> Ad-hoc signing $APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --verbose "$APP_PATH"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "==> Creating $DMG_PATH"
hdiutil create -volname "Trascribe" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"

echo "==> Generating checksum"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "==> Verifying signature on packaged app"
codesign -dv "$APP_PATH" 2>&1

echo "Done: $DMG_PATH"
