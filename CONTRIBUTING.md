# Contributing

## Setup

```bash
flutter pub get
cd rust_core && cargo build
```

Requires Flutter 3.38+, Rust 1.80+, and `cmake` on PATH (whisper.cpp is
compiled from source via `whisper-rs`).

## Before opening a PR

Both of these must pass — CI enforces the same gates:

```bash
# Rust
cd rust_core
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo audit
cargo deny check

# Flutter
cd ..
flutter analyze
flutter test
```

## Code style

- **Rust**: no `unwrap`/`expect`/`panic!` in library code — every
  fallible path returns `Result<T, TrascribeError>`. No `unsafe` without
  an inline justification comment. No `println!` in library code, use
  `tracing`. See `rust_core/src/error.rs` for the error type.
- **Dart**: Riverpod for state (`StateNotifierProvider`), no global
  mutable state outside providers. Widgets stay presentational where
  reasonable — business logic lives in notifiers.
- Prefer editing existing files over creating new ones. Don't add
  abstractions or config beyond what the current task needs.

## Testing philosophy

- Pure logic (VAD decisions, export formatting, session state machine,
  auto-split thresholds, sanitization, etc.) must be unit-tested and run
  in CI — no real hardware or network required.
- Hardware-dependent code (live audio capture threads, real device
  enumeration results) is exercised via manual smoke tests, not asserted
  on in CI, since CI runners may have zero audio devices.
- Use `rust_core/src/bin/gen_fixtures.rs` to generate synthetic WAV files
  for decode/VAD tests instead of requiring a real microphone.

## Git

- Create new commits rather than amending, unless explicitly asked to.
- Descriptive commit messages: what changed and why, not just what.
- Don't commit generated artifacts (`test/fixtures/`, `target/`,
  `build/`, `Pods/` are gitignored — check before adding new generated
  output).

## Security-sensitive changes

If your change touches networking, file I/O paths, or dependencies, see
[`SECURITY.md`](SECURITY.md) — in particular, no new code path may make a
network call during transcription, and any new dependency needs to clear
`cargo deny check` (license + advisory) before merge.
