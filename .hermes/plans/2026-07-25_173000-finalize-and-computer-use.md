# Finalisasi Transcribe + Setup Computer Use (Claude Code-style)

> **For agentic workers:** REQUIRED SUB-SKILL: Gunakan `subagent-driven-development` atau `executing-plans` untuk implementasi task-by-task. Steps menggunakan checkbox (`- [ ]`) syntax.

**Goal:** Menyempurnakan aplikasi Transcribe (wiring end-to-end yang tersisa) dan mengkonfigurasi computer use (cua-driver) agar Hermes bisa melakukan GUI testing otomatis layaknya Claude Code.

**Architecture:** Dua jalur paralel: (A) Finalisasi kode — menghubungkan download model progress dari Rust ke Dart, expose `read_download_progress` ke FRB, polling progress di wizard, dan fix edge case terakhir. (B) Setup computer use — memastikan cua-driver berfungsi penuh di M4 Pro MacBook, membuat Hermes agent bisa capture/click/type/scroll pada Transcribe app untuk smoke testing otomatis.

**Tech Stack:** Rust (flutter_rust_bridge v2.12), Dart (Riverpod), cua-driver v0.12.6 (49 macOS MCP tools), Hermes Agent desktop app.

---

## Global Constraints

1. **Tidak ada `Co-Authored-By: Claude` atau AI co-author dalam commit messages**
2. **Conventional commits:** `feat:`, `fix:`, `docs:`, `chore:`, `perf:`
3. **Pre-commit:** `cd rust_core && cargo test --lib && cargo fmt`
4. **Pre-commit:** `flutter analyze && flutter test`
5. **Tidak ada `unwrap()`/`expect()`/`panic!()` di library code Rust**
6. **FRB-exposed signatures harus `Result<T, TranscribeError>` eksplisit (bukan type alias)**
7. **Tidak ada `unsafe` tanpa inline justification comment**
8. **Versi pinned:** flutter_rust_bridge =2.12.0, whisper-rs 0.14, cpal 0.15

---

## Bagian A: Finalisasi Wiring Aplikasi

### Latar Belakang

Dari audit lengkap, ditemukan bahwa:
1. Rust `model.rs` sudah punya `reset_download_progress()`, `read_download_progress()`, dan `DOWNLOAD_PROGRESS` global `Mutex<Option>` — tapi semua masih `#[frb(ignore)]` karena FRB codegen belum di-regen.
2. `api.rs` belum punya wrapper untuk `read_download_progress()`.
3. `setup_wizard_screen.dart` panggil `bridge.downloadModel()` tapi tanpa progress bar — download jalan di background tanpa feedback ke user.
4. Flutter `batch_upload_model.dart` sudah punya state management untuk batch file tapi belum terhubung ke Rust `transcribe_files_batch()`.
5. Belum ada polling progress untuk download model di UI.

### Task A1: Expose `read_download_progress` ke FRB + API

**Files:**
- Modify: `rust_core/src/api.rs`
- Test: Sudah ada test `api::tests::download_unknown_model_errors` — perlu tambah test untuk progress

**Interfaces:**
- Consumes: `model.rs::read_download_progress()` → `Option<DownloadProgress>`
- Produces: `api.rs::get_download_progress()` → `Option<DownloadProgress>` (FRB-compatible)

- [ ] **Step 1: Baca `api.rs` untuk lihat pattern existing**

```bash
cd /Users/user/Projects/Trareon/Transcribe\ Transcribe
read_file rust_core/src/api.rs
```

- [ ] **Step 2: Tambah fungsi wrapper di `api.rs`**

Setelah fungsi `download_model` (line 93-109), tambah:

```rust
pub fn get_download_progress() -> Option<model::DownloadProgress> {
    crate::model::read_download_progress()
}
```

Tidak perlu `#[flutter_rust_bridge::frb(ignore)]` — ini sengaja di-expose ke Dart. `DownloadProgress` sudah `Serialize` dan FRB-compatible (hanya `u64` fields).

- [ ] **Step 3: Generate ulang FRB bindings**

