<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/Trascribe-100%25-Offline%20Transcriber-00796B?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MCIgaGVpZ2h0PSI0MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cGF0aCBkPSJNMTIgMWEzIDMgMCAwIDAtMyAzdjhhMyAzIDAgMCAwIDYgMFY0YTMgMyAwIDAgMC0zLTN6Ii8+PHBhdGggZD0iTTE5IDEwdjJhNyA3IDAgMCAxLTE0IDB2LTIiLz48bGluZSB4MT0iMTIiIHkxPSIxOSIgeDI9IjEyIiB5Mj0iMjMiLz48bGluZSB4MT0iOCIgeTE9IjIzIiB4Mj0iMTYiIHkyPSIyMyIvPjwvc3ZnPg=="/>
  <img alt="Trascribe" src="https://img.shields.io/badge/Trascribe-100%25-Offline%20Transcriber-00796B?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MCIgaGVpZ2h0PSI0MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cGF0aCBkPSJNMTIgMWEzIDMgMCAwIDAtMyAzdjhhMyAzIDAgMCAwIDYgMFY0YTMgMyAwIDAgMC0zLTN6Ii8+PHBhdGggZD0iTTE5IDEwdjJhNyA3IDAgMCAxLTE0IDB2LTIiLz48bGluZSB4MT0iMTIiIHkxPSIxOSIgeDI9IjEyIiB5Mj0iMjMiLz48bGluZSB4MT0iOCIgeTE9IjIzIiB4Mj0iMTYiIHkyPSIyMyIvPjwvc3ZnPg=="/>
</picture>

<h1 align="center">Trascribe</h1>

<p align="center">
  <strong>100% offline microphone + speaker transcription for macOS, Windows, and Linux.</strong><br/>
  Zero network calls during transcription. Your audio never leaves your machine.
</p>

<p align="center">
  <a href="https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml">
    <img src="https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"/>
  </a>
  <a href="https://www.rust-lang.org/">
    <img src="https://img.shields.io/badge/Rust-1.80+-orange" alt="Rust 1.80+"/>
  </a>
  <a href="https://flutter.dev/">
    <img src="https://img.shields.io/badge/Flutter-3.27+-blue" alt="Flutter 3.27+"/>
  </a>
  <a href="https://github.com/ggerganov/whisper.cpp">
    <img src="https://img.shields.io/badge/engine-whisper.cpp-FF6F00" alt="whisper.cpp"/>
  </a>
  <br/>
  <a href="ARCHITECTURE.md">Architecture</a> •
  <a href="CHANGELOG.md">Changelog</a> •
  <a href="CONTRIBUTING.md">Contributing</a> •
  <a href="SECURITY.md">Security</a>
</p>

---

Trascribe is a desktop application that transcribes meetings, lectures, interviews, and any other audio source — 100% offline. It captures both microphone input and system speaker output simultaneously, runs speech-to-text locally via Whisper, and exports transcripts in multiple formats. No cloud services, no telemetry, no network calls during transcription.

---

## Features

### Privacy & Offline

- **100% offline transcription** — No audio data ever leaves your machine. Zero network calls during active transcription.
- **No telemetry** — No analytics, no crash reporting, no background network activity.
- **Privacy Report** — Built-in screen showing all network activity (only model downloads ever appear).
- **No account required** — No sign-up, no login, no cloud dependency.

### Audio Capture

- **Dual capture** — Simultaneously records microphone and system speaker audio for complete meeting coverage.
- **Dual-stage VAD** — WebRTC VAD gate + confirmation detector for accurate speech boundaries.
- **VU meter** — Real-time audio level indicators for both MIC and SPK channels.
- **Platform loopback** — WASAPI loopback (Windows), CoreAudio Process Taps (macOS 14.4+), PipeWire (Linux).

### Speech-to-Text

- **whisper.cpp engine** — Local STT via `whisper-rs`, supporting all GGUF models from `tiny` (~75 MB) to `large-v3-turbo`.
- **Multi-speaker diarization** — Acoustic feature clustering separates speakers in transcripts.
- **Echo deduplication** — Cross-source dedupe (MIC vs SPK similarity) prevents duplicate transcription.
- **Priority queue** — Mic segments processed before speaker segments for responsive live transcription.
- **Auto-split sessions** — Sessions split automatically by time (hourly) and memory pressure thresholds.

### Export

