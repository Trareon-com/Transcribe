#!/usr/bin/env bash
# Build Trareon Transcribe as a Linux AppImage.
# Requires: flutter, cargo, appimagetool (https://github.com/AppImage/AppImageKit)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)}"
APP_NAME="transcribe"
BUILD_DIR="build/linux/x64/release/bundle"
DIST_DIR="dist"
APPIMAGE_DIR="build/linux/AppImage"
APPIMAGE_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-linux.AppImage"

echo "==> Building rust_core (release)"
(cd rust_core && cargo build --release --lib)

echo "==> Building Flutter Linux release"
flutter build linux --release

if [ ! -d "$BUILD_DIR" ]; then
  echo "error: $BUILD_DIR not found after build" >&2
  exit 1
fi

# Bundle models next to the executable
MODELS_DEST="$BUILD_DIR/models"
mkdir -p "$MODELS_DEST"
if [ -f "models/ggml-base.bin" ]; then
  cp "models/ggml-base.bin" "$MODELS_DEST/"
  echo "    -> base bundled"
else
  echo "    ** models/ggml-base.bin not found -- skipping"
fi

echo "==> Preparing AppImage structure"
rm -rf "$APPIMAGE_DIR"
mkdir -p "$APPIMAGE_DIR/usr/bin" "$APPIMAGE_DIR/usr/lib" "$APPIMAGE_DIR/usr/share/applications" "$APPIMAGE_DIR/usr/share/icons/hicolor/256x256/apps"

cp -a "$BUILD_DIR"/* "$APPIMAGE_DIR/usr/bin/"
cp "assets/logo.png" "$APPIMAGE_DIR/usr/share/icons/hicolor/256x256/apps/transcribe.png" 2>/dev/null || true

cat > "$APPIMAGE_DIR/usr/share/applications/transcribe.desktop" <<'EOF'
[Desktop Entry]
Name=Trareon Transcribe
Exec=transcribe
Icon=transcribe
Type=Application
Categories=AudioVideo;Audio;Utility;
Comment=100% offline meeting transcription
EOF

ln -s "usr/share/applications/transcribe.desktop" "$APPIMAGE_DIR/transcribe.desktop"
ln -s "usr/share/icons/hicolor/256x256/apps/transcribe.png" "$APPIMAGE_DIR/transcribe.png" 2>/dev/null || true

mkdir -p "$DIST_DIR"
if command -v appimagetool &>/dev/null; then
  echo "==> Creating AppImage"
  ARCH=x86_64 appimagetool "$APPIMAGE_DIR" "$APPIMAGE_PATH"
  shasum -a 256 "$APPIMAGE_PATH" > "$APPIMAGE_PATH.sha256"
  echo "Done: $APPIMAGE_PATH"
else
  echo "** appimagetool not found; falling back to .tar.gz"
  TAR_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-linux.tar.gz"
  tar -czf "$TAR_PATH" -C "$BUILD_DIR" .
  shasum -a 256 "$TAR_PATH" > "$TAR_PATH.sha256"
  echo "Done: $TAR_PATH"
fi