```bash
cd rust_core && cargo test --lib
flutter_rust_bridge_codegen generate \
  --rust-input crate::api,crate::error,crate::audio,crate::decode,crate::export,crate::model,crate::session,crate::settings \
  --rust-root rust_core \
  --dart-output lib/src/rust \
  --dart-entrypoint-class-name RustLib
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run test untuk verifikasi**

```bash
cd rust_core && cargo test --lib
```

Expected: 103+ passed (1 test baru untuk get_download_progress)

- [ ] **Step 5: Commit**

```bash
git add rust_core/src/api.rs lib/src/rust/
git commit -m "feat(rust): expose download progress polling to Dart via FRB"
```

### Task A2: Tambah progress polling di Dart BridgeService

**Files:**
- Modify: `lib/services/bridge_service.dart`
- Create: none
- Test: `test/bridge_service_test.dart` (file baru)

**Interfaces:**
- Consumes: `RustBridge` abstract class perlu method baru
- Produces: `RustBridge.getDownloadProgress()` → `Stream<double>` (0.0–1.0 progress ratio)

- [ ] **Step 1: Update `RustBridge` abstract class**

Tambah method:
```dart
Stream<double> downloadProgress(String modelsDir, String modelId);
```

- [ ] **Step 2: Implementasi di `RustEngineBridge`**

Gunakan `Timer.periodic` 200ms polling ke `rust_api.getDownloadProgress()`, selesai ketika `bytes_downloaded >= total_bytes` atau `total_bytes == 0`.

```dart
@Override
Stream<double> downloadProgress(String modelsDir, String modelId) {
  // Start download first
  downloadModel(modelsDir, modelId);
  // Then poll progress
  return Stream.periodic(const Duration(milliseconds: 200), (_) async {
    final progress = await rust_api.getDownloadProgress();
    if (progress == null) return 0.0;
    if (progress.totalBytes == 0) return 0.0;
    return progress.bytesDownloaded / progress.totalBytes;
  }).asyncMap((v) => v).takeWhile((v) => v < 1.0).followedBy(Stream.value(1.0));
}
```

- [ ] **Step 3: Implementasi di `RustBridgeMock`**

```dart
@Override
Stream<double> downloadProgress(String modelsDir, String modelId) {
  // Simulate progress over 3 seconds
  return Stream.periodic(const Duration(milliseconds: 300), (i) => (i+1) / 10.0)
      .take(10);
}
```

- [ ] **Step 4: Update test doubles di semua file test**

Semua test file yang implement `RustBridge` harus tambah method `downloadProgress`. File yang perlu diubah:
- `test/widget_test.dart` — `_NoopBridge`
- `test/session_model_test.dart` — `_NoopBridge`
- `test/setup_wizard_test.dart` — `_FakeBridge`
- `test/settings_screen_test.dart` — `_TestBridge`
- `test/main_screen_recovery_test.dart` — `_RecoveryBridge`

Masing-masing tambah:
```dart
@Override
Stream<double> downloadProgress(String modelsDir, String modelId) => const Stream.empty();
```

- [ ] **Step 5: Run test**

```bash
flutter test
```

Expected: 47+ passed

- [ ] **Step 6: Commit**

```bash
git add lib/services/bridge_service.dart test/
git commit -m "feat(ui): add download progress stream to RustBridge"
```

### Task A3: Tampilkan progress bar di Setup Wizard

**Files:**
- Modify: `lib/screens/setup_wizard_screen.dart`
- Test: `test/setup_wizard_test.dart`

**Interfaces:**
- Consumes: `RustBridge.downloadProgress(modelsDir, modelId)` → `Stream<double>`
- Produces: Wizard step 4 menunjukkan `LinearProgressIndicator` real-time selama download

- [ ] **Step 1: Baca wizard screen yang ada**

```bash
read_file lib/screens/setup_wizard_screen.dart
```

- [ ] **Step 2: Update `_DownloadStep` widget**

Di `_WizardStep.modelDownload` case, ganti tombol "Unduh model" dengan:

```dart
// Saat download aktif:
StreamBuilder<double>(
  stream: bridge.downloadProgress(settings.libraryPath, _selectedModel),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final progress = snapshot.data!;
      return Column(
        children: [
          LinearProgressIndicator(value: progress),
          Text('${(progress * 100).round()}%'),
        ],
      );
    }
    // Tombol unduh
    return ElevatedButton(...);
  },
)
```

- [ ] **Step 3: Update widget test untuk progress**

```dart
testWidgets('download step shows progress bar during download', ...)
```

- [ ] **Step 4: Run test**

```bash
flutter test test/setup_wizard_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/setup_wizard_screen.dart test/setup_wizard_test.dart
git commit -m "feat(ui): show real-time download progress bar in wizard"
```

### Task A4: Wire Rust `transcribe_files_batch` ke Dart

**Files:**
- Modify: `lib/services/bridge_service.dart` (tambah method)
- Modify: `lib/state/batch_upload_model.dart` (konek ke real engine)
- Test: `test/batch_upload_model_test.dart`

**Interfaces:**
- Consumes: Rust `api.rs::transcribe_files_batch()` → butuh dibuat wrapper dulu
- Produces: Batch transcribe bekerja dengan real Rust engine (tidak hanya mock)

- [ ] **Step 1: Cek apakah `transcribe_files_batch` sudah di `api.rs`**

```bash
grep -n "transcribe_files_batch\|transcribe_file" rust_core/src/api.rs
```

- [ ] **Step 2: Jika belum ada, buat wrapper API**

```rust
pub fn transcribe_files_batch(
    model_path: String,
    files: Vec<String>,
    output_dir: String,
    language: Option<String>,
) -> Result<(), TranscribeError> {
    // Load engine, process files
}
```

- [ ] **Step 3: Regenerate FRB bindings**

Sama seperti Task A1 Step 3.

- [ ] **Step 4: Hubungkan ke `BatchUploadNotifier`**

```dart
Future<void> processBatch(RustBridge bridge, String modelPath) async {
  for (final entry in state) {
    updateStatus(entry.path, BatchFileStatus.transcribing);
    // Call Rust batch
  }
}
```

- [ ] **Step 5: Run full test suite**

```bash
flutter analyze && flutter test
cd rust_core && cargo test --lib
```

- [ ] **Step 6: Commit**

```bash
git add lib/ rust_core/src/api.rs
git commit -m "feat: wire batch transcription to Rust engine"
```

---

## Bagian B: Setup Computer Use (cua-driver) untuk GUI Testing

### Latar Belakang

cua-driver v0.12.6 sudah terinstall di M4 Pro MacBook (dari memory notes). Tersedia 49 macOS MCP tools. Yang perlu dilakukan:
1. Verifikasi cua-driver berfungsi penuh (Accessibility + Screen Recording permissions)
2. Buat sesi Hermes + cua-driver untuk testing Transcribe
3. Buat smoke test script yang bisa jalan otomatis
4. Integrasikan dengan workflow development (pre-commit GUI smoke test opsional)

### Task B1: Verifikasi dan Update cua-driver

**Files:** None (system-level)
**Commands:**
**Interfaces:**
- Produces: cua-driver daemon siap digunakan, permissions granted

- [ ] **Step 1: Cek versi cua-driver dan health**

```bash
hermes computer-use doctor
```

Atau langsung panggil MCP:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"check_for_update","arguments":{}}}' | cua-driver mcp
```

