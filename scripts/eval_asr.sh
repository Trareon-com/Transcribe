#!/bin/bash
# Evaluasi 3 model ASR pada audio Indonesia
# Usage: ./eval_asr.sh /path/to/audio.wav

set -euo pipefail

AUDIO=$1
if [ -z "$AUDIO" ]; then
    echo "Usage: $0 /path/to/audio.wav"
    exit 1
fi

if [ ! -f "$AUDIO" ]; then
    echo "Error: File not found: $AUDIO"
    exit 1
fi

echo "=== Whisper large-v3-turbo (id) ==="
whisper "$AUDIO" \
    --model large-v3-turbo \
    --language id \
    --output_format txt \
    --timestamp_format none

echo ""
echo "=== Whisper medium (id) ==="
whisper "$AUDIO" \
    --model medium \
    --language id \
    --output_format txt \
    --timestamp_format none

echo ""
echo "=== Whisper small-turbo (id) ==="
whisper "$AUDIO" \
    --model small-turbo \
    --language id \
    --output_format txt \
    --timestamp_format none

echo ""
echo "Done. Results saved alongside input file."