| Format | Description |
|--------|-------------|
| Markdown | Timestamped transcript with speaker labels |
| TXT | Plain text, speaker-concatenated |
| JSON | Structured segment data for programmatic use |
| SRT | Subtitle format with sequence numbering |
| VTT | WebVTT subtitle format |
| HTML | Self-contained styled transcript page |
| DOCX | Microsoft Word document |
| WAV | Recorded audio alongside transcript |

Each export format runs in its own thread for parallel processing.

### User Interface

- **Live transcript view** — Real-time text display with auto-scroll, search, and copy.
- **Pause/resume** — Toggle recording without ending the session.
- **Session library** — Browse, search, delete (with undo), and re-export past sessions.
- **Transcript player** — Seek, speed control, inline editing of transcript text.
- **Mode selector** — Webinar (speaker only), Rapat Online (mic + speaker), Offline (mic only).
- **First-run setup wizard** — 5-step guided configuration: spec detection, model selection, audio setup, model download, tone test.
- **Light / dark / system theme** — Full theme switching managed via Riverpod.
- **Keyboard shortcuts** — Cmd+R (start/stop), Cmd+P (pause/resume), Cmd+L (library), Cmd+, (settings), Cmd+/ (shortcuts panel).
- **Minimize to tray** — Recording continues when window is hidden.
- **WCAG 2.2 AA accessibility** — Semantics labels, keyboard focus traversal, minimum 24×24pt tap targets.

### CLI & Batch Processing

- **`trascribe` CLI** — Batch-transcribe audio files without the UI.
- **`gen_fixtures`** — Generate synthetic WAV fixtures for hardware-free testing.
- **Batch file upload** — Drag-and-drop audio files for multi-file transcription.

---

## Screenshots

> Screenshots will be added to `assets/screenshots/` before the first public release. The current UI reflects pre-1.0 development — visual polish and final layout adjustments are ongoing.

| Main Screen | Recording | Settings |
|:---:|:---:|:---:|
| *(pending)* | *(pending)* | *(pending)* |

---

## Architecture

```
lib/                      Flutter UI (Dart)
├── screens/              Full-page screens
├── widgets/              Reusable UI components
├── state/                Riverpod notifiers + data models
├── services/             Bridge interface + implementations
├── src/rust/             FRB-generated Dart bindings
└── theme/                Color tokens + ThemeData

rust_core/                Rust engine
├── src/
│   ├── api.rs            Public FFI surface (FRB entry point)
│   ├── audio/            Device enumeration, ring buffer, config
│   ├── vad/              Dual-stage VAD
│   ├── stt/              whisper-rs wrapper + batch transcription
│   ├── dedupe/           Echo deduplication
│   ├── export/           Multi-format export writers
│   ├── decode/           Audio decode + resample (Symphonia + rubato)
│   ├── model.rs          Catalog, SHA256 verification, resumable download
│   ├── session.rs        Session registry, auto-split, recovery
│   ├── settings.rs       Persistence layer
│   └── singleton.rs      Single-instance PID lock
└── bin/                  CLI tools (trascribe, gen_fixtures, device_probe)
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the complete layout, data flow diagrams, and bridge implementation details.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **UI** | Flutter 3.27+ (Dart), Riverpod, flutter_rust_bridge 2.12 |
| **Engine** | Rust 1.80+, edition 2021 |
| **STT** | whisper.cpp via `whisper-rs` 0.14 |
| **Audio capture** | `cpal` 0.15 |
| **Audio decode** | Symphonia + rubato (pure Rust, no ffmpeg) |
| **VAD** | WebRTC VAD (`webrtc-vad` 0.4) + confirmation stage |
| **Export** | Markdown, TXT, JSON, SRT, VTT, HTML, DOCX (`docx-rs`), WAV (`hound`) |
| **Model download** | `reqwest` with SHA256 verification + resume support |

---

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/) 3.27+ (stable channel)
- [Rust](https://www.rust-lang.org/) 1.80+ with `cmake` on PATH
- **macOS**: Xcode 15+ with Command Line Tools
- **Windows**: Visual Studio 2022 Build Tools (Desktop development with C++ workload)
- **Linux**: `pkg-config`, `libasound2-dev`, `libgtk-3-dev`, `liblzma-dev`, `ninja-build`, `clang`

### Build & Run (Development)

```bash
# Clone
git clone https://github.com/Trareon-com/Transcribe.git
cd Transcribe