Expected output: version info + health status per check

- [ ] **Step 2: Jika update tersedia, install**

```bash
cua-driver update
```

- [ ] **Step 3: Cek permissions**

```bash
cua-driver permissions check
```

Expected: Accessibility ✅, Screen Recording ✅

- [ ] **Step 4: Jika permission kurang, grant**

Buka System Settings → Privacy & Security:
```bash
cua-driver permissions grant --all
```

- [ ] **Step 5: Verifikasi daemon berjalan**

```bash
cua-driver status
```

### Task B2: Buat Smoke Test Script untuk Transcribe

**Files:**
- Create: `scripts/gui_smoke_test.sh`
- Create: `scripts/gui_smoke_test.dart` (opsional — Hermes agent script)

**Interfaces:**
- Consumes: cua-driver MCP tools via `computer_use` Hermes tool
- Produces: Automated GUI smoke test yang memverifikasi: app launch, wizard, main screen

- [ ] **Step 1: Buat script Hermes agent untuk smoke test**

```bash
cat > scripts/gui_smoke_test.sh << 'SCRIPT'
#!/usr/bin/env bash
# GUI Smoke Test untuk Transcribe menggunakan computer_use via Hermes
# Jalankan: hermes chat -q "$(cat scripts/gui_smoke_test.sh)"
set -euo pipefail

echo "=== Transcribe GUI Smoke Test ==="
echo "Test 1: Launch app"
open -a "Transcribe" || { echo "FAIL: App not found"; exit 1; }
sleep 2

echo "Test 2: Verify window exists"
# Will be executed by Hermes agent with computer_use
SCRIPT
chmod +x scripts/gui_smoke_test.sh
```

- [ ] **Step 2: Buat test plan detail untuk computer use**

Bikin file markdown yang menjelaskan setiap langkah GUI test secara detail:

