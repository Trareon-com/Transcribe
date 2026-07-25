
<p align="center">
  <br/>
  <img src="https://img.shields.io/badge/Trascribe-100%25%20Offline%20Meeting%20Transcriber-8A2BE2?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MCIgaGVpZ2h0PSI0MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cGF0aCBkPSJNMTIgMWEzIDMgMCAwIDAtMyAzdjhhMyAzIDAgMCAwIDYgMFY0YTMgMyAwIDAgMC0zLTN6Ii8+PHBhdGggZD0iTTE5IDEwdjJhNyA3IDAgMCAxLTE0IDB2LTIiLz48bGluZSB4MT0iMTIiIHkxPSIxOSIgeDI9IjEyIiB5Mj0iMjMiLz48bGluZSB4MT0iOCIgeTE9IjIzIiB4Mj0iMTYiIHkyPSIyMyIvPjwvc3ZnPg==" alt="Trascribe"/>
  <br/>
</p>

<h1 align="center">Trascribe</h1>

<p align="center">
  <strong>100% offline mic + speaker meeting transcription for macOS and Windows.</strong><br/>
  Zero network calls during transcription. No cloud STT. No telemetry.
</p>

<p align="center">
  <a href="https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml">
    <img src="https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"/>
  </a>
  <a href="https://lynk.id">
    <img src="https://img.shields.io/badge/distribution-Lynk.ID%20%245-8A2BE2" alt="Lynk.ID $5"/>
  </a>
  <a href="https://www.rust-lang.org/">
    <img src="https://img.shields.io/badge/Rust-1.80+-orange" alt="Rust 1.80+"/>
  </a>
  <a href="https://flutter.dev/">
    <img src="https://img.shields.io/badge/Flutter-3.27+-blue" alt="Flutter 3.27+"/>
  </a>
  <a href="https://github.com/ggerganov/whisper.cpp">
    <img src="https://img.shields.io/badge/whisper.cpp-backed-FF6F00" alt="whisper.cpp"/>
  </a>
  <br/>
  <a href="ARCHITECTURE.md">Architecture</a> •
  <a href="CHANGELOG.md">Changelog</a> •
  <a href="CONTRIBUTING.md">Contributing</a> •
  <a href="SECURITY.md">Security</a> •
  <a href="DISTRIBUTION.md">Distribution</a>
</p>

---

## Features

- **100% offline** — Zero network calls during transcription. Your audio never leaves your machine.
- **Dual audio capture** — Simultaneously captures microphone and system speaker audio for complete meeting coverage.
- **Dual-stage VAD** — WebRTC VAD gate + confirmation detector for accurate speech segment boundaries.
- **whisper.cpp engine** — Local speech-to-text via `whisper-rs`, supporting all GGUF models from `tiny` to `large-v3-turbo`.
- **Multi-speaker diarization** — Acoustic feature clustering for speaker separation in transcripts.
- **Echo deduplication** — Intelligent dedupe (MIC vs SPK similarity) prevents duplicate transcription of the same speech.
- **Priority queue** — Mic segments processed before speaker segments for responsive live transcription.
- **Auto-split sessions** — Sessions automatically split by time and memory pressure thresholds.
- **Resumable model downloads** — Large Whisper models download with SHA256 verification and resume support.
- **Rich export formats** — Markdown, TXT, JSON, SRT, VTT, HTML, DOCX, and WAV.
- **Parallel export** — Each export format runs in its own thread for speed.
- **Chunked file processing** — Large files transcoded in 30-second chunks.
- **In-memory session registry** — Manage multiple transcription sessions with search, soft-delete (with undo), and playback.
- **Built-in transcript player** — Seek, speed control, and inline editing of transcript text.
- **CLI mode** — `trascribe-cli` for batch-transcribing files from the command line without the UI.
- **Privacy Report** — See exactly what data stays local and what (if anything) ever touched the network.
- **Usage dashboard** — Track transcription time, word counts, and session history.
- **First-run setup wizard** — 5-step guided configuration with premium dark glassmorphism design.
- **Light / dark / system theme** — Full Riverpod-managed theme switching.
- **Keyboard shortcuts** — In-app shortcuts panel with minimize-to-tray support.
- **WCAG 2.2 AA accessibility** — Semantics labels, keyboard focus traversal, minimum 24×24pt tap targets across all widgets.
- **Auto-stop timer** — Configurable inactivity timeout stops recording after N minutes of silence.