# Flutter dependencies
flutter pub get

# Build Rust engine
cd rust_core
cargo build --release --lib
cd ..

# Run
flutter run -d macos     # macOS
flutter run -d windows   # Windows
flutter run -d linux     # Linux
```

### Build Distributable Package

```bash
# macOS
bash scripts/package_macos.sh "1.0.0"

# Windows (PowerShell)
.\scripts\package_windows.ps1 -Version "1.0.0"
```

Both scripts: build Rust release → build Flutter release → sign → package → generate SHA256 checksum → output to `dist/`.

### CLI Batch Transcription

```bash
cd rust_core
cargo run --bin trascribe -- \
  --batch "*.mp3" --output ./transcripts/ --model models/ggml-tiny.bin
```

---

## Platform Support

| Feature | macOS | Windows | Linux |
|---------|-------|---------|-------|
| Live capture (mic + speaker) | ✅ | ✅ | ✅ |
| STT (Whisper) | ✅ | ✅ | ✅ |
| File transcription | ✅ | ✅ | ✅ |
| All export formats | ✅ | ✅ | ✅ |
| CLI mode | ✅ | ✅ | ✅ |
| CI build | ✅ | ✅ | ✅ |
| Packaging script | ✅ (DMG) | ✅ (ZIP) | — |
| Distribution channel | Lynk.ID ($5) | Lynk.ID ($5) | — |
| Notarization / signing | Ad-hoc | Self-signed | — |

---

## Known Limitations

- **macOS Gatekeeper** — Ad-hoc signing shows "Apple cannot verify this app" on first launch. Right-click → Open to bypass once.
- **Windows SmartScreen** — Self-signed certificate triggers "Windows protected your PC" on first run until reputation is established.
- **No auto-update (v1)** — Users check manually via Help → Check for Updates. Ed25519-signed auto-update planned for v2.
- **Model downloads require internet** — `tiny` (~75 MB) bundled; larger models download on-demand via HTTPS (SHA256-verified).
- **Live audio capture** — End-to-end hardware validation across target microphones/speakers is ongoing.

---

## FAQ

### Does Trascribe send my audio to the cloud?

**No.** Trascribe is 100% offline. During transcription — both live capture and file transcription — the application makes zero network calls. The only network activity is downloading an optional Whisper model (HTTPS, SHA256-verified).

### What models are supported?

Any GGUF-format Whisper model. `tiny` (~75 MB) is bundled. `base`, `small`, `medium`, and `large-v3-turbo` download on-demand with resume support.

### Can I transcribe pre-recorded files?

Yes. Drag-and-drop audio/video files onto the Library screen, or use the `trascribe` CLI for batch processing. Supported: MP3, AAC, MP4, OGG, FLAC, WAV, MOV, MKV (via Symphonia).

### How does speaker diarization work?

Acoustic feature clustering separates speakers based on voice characteristics — entirely local, no cloud services required.

### Is telemetry collected?

**No.** There is no telemetry, analytics, or crash reporting. Any future opt-in diagnostics will be documented in [SECURITY.md](SECURITY.md) before release and will never transmit audio or transcript content.

### How do I update?

v1: manual check via Help → Check for Updates. Auto-update with Ed25519 binary verification is planned for v2.

### How do I bypass the Gatekeeper / SmartScreen warning?

- **macOS**: Right-click (or Ctrl+click) the app → Open → Click "Open". Subsequent launches work normally.
- **Windows**: Click "More info" → "Run anyway".

---

## Project Status

Trascribe is in **pre-1.0 development**. The engine, UI, and CI pipeline are functional and tested, but the application has not yet undergone a public beta. Key milestones remaining before 1.0:

- [ ] Live audio capture E2E validation across target hardware
- [ ] Screenshots for README
- [ ] Lynk.ID product page setup
- [ ] macOS notarization
- [ ] Windows code signing
- [ ] Public beta release

---

## Security

See [`SECURITY.md`](SECURITY.md) for:
- Core privacy guarantee (zero network calls during transcription)
- Vulnerability reporting process (GitHub Security Advisory or email)
- Development security practices (`cargo audit`, `cargo deny`, clippy gates)

## License

MIT — see [`LICENSE`](LICENSE) for the full text. Copyright © 2026 [Trareon.com](https://trareon.com).
