#!/usr/bin/env bash
# Run Trareon Transcribe on Linux
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_DIR="$APP_DIR/build/linux/x64/release/bundle/usr/local"

export LD_LIBRARY_PATH="$BUNDLE_DIR/lib:${LD_LIBRARY_PATH:-}"

# Path ke model Whisper — download dulu kalau belum ada
MODEL_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/whisper"
MODEL_FILE="$MODEL_DIR/ggml-tiny.bin"

if [ ! -f "$MODEL_FILE" ]; then
  echo "📥 Model Whisper belum ada. Download tiny (~75MB)..."
  mkdir -p "$MODEL_DIR"
  curl -L -o "$MODEL_FILE" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
  echo "✅ Model siap!"
fi

echo "🎤 Menjalankan Trareon Transcribe..."
exec "$BUNDLE_DIR/trascribe"
