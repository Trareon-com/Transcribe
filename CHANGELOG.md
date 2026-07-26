# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/); this project is
pre-1.0 so versions aren't cut yet — entries are grouped by development
phase instead.

## [0.1.0] — 2026-07-26

### Fixed
- CI `flutter test` failure: `session_model_test` now creates a temp directory with
  a stub model file so `_sanitizeDefaultModel` resolves correctly on CI runners
  without pre-downloaded models.
- Fixed branch in CI badge URL (README.md).

### Added

- Repo scaffold, CI (cargo fmt/clippy/test/audit/deny + flutter
  analyze/test), Dependabot, SECURITY.md, performance benchmark scripts
- Rust engine core: audio device enumeration, ring buffer, dual-stage VAD
  (WebRTC + confirmation), whisper-rs STT engine + file/batch
  transcription, echo-dedupe, export (Markdown/TXT/JSON/SRT/VTT/HTML/
  DOCX/WAV), pure-Rust decode (Symphonia + rubato, no ffmpeg), model
  catalog with SHA256 verification and resumable download, in-memory
  session registry with auto-split (time + memory pressure), settings
  persistence, singleton instance lock, CLI mode (`transcribe-cli`),
  diarization (acoustic feature clustering for multi-speaker)
- Flutter UI: theme (light/dark/system), Riverpod state management, main
  screen (mode selector, mic/speaker toggles, VU meter, transcript view,
  pause/resume, stop confirmation), first-run setup wizard (5 steps with
  premium dark glassmorphism design), settings screen, library screen
  (search, soft-delete with undo, export dialog, file upload with drag &
  drop), transcript player (seek, speed control, inline editing), Privacy
  Report screen, usage dashboard, native share sheet, in-app keyboard
  shortcuts + visible shortcuts panel, minimize-to-tray, accessibility
  semantics across all widgets (WCAG 2.2 AA)
- flutter_rust_bridge wired end-to-end: `RustEngineBridge` is now the
  default bridge, calling real generated Dart bindings (`lib/src/rust/`)
  into the compiled Rust engine.
- Desktop build plumbing now builds and installs the Rust library on
  Linux, Windows, and macOS as part of the native desktop build flow.
- Resume download for models now appends partial files and is covered
  by a deterministic unit test.
- Transcript-player edits now notify listeners, and the session state
  exposes a shared transcript-edit update path.
- Auto-stop timer: configurable inactivity timeout stops recording after
  N minutes of silence (Settings → Auto-stop, default: disabled).
- Accessibility: WCAG 2.2 AA contrast ratios, keyboard focus traversal,
  Semantics labels on all widgets, minimum 24x24pt tap targets.
- Release workflow now builds macOS DMG (ad-hoc signed) and Windows ZIP
  (self-signed) on tag push. DISTRIBUTION.md documents Lynk.ID setup.
- Performance benchmark script (`scripts/benchmark.sh`) with CI gate
  thresholds for STT latency, export time, and VAD processing.
- STT priority queue: mic segments processed before speaker segments.
- Parallel export: each format runs in its own thread.
- Chunked file processing: large files transcoded in 30s chunks.

### Known gaps
- Live audio capture still needs real hardware validation, especially
  end-to-end on a machine with the target microphones/speakers.
- No notarization (macOS); SmartScreen warning (Windows) — see DISTRIBUTION.md
- No auto-update (manual check only in v1)
- Lynk.ID product page not yet live (DISTRIBUTION.md has the checklist)
