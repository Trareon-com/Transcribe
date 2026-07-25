#!/usr/bin/env bash
# Trascribe GUI Smoke Test — automated via Hermes computer_use
#
# This script is designed to be invoked by Hermes agent using the computer_use
# tool. It does NOT run autonomously — each step requires the agent to:
#   1. Capture the desktop/screen
#   2. Find elements by index or coordinate
#   3. Click/type/scroll
#   4. Verify the result
#
# Usage (via Hermes):
#   hermes chat -q "Jalankan GUI smoke test untuk Trascribe sesuai scripts/gui_smoke_test.sh"
#
set -euo pipefail

echo "=== Trascribe GUI Smoke Test ==="
echo "Date: $(date)"
echo ""

# Configuration
APP_NAME="Trascribe"
BUILD_DIR="build/macos/Build/Products/Debug"

# Step 1: Verify app is built
echo "Step 1: Verifying app build..."
if [ -d "$BUILD_DIR/$APP_NAME.app" ]; then
  echo "  ✅ App bundle found at $BUILD_DIR/$APP_NAME.app"
else
  echo "  ⚠️  App not built. Building..."
  cd "$(dirname "$0")/.."
  flutter build macos --debug 2>/dev/null || {
    echo "  ❌ Build failed. Run 'flutter build macos --debug' manually."
    exit 1
  }
fi

# Step 2: Verify models directory has tiny model
echo "Step 2: Verifying model files..."
if [ -f "models/ggml-tiny.bin" ]; then
  echo "  ✅ tiny model found (75 MB)"
else
  echo "  ⚠️  tiny model not found. Download:"
  echo "     cd rust_core && cargo run --bin download_model -- tiny"
fi

# Step 3: Launch the app
echo ""
echo "Step 3: Launching Trascribe..."
open "$BUILD_DIR/$APP_NAME.app"
echo "  ✅ App launched. Use computer_use to interact."

# Display test checklist for Hermes agent
echo ""
echo "=== GUI Test Checklist ==="
echo "The following must be verified via computer_use:"
echo ""
echo "TC1: App Launches"
echo "  - Capture window → verify 'Trareon Transcribe' title visible"
echo ""
echo "TC2: Wizard Complete Flow (if first run)"
echo "  - Step 1: Verify spec detection shows '1. Deteksi Spesifikasi'"
echo "  - Step 2: Click 'Lanjut' → '2. Pilih Model' visible"
echo "  - Step 3: Click 'Lanjut' → '3. Setup Audio' visible"
echo "  - Step 4: Click 'Lanjut' → '4. Unduh Model' visible (skip download)"
echo "  - Step 5: Click 'Lanjut' → '5. Tone Test' visible"
echo "  - Click 'Selesai' → Main screen visible"
echo ""
echo "TC3: Main Screen"
echo "  - Verify mode selector: Webinar, Rapat Online, Rapat Offline"
echo "  - Verify MIC indicator present"
echo "  - Verify SPK indicator present"
echo "  - Verify 'Mulai' button present"
echo "  - Verify 'Export' button present"
echo "  - Verify nav icons: Library, Pengaturan, Shortcuts"
echo ""
echo "TC4: Settings Navigation"
echo "  - Click 'Pengaturan' → verify 'Pengaturan' title"
echo "  - Verify: Tema, Model default, Mode default, Bahasa, VAD, Echo-dedupe"
echo "  - Navigate back to main screen"
echo ""
echo "TC5: Library Screen"
echo "  - Click 'Library' → verify 'Library' title"
echo "  - Verify tabs: Sesi, Upload File"
echo "  - Verify search field present"
echo "  - Navigate back to main screen"
echo ""
echo "=== Smoke Test Complete ==="
