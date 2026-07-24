# Security Policy — Trascribe

## Core Privacy Guarantee

Trascribe performs 100% offline speech-to-text. During any active transcription
(live capture or file transcription), the application makes **zero network
calls**. The only network activity that ever occurs is:

- Downloading an optional Whisper model the user explicitly selects (HTTPS,
  checksum-verified with a SHA256 bundled in the binary).

There is no telemetry, no analytics, and no crash reporting enabled by
default. Any future opt-in diagnostics will be documented here before
release and will never transmit audio or transcript content.

## Reporting a Vulnerability

If you find a security issue (memory safety bug, path traversal, unsafe
deserialization, dependency vulnerability, etc.), please report it privately
rather than opening a public issue:

- Open a [GitHub Security Advisory](https://github.com/Trareon-com/Transcribe/security/advisories/new)
  on this repository, or
- Email the maintainer directly (see repository profile) with details and,
  if possible, a reproduction.

We aim to acknowledge reports within 72 hours. Fix timelines follow severity:

| Severity | Target fix time |
|---|---|
| Critical (RCE, data exfiltration, network-call regression) | 24–48h |
| High | 7 days |
| Medium | 30 days |
| Low | Next scheduled release |

## Supported Versions

Only the latest released version receives security fixes while the project
is pre-1.0.

## Development Practices

- `cargo audit` and `cargo deny` run on every pull request; a HIGH+ severity
  advisory or license violation blocks merge.
- `cargo clippy -- -D warnings` and `flutter analyze` must be clean before
  merge.
- No `unsafe` Rust without an inline justification comment.
- No `unwrap`/`expect`/`panic!` in library code — all fallible paths return
  `Result<T, TrascribeError>`.
- Dependencies are kept current via Dependabot (weekly); `Cargo.lock` and
  `pubspec.lock` are committed and never deleted.
- This policy is reviewed at least every 6 months.

Last reviewed: 2026-07-25.
