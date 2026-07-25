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
  control, inline editing), Privacy Report screen, in-app keyboard
  shortcuts + visible shortcuts panel

### Known gaps
- flutter_rust_bridge wiring is not yet connected — the UI runs against
  `RustBridgeMock`. See `ARCHITECTURE.md` for the two specific blockers
  found and the fix plan.
- Live audio capture threads (cpal streams → ring buffer → VAD → STT
  pipeline) are not yet wired to real hardware.
- No real whisper GGUF model is bundled yet; `model.rs`'s checksum
  pins are placeholders pending the official release manifest.
- No code signing, no CI build/release pipeline, no distribution channel
  set up yet.
