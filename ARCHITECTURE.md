# Architecture

Trascribe is a Flutter UI over a Rust engine, connected via
[flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) (FRB) V2.
`RustEngineBridge` (`lib/services/bridge_service.dart`) is the real,
FRB-generated bridge and is the default; `RustBridgeMock` is a timer-driven
stand-in still used by widget tests (and available for UI work without a
live Rust build).

## Layout

```
lib/                      Flutter UI
  screens/                 Full-page screens (main, wizard, library, settings, player, privacy report)
  widgets/                 Reusable UI pieces (VU meter, transcript view, shortcuts panel, ...)
  state/                   Riverpod state notifiers + Dart mirrors of the Rust API types
  services/                RustBridge interface, RustEngineBridge (real), RustBridgeMock, native library loader
  src/rust/                 flutter_rust_bridge-generated Dart bindings — do not hand-edit
  theme/                   Color tokens, ThemeData

rust_core/                 Rust engine (compiled as staticlib/cdylib/lib)
  src/
    api.rs                 Public surface exposed to Dart (FRB entry point)
    frb_generated.rs        flutter_rust_bridge-generated glue — do not hand-edit
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

## Data flow

```
Dart UI  <-- Riverpod state --  RustEngineBridge (FRB-generated bindings, lib/src/rust/)
                                        |
                                        v
                              rust_core::api  (Rust, via FFI)
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
and covered by `cargo test`. `transcriptStream`/`vuMeterStream` on
`RustEngineBridge` are currently stubs (`Stream.empty()`) since `api.rs`
doesn't expose a streaming surface yet — that lands with the live capture
thread wiring.

## Bridge status: connected

FRB codegen is wired and verified end-to-end (real `.dylib`, real Dart
bindings, app launches and calls into Rust without crashing). Getting here
required two fixes to `rust_core/src/error.rs`:

1. `TrascribeResult<T>` type alias isn't resolved by FRB when scanning
   multiple modules — every FRB-exposed signature spells out
   `Result<T, TrascribeError>` explicitly instead. The alias still exists
   for internal-only code.
2. `TrascribeError::Io` changed from `std::io::Error` (no FFI codec) to
   `String`, with a manual `From<std::io::Error>` impl so
   `.map_err(TrascribeError::from)` still works at every call site.

Internal-only items not meant for the Dart surface (`RingBuffer`,
`decode::decode_audio_file`/`resample_to_target` which take `&Path`,
`model.rs`'s `&Path`-based helpers, `export::export_segments`/`write_wav`)
are marked `#[flutter_rust_bridge::frb(ignore)]` — `api.rs` wraps each of
them with a `String`-based signature that Dart actually calls.

Regenerate bindings after any FRB-exposed signature changes:

```bash
flutter_rust_bridge_codegen generate \
  --rust-input crate::api,crate::error,crate::audio,crate::decode,crate::export,crate::model,crate::session,crate::settings \
  --rust-root rust_core \
  --dart-output lib/src/rust \
  --dart-entrypoint-class-name RustLib
flutter pub run build_runner build --delete-conflicting-outputs   # freezed unions (e.g. AutoSplitReason)
```

Do **not** run `flutter_rust_bridge_codegen integrate` against this repo —
it overwrites `lib/main.dart` with a demo stub and reformats the whole
tree. Always use the scoped `generate` command above.

### Native library loading (temporary, needs a real build phase)

`lib/services/rust_library_loader.dart` resolves the compiled
`librust_core.dylib`/`rust_core.dll`/`librust_core.so` at runtime by
searching a few candidate paths (the app bundle's `Frameworks/` folder,
then `rust_core/target/{release,debug}/` relative to the executable for
dev runs). This is a stand-in for a proper build-system step — normally
`flutter_rust_bridge_codegen integrate`'s cargokit machinery adds an Xcode
"Run Script" build phase (macOS) / CMake step (Windows) that builds the
Rust library and copies it into the app bundle automatically. That
automation hasn't been added because `integrate` is destructive against
this project's structure (see above), and hand-editing the generated
`.xcodeproj`/`.pbxproj` blindly (no Xcode GUI available in this
environment) is riskier than shipping the explicit-path loader.

**To run the app locally right now:**

```bash
cd rust_core && cargo build --release --lib
# macOS — copy the dylib into the built app bundle:
mkdir -p ../build/macos/Build/Products/Debug/trascribe.app/Contents/Frameworks
cp target/release/librust_core.dylib \
   ../build/macos/Build/Products/Debug/trascribe.app/Contents/Frameworks/
```

**Follow-up work** (tracked, not yet done): add a real Xcode "Run Script"
build phase to `macos/Runner.xcodeproj` (via Xcode GUI, not blind text
edits) that runs `cargo build --release --manifest-path=../../rust_core/Cargo.toml`
and copies `librust_core.dylib` into `$BUILT_PRODUCTS_DIR/$FRAMEWORKS_FOLDER_PATH/`
as part of every build; equivalent CMake step for `windows/CMakeLists.txt`
producing `rust_core.dll` next to the built `.exe`. This is the same
scope of work cargokit automates, done safely by hand instead of via the
destructive `integrate` command.

## Security posture

See [`SECURITY.md`](SECURITY.md). The short version: zero network calls
during transcription, model downloads are the only legitimate network
activity and are SHA256-verified, no telemetry by default, `cargo
audit`/`cargo deny`/`clippy -D warnings` gate every change.
