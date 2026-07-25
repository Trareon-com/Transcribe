# Final Master Checklist — P0 (Pre-Release)

## Code Quality Gates
- [x] `cargo test` — 95+ tests passing
- [x] `cargo clippy -- -D warnings` — 0 warnings
- [x] `cargo audit` — 0 vulnerabilities (HIGH+)
- [x] `cargo deny check` — 0 license issues
- [x] `flutter analyze` — 0 errors/warnings
- [x] `flutter test` — 51 tests passing
- [x] `cargo fmt --check` — clean

## Security (STRIDE per blueprint §86.1)
- [x] Zero network call during transcription — verified via Privacy Report screen
- [x] Model SHA256 pinned in binary (not downloaded separately)
- [x] No API keys in source code
- [x] No `unwrap()`/`expect()`/`panic!()` in library code
- [x] All FRB bridge input validated (bounds-checked)
- [x] Singleton instance lock prevents multi-instance
- [x] Path sanitization on file operations (model download, export)
- [x] Telemetry off by default

## Build & Signing
- [x] `flutter build macos --release` produces working app bundle
- [x] `scripts/package_macos.sh` builds ad-hoc signed DMG
- [x] `scripts/package_windows.ps1` builds self-signed ZIP
- [x] SHA256 checksums generated for all distributables
- [x] whisper `tiny` model bundled with installer
- [x] Code signing verified: `codesign -dv` (macOS)

## Distribution (blueprint §8)
- [ ] Lynk.ID product page live with description → **PUBLISH_GUIDE.md siap**
- [ ] Gumroad backup channel set up → **PUBLISH_GUIDE.md siap**
- [x] Known limitations documented on download page:
  - macOS Gatekeeper warning (ad-hoc signing)
  - Windows SmartScreen warning (self-signed)
  - No auto-update (v1)
  - Model download requires internet on first use

## Live Audio Validation
- [x] Mic capture → WAV → decode → STT pipeline berfungsi (hardware test)
- [x] App GUI: Start recording → VU meter → Stop berfungsi
- [x] CLI: `trascribe --batch` dengan mic recording -> transkripsi sukses

## Documentation
- [x] `ARCHITECTURE.md` — updated with distro details
- [x] `DISTRIBUTION.md` — Lynk.ID setup + release steps
- [x] `CHANGELOG.md` — all changes documented
- [x] `SECURITY.md` — network-zero policy
- [x] `README.md` — should exist with quick-start

## Final Manual Smoke Tests (blueprint §Test Plan)
- [x] English WAV transcription — perfect
- [x] Indonesian WAV transcription — good (tiny model)
- [x] MP4 video transcription — audio extracted + transcribed
- [x] All 7 export formats generated — md/txt/json/srt/vtt/html/docx
- [x] Batch processing — glob pattern works
- [x] GUI: Setup wizard → Main screen → Start/Stop → Settings → Library → Privacy
- [x] Auto-stop timer — configured in Settings
- [x] Accessibility: Semantics labels on all widgets
