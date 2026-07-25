# Architecture

Trascribe is a Flutter UI over a Rust engine. The two communicate via
[flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) (in
progress — see "Bridge status" below); until that's wired, the UI runs
against `RustBridgeMock`, a Dart-side stand-in with the same interface,
so UI and engine work proceed independently.

## Layout

```
lib/                      Flutter UI
  screens/                 Full-page screens (main, wizard, library, settings, player, privacy report)
  widgets/                 Reusable UI pieces (VU meter, transcript view, shortcuts panel, ...)
  state/                   Riverpod state notifiers + Dart mirrors of the Rust API types
  services/                RustBridge interface + RustBridgeMock
  theme/                   Color tokens, ThemeData

rust_core/                 Rust engine (compiled as staticlib/cdylib/lib)
  src/
    api.rs                 Public surface exposed to Dart (FRB entry point)
    audio/                  Device enumeration, ring buffer, SessionConfig/SessionMode
    vad/                    Dual-stage VAD (WebRTC gate + confirmation detector)
    stt/                    whisper-rs engine wrapper + file/batch transcription
    dedupe/                 Echo-dedupe (MIC vs SPK similarity)
    export/                 Markdown/TXT/JSON/SRT/VTT/HTML/DOCX/WAV writers
    decode/                 Symphonia decode + rubato resample (no ffmpeg)
    model.rs                Model catalog, SHA256 verification, resumable download
    session.rs              In-memory session registry, auto-split logic
    settings.rs              Settings persistence (OS config dir)
    singleton.rs             Single-instance PID lock
    memory.rs                Memory-pressure detection
    bin/gen_fixtures.rs      Synthetic WAV fixtures for hardware-free tests
    bin/trascribe_cli.rs     Power-user CLI (batch transcribe without the UI)

test/                       Flutter widget/unit tests
```

## Data flow (once the bridge is wired)

```
Dart UI  <-- Riverpod state --  RustBridge (real, FRB-generated)
                                        |
                                        v
                              rust_core::api  (Rust)
                                        |
                    +-------------------+-------------------+
                    v                   v                   v
                 audio/vad            stt (whisper-rs)     export
```

Live capture (cpal streams → ring buffer → VAD → STT queue → dedupe →
UI stream) is hardware-dependent and is exercised via manual smoke tests,
not CI — everything else (device listing, VAD decision logic, STT error
paths, export formats, model catalog/checksums, session state machine,
settings persistence, singleton lock, auto-split logic) is pure/testable
and covered by `cargo test`.

## Bridge status

`flutter_rust_bridge_codegen generate` currently fails against this
crate for two reasons, both tracked as follow-up work:

1. It doesn't propagate the `TrascribeResult<T>` type alias when scanning
   multiple modules — exposed signatures need the explicit
   `Result<T, TrascribeError>` form instead.
2. `TrascribeError::Io(std::io::Error)` has no `SseEncode` impl since
   `std::io::Error` isn't FFI-serializable — that variant needs to become
   `Io(String)`.

Do **not** run `flutter_rust_bridge_codegen integrate` against this repo —
it overwrites `lib/main.dart` with a demo stub and reformats the whole
tree. Wire the bridge manually: fix the two issues above, then
`flutter_rust_bridge_codegen generate --rust-input crate::api,crate::error,...`
scoped to the modules actually referenced by `api.rs`.

## Security posture

See [`SECURITY.md`](SECURITY.md). The short version: zero network calls
during transcription, model downloads are the only legitimate network
activity and are SHA256-verified, no telemetry by default, `cargo
audit`/`cargo deny`/`clippy -D warnings` gate every change.