> See the [CHANGELOG](CHANGELOG.md) for the full development history and known gaps.

## Screenshots

| Main Screen | Recording Active | Settings |
|:---:|:---:|:---:|
| ![Main Screen](assets/screenshots/trascribe_main_screen.png) | ![Recording Active](assets/screenshots/trascribe_recording_active.png) | ![Settings](assets/screenshots/trascribe_settings_screen.png) |

| Setup Wizard | Privacy Report | Usage Dashboard |
|:---:|:---:|:---:|
| ![Setup Wizard Step 3](assets/screenshots/trascribe_step3_audio.png) | ![Privacy Report](assets/screenshots/trascribe_privacy_report.png) | ![Usage Dashboard](assets/screenshots/trascribe_usage_dashboard.png) |

| Model Selection | Transcript Player | Tone Test |
|:---:|:---:|:---:|
| ![Model Download](assets/screenshots/trascribe_step4_download.png) | ![Transcript Playing](assets/screenshots/trascribe_tone_test_playing.png) | ![Tone Test](assets/screenshots/trascribe_step5_tone.png) |

*Screenshots will be added to `assets/screenshots/` before release. These reflect the pre-1.0 development UI.*

---

## Architecture Overview

Trascribe is a **Flutter UI over a Rust engine**, connected via [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) (FRB) V2. The Rust engine (`rust_core`) handles all audio pipeline work — device enumeration via `cpal`, dual-stage VAD (WebRTC gate + confirmation), `whisper-rs` STT inference, echo deduplication, session management, and multi-format export — entirely offline. The Flutter layer manages the UI state with Riverpod, polling the Rust event queue every 100ms for transcript and VU events. No audio data ever traverses the network; model downloads are the only legitimate network activity and are SHA256-verified. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full layout and data flow diagram.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI** | Flutter 3.27+ (Dart), Riverpod, flutter_rust_bridge v2.12 |
| **Engine** | Rust 1.80+ (edition 2021) |
| **STT** | whisper.cpp via `whisper-rs` 0.14 (any GGUF model) |
| **Audio capture** | `cpal` 0.15 |
| **Audio decode** | Symphonia + rubato (pure Rust, no ffmpeg dependency) |
| **VAD** | WebRTC VAD (`webrtc-vad` 0.4) + confirmation stage |
| **Export** | Markdown, TXT, JSON, SRT, VTT, HTML, DOCX (`docx-rs`), WAV (`hound`) |
| **Model download** | `reqwest` with SHA256 verification + resume |
| **Distribution** | Lynk.ID ($5) — macOS DMG (ad-hoc signed), Windows ZIP (self-signed) |

## Quick Start

### Prerequisites

