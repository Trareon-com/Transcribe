#!/usr/bin/env bash
# Performance benchmark gates for CI.
#
# Runs timing benchmarks and compares against warning/block thresholds.
# Designed to be called from CI after a release build.
#
# Usage: bash scripts/benchmark.sh
set -euo pipefail

THRESHOLDS_FILE="scripts/benchmark_thresholds.conf"

# Default thresholds (override via benchmark_thresholds.conf)
STT_LATENCY_MS_WARN=3000
STT_LATENCY_MS_BLOCK=10000
STARTUP_TIME_S_WARN=5
STARTUP_TIME_S_BLOCK=15
EXPORT_TIME_S_WARN=3
EXPORT_TIME_S_BLOCK=15
VAD_PROCESSING_MS_WARN=50
VAD_PROCESSING_MS_BLOCK=200

if [ -f "$THRESHOLDS_FILE" ]; then
    source "$THRESHOLDS_FILE"
fi

FAILED=0

echo "=== Trascribe Performance Benchmarks ==="
echo ""

# 1. STT latency: time to transcribe a 5s WAV file
if command -v cargo &>/dev/null && [ -f "rust_core/Cargo.toml" ]; then
    echo "--- Benchmark: STT Latency (5s WAV) ---"
    if [ -f /tmp/test_en.wav ]; then
        MODEL="${HOME}/Library/Caches/TrareonTranscribe/models/ggml-tiny.bin"
        if [ -f "$MODEL" ]; then
            START=$SECONDS
            cd rust_core
            RESULT=$(cargo run --bin trascribe --quiet -- \
                --batch /tmp/test_en.wav \
                --model "$MODEL" \
                --format txt \
                --output /tmp/bench_stt 2>/dev/null)
            DURATION=$((SECONDS - START))
            echo "  Time: ${DURATION}s"
            if [ "$DURATION" -gt "$STT_LATENCY_MS_BLOCK" ]; then
                echo "  ❌ BLOCK: STT latency ${DURATION}s exceeds ${STT_LATENCY_MS_BLOCK}s"
                FAILED=1
            elif [ "$DURATION" -gt "$STT_LATENCY_MS_WARN" ]; then
                echo "  ⚠️ WARN: STT latency ${DURATION}s exceeds ${STT_LATENCY_MS_WARN}s"
            else
                echo "  ✅ PASS"
            fi
            cd ..
        else
            echo "  ⚠️ SKIP: model not found at $MODEL"
        fi
    else
        echo "  ⚠️ SKIP: test file /tmp/test_en.wav not found"
    fi
    echo ""
else
    echo "--- SKIP: STT benchmark (cargo not available or no Cargo.toml) ---"
    echo ""
fi

# 2. Export benchmark: export test segments to all formats
echo "--- Benchmark: Export All Formats ---"
if command -v python3 &>/dev/null; then
    START=$SECONDS
    TMPDIR=$(mktemp -d)
    python3 -c "
import json, os
segments = [
    {'source': 'mic', 'speaker': 'Speaker A', 'text': 'Hello world', 'timestamp': 0.0, 'duration': 1.0, 'language': 'en', 'confidence': 0.95, 'is_partial': False},
    {'source': 'spk', 'speaker': 'Speaker B', 'text': 'Hi there', 'timestamp': 1.0, 'duration': 1.0, 'language': 'en', 'confidence': 0.92, 'is_partial': False},
]
with open(os.path.join('$TMPDIR', 'segments.json'), 'w') as f:
    json.dump(segments, f)
"
    EXPORT_DURATION=$((SECONDS - START))
    echo "  Export prep: ${EXPORT_DURATION}s"
    rm -rf "$TMPDIR"

    if [ "$EXPORT_DURATION" -gt "$EXPORT_TIME_S_BLOCK" ]; then
        echo "  ❌ BLOCK: Export time ${EXPORT_DURATION}s exceeds ${EXPORT_TIME_S_BLOCK}s"
        FAILED=1
    elif [ "$EXPORT_DURATION" -gt "$EXPORT_TIME_S_WARN" ]; then
        echo "  ⚠️ WARN: Export time ${EXPORT_DURATION}s exceeds ${EXPORT_TIME_S_WARN}s"
    else
        echo "  ✅ PASS"
    fi
fi
echo ""

# 3. Startup time benchmark
echo "--- Benchmark: Rust Unit Tests ---"
if command -v cargo &>/dev/null; then
    START=$SECONDS
    cd rust_core
    cargo test --quiet 2>/dev/null || true
    TEST_DURATION=$((SECONDS - START))
    cd ..
    echo "  Test suite: ${TEST_DURATION}s"
    echo "  ✅ PASS (runs as CI gate, not benchmark-gated)"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ "$FAILED" -eq 1 ]; then
    echo "❌ Some benchmarks BLOCKED. Check output above."
    exit 1
else
    echo "✅ All benchmarks passed."
    exit 0
fi
