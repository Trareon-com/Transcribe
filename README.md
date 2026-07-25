# Trascribe

Offline mic+speaker meeting transcription for macOS and Windows. 100%
local — zero network calls during transcription, no cloud STT, no
telemetry. Flutter UI, Rust engine (whisper.cpp via `whisper-rs`).

See [`TRASCRIBE-BLUEPRINT.md`](TRASCRIBE-BLUEPRINT.md) for the full
product/architecture blueprint this project is built from.

## Status

Pre-1.0, active development. Core Rust engine (audio capture, VAD, STT,
export, model management), the Flutter UI shell, and the scoped
flutter_rust_bridge event bridge are in place. Device-specific capture and
end-to-end live transcription still require manual hardware/model validation.

## Requirements

- Flutter 3.38+ (stable channel)
- Rust 1.80+ with `cmake` available (whisper.cpp is compiled from source)
- macOS: Xcode + CocoaPods, for building the macOS target
- Windows: Visual Studio Build Tools, for building the Windows target

## Getting started

```bash
flutter pub get
cd rust_core && cargo build && cargo test && cd ..
flutter test
flutter build macos   # or: flutter build windows
```

Generate audio test fixtures (no real mic/model required):

```bash
cd rust_core && cargo run --bin gen_fixtures -- ../test/fixtures
```

Batch-transcribe files from the command line (needs a real whisper GGUF
model):

```bash
cd rust_core && cargo run --bin trascribe_cli -- \
  --batch "*.mp3" --output ./transkrip/ --model models/ggml-tiny.bin
```

## Project layout

See [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Security

See [`SECURITY.md`](SECURITY.md) for the privacy guarantee, vulnerability
reporting process, and development security practices enforced in CI.

## License

MIT.