- [Flutter](https://flutter.dev/) 3.27+ (stable channel)
- [Rust](https://www.rust-lang.org/) 1.80+ with `cmake` on PATH (whisper.cpp is compiled from source)
- **macOS**: Xcode + CocoaPods for building the macOS target
- **Windows**: Visual Studio Build Tools for building the Windows target

### Build and Run

```bash
# 1. Clone the repository
git clone https://github.com/Trareon-com/Transcribe.git
cd Transcribe

# 2. Install Flutter dependencies
flutter pub get

# 3. Build the Rust engine
cd rust_core
cargo build --release --lib
cd ..

# 4. Build and run the Flutter app
flutter run -d macos   # or: flutter run -d windows
```

### Batch Transcribe via CLI

```bash
cd rust_core
cargo run --bin trascribe -- \
  --batch "*.mp3" --output ./transcripts/ --model models/ggml-tiny.bin
```

### Generate Test Fixtures (no real mic / model required)

```bash
cd rust_core
cargo run --bin gen_fixtures -- ../test/fixtures
```

### Build a Distributable Package

```bash
# macOS
bash scripts/package_macos.sh "1.0.0"

# Windows (PowerShell)
.\scripts\package_windows.ps1 -Version "1.0.0"
```

Both scripts: build Rust release → build Flutter release → sign → package → generate SHA256 checksum → output to `dist/`.

---

## Distribution

Trascribe source code is **MIT licensed** and publicly available on GitHub. Pre-built binary installers are distributed through **Lynk.ID** for **$5**.

| Platform | Installer | Signing |
|----------|-----------|---------|
| macOS | `.dmg` | Ad-hoc signed (`codesign --sign -`) |
| Windows | `.zip` | Self-signed (makecert) |

**Important**: See [`DISTRIBUTION.md`](DISTRIBUTION.md) for full details on signing status, Lynk.ID product page checklist, model bundling, release workflow, and the hotfix protocol.

---

## Known Limitations

- **No notarization (macOS)** — Ad-hoc signing means Gatekeeper shows "Apple cannot verify this app" on first launch. Users can right-click → Open to bypass once; subsequent launches are silent.
- **SmartScreen warning (Windows)** — Self-signed certificate triggers "Windows protected your PC" on first run until sufficient reputation is established.
- **No auto-update (v1)** — Users check manually via Help → Check for Updates. Full auto-update with Ed25519 binary signature is planned for v2.
- **Large model downloads require internet** — The `tiny` model (~75MB) is bundled; larger models (base/small/medium/large-v3-turbo) download on-demand via HTTPS.
- **Live audio capture** — Real hardware validation is still in progress, especially end-to-end testing with target microphones and speakers.
- **Lynk.ID product page** — Not yet live (see DISTRIBUTION.md for the checklist).

---

## FAQ

### Does Trascribe send my audio to the cloud?

**No.** Trascribe is 100% offline. During transcription — both live capture and file transcription — the application makes **zero network calls**. The only network activity is downloading an optional Whisper model you explicitly select (HTTPS, checksum-verified).

### What models does Trascribe support?

Any GGUF-format Whisper model. The `tiny` model (~75 MB) is bundled with the installer. Larger models (`base`, `small`, `medium`, `large-v3-turbo`) are downloaded on-demand with SHA256 verification and resume support if interrupted.

### Which platforms are supported?

**macOS** and **Windows** are actively supported and tested. Linux builds as part of CI but does not yet have packaging scripts or a distribution channel.

### What export formats are available?

Markdown, plain text (TXT), JSON, SRT, VTT, HTML, DOCX, and WAV. Each format exports in its own thread for speed.

### How does speaker diarization work?

Trascribe uses acoustic feature clustering to separate speakers based on voice characteristics. This is done entirely locally — no cloud services or speaker enrollment required.

### Can I transcribe pre-recorded files?

Yes. Drag and drop audio files onto the library screen, or use the `trascribe` CLI for batch file processing. Supported formats include MP3, AAC, MP4, OGG, FLAC, and WAV (via Symphonia).

### How do I bypass the Gatekeeper / SmartScreen warning?

- **macOS**: Right-click (or Ctrl+click) the app → Open → Click "Open" in the dialog. Subsequent launches work normally.
- **Windows**: Click "More info" → "Run anyway". The warning disappears once SmartScreen builds enough reputation.

### Is telemetry or crash reporting collected?

**No.** There is no telemetry, no analytics, and no crash reporting enabled by default. Any future opt-in diagnostics will be documented in [SECURITY.md](SECURITY.md) before release and will never transmit audio or transcript content.

### How do I update Trascribe?

In v1, check for updates manually via Help → Check for Updates. A full auto-update system with Ed25519 binary signature verification is planned for v2.

### Can I contribute?

Absolutely! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup instructions, code style guidelines, PR process, and CI gate requirements.

---

## Security

See [`SECURITY.md`](SECURITY.md) for the full security policy, including:
- Core privacy guarantee (zero network calls during transcription)
- Vulnerability reporting process (GitHub Security Advisory or email)
- Development security practices (`cargo audit`, `cargo deny`, clippy gates)
- Supported versions and fix timelines

## License

MIT — see [`LICENSE`](LICENSE) for the full text. Copyright © 2026 Trareon.com.
