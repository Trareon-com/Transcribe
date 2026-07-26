#!/usr/bin/env bash
# Build a Universal Binary (arm64 + x86_64), ad-hoc sign, and package
# Trareon Transcribe as a .dmg for macOS.
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

# ── Add cross-compilation targets if missing ──────────────────────────
echo "==> Ensuring cross-compilation targets"
rustup target add aarch64-apple-darwin x86_64-apple-darwin

# ── Build Rust library for both architectures ─────────────────────────
echo "==> Building rust_core for aarch64-apple-darwin"
(cd rust_core && cargo build --release --target aarch64-apple-darwin --lib)

echo "==> Building rust_core for x86_64-apple-darwin"
(cd rust_core && cargo build --release --target x86_64-apple-darwin --lib)

echo "==> Creating universal librust_core.dylib"
mkdir -p rust_core/target/universal
lipo -create \
  rust_core/target/aarch64-apple-darwin/release/librust_core.dylib \
  rust_core/target/x86_64-apple-darwin/release/librust_core.dylib \
  -output rust_core/target/universal/librust_core.dylib

# ── Build Flutter macOS release ───────────────────────────────────────
# The Xcode build phase builds Rust for native arch and copies it into
# the bundle. We'll overwrite it with the universal dylib afterwards.
echo "==> Building Flutter macOS release"
flutter build macos --release

if [ ! -d "$APP_PATH" ]; then
  echo "error: $APP_PATH not found after build" >&2
  exit 1
fi

# ── Replace native-arch dylib with universal dylib ────────────────────
FRAMEWORKS="$APP_PATH/Contents/Frameworks"
echo "==> Copying universal librust_core.dylib into bundle"
cp rust_core/target/universal/librust_core.dylib "$FRAMEWORKS/"

# ── Bundle models ──────────────────────────────────────────────
# App Sandbox blocks reading arbitrary paths outside the bundle/container,
# so bundled models must physically live inside Contents/Resources —
# lib/state/models.dart's modelPathForId() looks there first.
RESOURCES="$APP_PATH/Contents/Resources"
echo "==> Bundling models into $RESOURCES/models"
mkdir -p "$RESOURCES/models"
cp models/ggml-base.bin "$RESOURCES/models/"
cp models/ggml-large-v3-turbo-q5.bin "$RESOURCES/models/"
echo "    → base (142 MB) bundled"
echo "    → large-v3-turbo-q5 (548 MB) bundled"

# ── Ad-hoc signing ────────────────────────────────────────────────────
echo "==> Ad-hoc signing $APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --verbose "$APP_PATH"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "==> Creating $DMG_PATH"
hdiutil create -volname "TrareonTranscribe" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"

echo "==> Generating checksum"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "==> Verifying signature on packaged app"
codesign -dv "$APP_PATH" 2>&1

echo "Done: $DMG_PATH"
