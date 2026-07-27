# Distribution — Trareon Transcribe

## Pricing & Channel

- **License**: MIT (source) + binary for $5 via Lynk.ID
- **Primary channel**: [Lynk.ID](https://lynk.id) — Indonesian payment gateway
- **Backup channel**: [Gumroad](https://gumroad.com) — international coverage
- **Source code**: Public on GitHub (MIT) at `github.com/Trareon-com/Transcribe`

## Binary Builds

Two packaging scripts produce ready-to-distribute installers:

| Platform | Script | Output | Bundle details |
|----------|--------|--------|----------------|
| macOS | `scripts/package_macos.sh` | `.dmg` | Ad-hoc signed (`codesign --sign -`), whisper `tiny` model bundled |
| Windows | `scripts/package_windows.ps1` | `.zip` | Self-signed certificate (v1), whisper `tiny` model bundled |
| Linux | `scripts/package_linux.sh` | `.AppImage` (or `.tar.gz` fallback) | Unsigned, `base` model bundled |

Both scripts:
1. Build Rust engine (`cargo build --release --lib`)
2. Build Flutter (`flutter build macos --release` / `flutter build windows --release`)
3. Generate SHA256 checksum file
4. Output to `dist/`

Run from the repo root:
```bash
# macOS
bash scripts/package_macos.sh "1.0.0"

# Windows (PowerShell)
.\scripts\package_windows.ps1 -Version "1.0.0"

# Linux (AppImage, falls back to tar.gz if appimagetool is missing)
bash scripts/package_linux.sh "1.0.0"
```

## CI & Release Workflow

Trareon Transcribe's CI pipeline (GitHub Actions) runs on every push and pull request:
- **Rust**: `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test`, `cargo audit`, `cargo deny`
- **Flutter**: `flutter analyze`, `flutter test`, builds for macOS/Windows/Linux  
- **Smoke tests**: macOS DMG and Windows ZIP packaging verified on every push

CI status: [![CI](https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml/badge.svg)](https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml)

Pushing a `v*` tag triggers `.github/workflows/release.yml`:
1. Source tarball (GitHub Releases — for transparency, no binaries)
2. macOS `.dmg` (binary via Lynk.ID)
3. Windows `.zip` (binary via Lynk.ID)
4. Linux `.AppImage` (binary via Lynk.ID)

## Signing Status (v1)

| Requirement | macOS | Windows | Linux |
|-------------|-------|---------|-------|
| Code signing | ✅ Ad-hoc (`codesign --sign -`) | 🔶 Self-signed (makecert) | — |
| Notarization | ❌ (requires $99/yr Apple Developer) | N/A | N/A |
| Gatekeeper warning | ⚠️ "Apple cannot verify" | N/A | N/A |
| SmartScreen warning | N/A | ⚠️ "Unrecognized app" | N/A |
| User documentation | ✅ Described on download page | ✅ Described on download page | ✅ Described on download page |

**Why ad-hoc / self-signed?** The blueprint ADR-12 defers paid certificates to
post-v1. Users see one warning dialog on first launch; subsequent launches are
silent (macOS Gatekeeper remembers the user's "Open Anyway" choice; Windows
SmartScreen learns after enough reputation).

## Lynk.ID Product Page Checklist

- [ ] Title: "Trareon Transcribe — Offline Meeting Transcriber"
- [ ] Price: $5 (or IDR equivalent)
- [ ] Description mentions:
  - 100% offline, zero network calls during transcription
  - macOS + Windows support
  - **Important**: ad-hoc signing warning for macOS ("Apple cannot verify")
  - **Important**: SmartScreen warning for Windows
  - Whisper model `tiny` bundled (larger models downloaded on-demand)
  - All export formats: Markdown, TXT, JSON, SRT, VTT, HTML, DOCX, WAV
- [ ] Known limitations listed:
  - No notarization (macOS)
  - No auto-update (manual check only in v1)
  - Large model downloads require internet on first use
- [ ] Link to GitHub source (MIT)
- [ ] Link to documentation / user guide

## Manual Release Steps

```bash
# 1. Tag and push
git tag -a v1.0.0 -m "v1.0.0 — initial release"
git push origin v1.0.0

# 2. CI builds automatically (watch Actions tab)

# 3. Download artifacts from CI, verify checksums
sha256sum -c transcribe-*.sha256

# 4. Upload to Lynk.ID + Gumroad

# 5. Create GitHub Release (source only)
# CI creates this automatically via softprops/action-gh-release

# 6. Update CHANGELOG.md if not already done

# 7. Post-release bump: pubspec.yaml version → 1.1.0-dev
```

## Model Bundling

The `tiny` model (~75 MB) is bundled inside each installer so first-run
download is optional. User-chosen larger models (small/medium/large-v3-turbo)
are downloaded on-demand via HTTPS with SHA256 verification.

Model cache location: `~/Library/Caches/TrareonTranscribe/models/` (macOS) /
`%LOCALAPPDATA%\TrareonTranscribe\models\` (Windows).

## Update Strategy (v1)

- **No auto-update.** User checks manually via Help → Check for Updates.
- Update checker uses HTTPS HEAD request to a version manifest URL.
- Full auto-update with Ed25519 binary signature is roadmap for v2.

## Hotfix Protocol

1. Branch: `hotfix/v1.0.1` from tag `v1.0.0`
2. Fix, commit, test
3. Tag: `git tag v1.0.1`
4. Target: 24-hour turnaround for critical bugs
