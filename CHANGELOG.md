# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/); this project is
pre-1.0 so versions aren't cut yet — entries are grouped by development
phase instead.

## Unreleased

### Added
- Repo scaffold, CI (cargo fmt/clippy/test/audit/deny + flutter
  analyze/test), Dependabot, SECURITY.md
- Rust engine core: audio device enumeration, ring buffer, dual-stage VAD
  (WebRTC + confirmation), whisper-rs STT engine + file/batch
  transcription, echo-dedupe, export (Markdown/TXT/JSON/SRT/VTT/HTML/
  DOCX/WAV), pure-Rust decode (Symphonia + rubato, no ffmpeg), model
  catalog with SHA256 verification and resumable download, in-memory
  session registry with auto-split (time + memory pressure), settings
  persistence, singleton instance lock, CLI mode (`trascribe-cli`)
- Flutter UI: theme (light/dark/system), Riverpod state management, main
  screen (mode selector, mic/speaker toggles, VU meter, transcript view,
  pause/resume, stop confirmation), first-run setup wizard (5 steps),
  settings screen, library screen (search, soft-delete with undo, export
  dialog, file upload with drag & drop), transcript player (seek, speed
  control, inline editing), Privacy Report screen, usage dashboard, native
  share sheet, in-app keyboard shortcuts + visible shortcuts panel,
  accessibility semantics (VU meter, stream toggles)
- flutter_rust_bridge wired end-to-end: `RustEngineBridge` is now the
  default bridge, calling real generated Dart bindings (`lib/src/rust/`)
  into the compiled Rust engine. Verified by launching the built macOS app
  and confirming it initializes and runs without error against a real
  `librust_core.dylib`. Fixed two codegen blockers along the way (see
  `ARCHITECTURE.md`): the `TrascribeResult<T>` alias not resolving across
  modules, and `TrascribeError::Io` needing to be `String` instead of
  `std::io::Error` for FFI serialization.
  - Desktop build plumbing now builds and installs the Rust library on
    Linux, Windows, and macOS as part of the native desktop build flow.
  - Resume download for models now appends partial files and is covered
    by a deterministic unit test.
  - Transcript-player edits now notify listeners, and the session state
    exposes a shared transcript-edit update path.

### Known gaps
- Native library loading still has a runtime fallback path in
  `rust_library_loader.dart` for dev runs and nonstandard bundle layouts.
- Live audio capture still needs real hardware validation, especially
  end-to-end on a machine with the target microphones/speakers.
- No real whisper GGUF model is bundled yet; `model.rs`'s checksum
  pins are placeholders pending the official release manifest.
- Tagged release publishing is source-only; binary distribution and code
  signing remain separate follow-up work.
