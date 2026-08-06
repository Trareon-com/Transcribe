#!/usr/bin/env bash
set -euo pipefail
# Usage: ./scripts/package_linux.sh [version]
# Builds the Flutter Linux release bundle with bundled ASR models, then
# archives it as dist/transcribe-<version>-linux.tar.gz + .sha256.

VERSION="${1:-1.0.0}"
cd "$(dirname "$0")/.."
mkdir -p dist

echo "==> flutter build linux --release"
flutter build linux --release

BUNDLE="build/linux/x64/release/bundle"
mkdir -p "$BUNDLE/models"

echo "==> Bundling models into $BUNDLE/models"
for M in ggml-base.bin ggml-large-v3-turbo-q5_0.bin; do
  if [ -f "models/$M" ]; then
    cp "models/$M" "$BUNDLE/models/"
    echo "    ✓ models/$M"
  else
    echo "    ⚠️ models/$M not found — skipping"
  fi
done

echo "==> Packaging tar.gz"
tar -C "$BUNDLE" -czf "dist/transcribe-${VERSION}-linux.tar.gz" .
sha256sum "dist/transcribe-${VERSION}-linux.tar.gz" > "dist/transcribe-${VERSION}-linux.tar.gz.sha256"

echo "==> dist/transcribe-${VERSION}-linux.tar.gz ($(du -sh "dist/transcribe-${VERSION}-linux.tar.gz" | cut -f1))"