```markdown
# GUI Smoke Test Plan — Transcribe

## Prerequisites
- cua-driver daemon running
- Transcribe app built (flutter build macos --debug)
- Models directory with ggml-tiny.bin

## Test Cases

### TC1: App Launches
1. capture(desktop) → verify app icon exists
2. Launch app via open command
3. capture(app="Transcribe") → verify main window visible

### TC2: Wizard Complete Flow (5 steps)
1. capture(app="Transcribe") → find "Lanjut" button
2. click(element=N) → verify step changes
3. Repeat for all 5 steps
4. Verify "Selesai" button visible on last step

### TC3: Main Screen Elements
1. Verify mode selector (Webinar, Rapat Online, Rapat Offline)
2. Verify MIC/SPK indicators
3. Verify Start button ("Mulai")
4. Verify Export button
```

- [ ] **Step 3: Test dengan session Hermes + computer_use**

Jalankan sesi Hermes dengan skill computer-use terload:
```bash
hermes chat -q "Jalankan GUI smoke test untuk Transcribe: 
1. Buka aplikasi Transcribe 
2. Verifikasi window muncul
3. Screenshot dan report"
```

Gunakan `computer_use(action="capture")` untuk screenshot, `computer_use(action="click", element=N)` untuk navigasi.

- [ ] **Step 4: Simpan hasil test pertama**

```bash
mkdir -p test/screenshots/gui-smoke
cp /tmp/transcribe_smoke_*.png test/screenshots/gui-smoke/
```

### Task B3: Integrasi GUI Smoke Test ke Workflow

**Files:**
- Create: `.github/workflows/gui-smoke.yml` (optional — untuk CI dengan macOS runner)
- Modify: `AGENTS.md` (tambah step GUI smoke test)

**Interfaces:**
- Consumes: `scripts/gui_smoke_test.sh`, cua-driver, Transcribe debug build
- Produces: Pre-commit / pre-push GUI smoke test yang bisa jalan otomatis

- [ ] **Step 1: Update AGENTS.md**

Tambah baris:
```
- Run `scripts/gui_smoke_test.sh`  sebelum merge jika ada perubahan UI
```

- [ ] **Step 2: Dokumentasikan cara pakai computer use**

Buat file `COMPUTER_USE.md` yang menjelaskan:
- Cara capture
- Cara click by element
- Cara type
- Cara scroll
- Cara verify before/after

- [ ] **Step 3: Commit semua perubahan**

```bash
git add scripts/gui_smoke_test.sh AGENTS.md COMPUTER_USE.md
git commit -m "feat: add GUI smoke test infrastructure with cua-driver"
```

---

## Bagian C: Verify & Push

### Task C1: Full Regression Test

- [ ] **Step 1: Rust full test**

```bash
cd rust_core && cargo test --lib && cargo fmt --check
```

Expected: 105+ passed, fmt clean

- [ ] **Step 2: Flutter full test**

```bash
flutter analyze && flutter test
```

Expected: 0 errors, 50+ tests passed

- [ ] **Step 3: GUI smoke test manual**

```bash
hermes chat -q "Jalankan GUI smoke test Transcribe: buka app, screenshots, verifikasi semua elemen utama"
```

- [ ] **Step 4: Push ke origin**

```bash
git push origin main
```

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| FRB codegen gagal karena API changes | Medium | High | Test `cargo test --lib` sebelum codegen; rollback jika rust compilation error |
| cua-driver permissions belum grant | Low | Medium | Dokumen `cua-driver permissions grant --all` sebagai step pertama |
| Flutter widget tests broken oleh bridge changes | Medium | Medium | Semua test doubles (5 file) harus synchronously update |
| `setup_wizard_test.dart` gagal karena progress bar | Medium | Low | StreamBuilder di test perlu `pump(Duration)` untuk trigger |
| cua-driver daemon tidak jalan di Hermes desktop | Low | High | Cek dengan `cua-driver status`; restart jika perlu |

## Open Questions

1. **FRB codegen version compatibility** — Apakah flutter_rust_bridge v2.12.0 codegen bisa handle `Option<DownloadProgress>` return type? Jika tidak, perlu bungkus dalam `Vec` atau `String` (JSON serialized).
2. **cua-driver + Hermes desktop app** — Apakah `computer_use` tool bisa di-invoke dari Hermes desktop app (bukan hanya CLI)? Dari system prompt terlihat tool `computer_use` tersedia — perlu diverifikasi.
3. **Batch transcription progress** — Apakah perlu progress callback dari Rust ke Dart untuk batch file, atau cukup status update per-file? Saat ini `transcribe_files_batch` pakai closure callback — perlu FRB-compatible pattern.
