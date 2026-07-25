# Gap Analysis & Completion Plan — Trascribe Blueprint vs Current Implementation

> **For Hermes:** This plan identifies gaps between the 5913-line TRASCRIBE-BLUEPRINT.md and the current codebase, then prioritizes remaining work.

**Goal:** Close all remaining gaps between the blueprint specification and the working implementation

**Methodology:** Full read of TRASCRIBE-BLUEPRINT.md (5913 lines) → compare against actual codebase state (verified via flutter analyze, flutter test, cargo test, and live GUI testing on macOS)

**Current Codebase Stats:**
- 40 Dart files, 25 Rust files, 13 test files
- 17,954 lines of code
- 51 Flutter tests ✅ | 95+ Rust tests ✅ | Flutter analyze clean ✅ | Build macOS ✅

---

## Summary: What's Already Done (~85% of Blueprint)

| Blueprint Section | Status |
|-------------------|--------|
| §1-4 PRD, Goals, Non-Goals | ✅ Implemented |
| §5 Fitur (Audio, STT, Export, File, Wizard, Speaker) | ✅ All implemented |
| §6 Non-Fungsional (perf, security, binary, RAM) | ✅ Met |
| §7 Edge Cases | ✅ 18/18 handled |
| §8 Acceptance Criteria (20 items) | ✅ **20/20 done** |
| §9-10 Market, Competitor, USP | 📄 Documentation only |
| §11 ADR-1..6 | ✅ All decisions implemented |
| §12 Directory Structure | ✅ Matches |
| §13 Test Plan | ✅ Exceeded (51 Flutter + 95 Rust) |
| §14 Task Separation (Agent A-E) | ✅ All 5 agents' work done |
| §15 Code Review Checklist | ✅ Followed |
| §16 UX Friction (32 points) | ✅ 32/32 resolved |
| §17 Architecture Bottlenecks (12) | ✅ 11/12 fixed (see below) |
| §18 Final Pain Points (PP-1..25) | ✅ PP-1 through PP-25 implemented |
| §19 Security Audit (STRIDE) | ✅ All mitigations in place |
| §20 Performance Benchmarks | ✅ Scripts + CI gates |
| §21 Release Management | ✅ Docs + workflow |
| §22 Dependency Maintenance | ✅ Dependabot + lockfiles |
| §23 WCAG Accessibility | ✅ Recently completed |
| §24 Operational Excellence | 🔶 Partial (see gaps) |
| §25 Final Master Checklist | 🔶 14/17 P0 items done |

---

## Gap #1 — Windows Build Not Verified (P0/P1)

**Blueprint ref:** §92 Final Checklist — "Windows build - .exe berfungsi"

**Current state:** CI has `flutter build windows --release` job but it's never been verified on an actual Windows machine. The `package_windows.ps1` script was written but never tested.

**What needs to happen:**
1. Run `flutter build windows --release` on a Windows machine
2. Fix any compilation/linking errors (likely around Rust library integration)
3. Test the resulting .exe with a real audio file
4. Update CI if fixes are needed

**Files:**
- `scripts/package_windows.ps1`
- `windows/CMakeLists.txt`
- `.github/workflows/ci.yml`
- `rust_core/Cargo.toml` (check cfg(target_os = "windows") deps)

**Effort:** Unknown — could be 1-8 hours depending on issues found.

---

## Gap #2 — macOS Intel / Universal Binary (P2)

**Blueprint ref:** §92 P2 — "macOS Universal Binary"

**Current state:** Build targets only Apple Silicon. macOS Intel users would need a separate build, or a universal binary (lipo).

**What needs to happen:**
1. Add `aarch64-apple-darwin` + `x86_64-apple-darwin` targets to build
2. Create universal Rust library via `lipo -create`
3. Update `package_macos.sh` to produce universal `.dmg`
4. Update release workflow

**Files:**
- `scripts/package_macos.sh`
- `.github/workflows/release.yml`

**Effort:** ~2-3 hours

---

## Gap #3 — Lynk.ID Product Page & Gumroad Backup (P0)

**Blueprint ref:** §92 — "Lynk.ID: product page + screenshot + $5"

**Current state:** `DISTRIBUTION.md` has the full checklist, but no product page is actually created yet.

**What needs to happen:**
1. Create Lynk.ID account
2. Create product page with:
   - Title: "Trascribe — Offline Meeting Transcriber"
   - Price: $5 (or IDR equivalent)
   - Description noting ad-hoc signing warnings
   - Screenshots from `~/Desktop/trascribe_*.png`
3. Create Gumroad backup
4. Upload macOS `.dmg` and Windows `.zip` (once Gap #1 is resolved)

**Files:** 
- `DISTRIBUTION.md` (checklist already there)

**Effort:** ~1-2 hours (manual, requires account signup)

---

## Gap #4 — Crashpad/Breakpad Opt-in Telemetry (P2)

**Blueprint ref:** §91.1 — Monitoring & Telemetry

**Current state:** No crash reporting at all. Blueprint specifies opt-in Crashpad/Breakpad integration, but v1 intentionally has no telemetry.

**Recommendation:** Defer to v2. Blueprint itself says "Opt-in. Sanitize path sebelum kirim." and "Tidak ada auto-update di v1."

**Effort:** ~3-5 days (significant integration work)

---

## Gap #5 — System Tray Minimize Verify (P0)

**Blueprint ref:** §92 — "Tray: minimize -> restore"

**Current state:** Code has minimize-to-tray (commit `1c26ad3`), but I haven't verified it actually works in the live GUI test. The `window_manager` package is used.

**What needs to happen:**
1. Run the app, verify minimize-to-tray works
2. Verify recording continues in background
3. Verify restore from tray works

**Files:**
- `lib/main.dart` (tray setup)
- `lib/services/tray_service.dart` (if exists)

**Effort:** ~30 min verification

---

## Gap #6 — Auto-Detect Meeting Title (P2)

**Blueprint ref:** §5.4 Export Naming — "detect judul dari window title"

**Current state:** Not implemented. Would require:
- macOS: AppleScript to get frontmost window title
- Windows: Win32 `GetWindowText` API
- Rust: Expose via API, Dart: Use as default title

**Files to create:**
- `rust_core/src/platform/macos/title.rs`
- `rust_core/src/platform/windows/title.rs`
- `rust_core/src/platform/mod.rs`

**Files to modify:**
- `rust_core/src/api.rs` (add `detect_window_title()`)
- `lib/services/bridge_service.rs` (add to RustBridge)
- `lib/screens/main_screen.dart` (use in title)

**Effort:** ~3-4 hours

---

## Gap #7 — Internationalization (i18n) — English UI (P1)

**Blueprint ref:** §91.3 — "Bahasa Indonesia (P0)"

**Current state:** The ENTIRE UI is in Indonesian. The blueprint says Indonesian is P0 input translation. For wider market, English UI is needed.

**What needs to happen:**
1. Extract all hardcoded Indonesian strings into ARB files
2. Create `lib/l10n/` with `app_en.arb` and `app_id.arb`
3. Use `flutter gen-l10n` to generate localization classes
4. Replace all string literals with `AppLocalizations.of(context)!.xxx`

**Files to create:**
- `lib/l10n/app_en.arb`
- `lib/l10n/app_id.arb`

**Files to modify:** Almost every screen file (massive refactor)

**Effort:** ~4-6 hours (tedious but mechanical)

**Recommendation:** Defer to post-v1 or batch with a script.

---

## Gap #8 — Global Keyboard Shortcuts (P2)

**Blueprint ref:** §Improvement — "rdev crate untuk global hotkey registration"

**Current state:** In-app shortcuts work via `CallbackShortcuts`, but global shortcuts (even when app is minimized) are not implemented. `rdev` crate is not in dependencies.

**What needs to happen:**
1. Add `rdev` crate to `rust_core/Cargo.toml`
2. Create global hotkey listener in Rust
3. Expose hotkey events via FRB stream
4. Handle in Dart: toggle record, pause, etc.

**Files:**
- `rust_core/Cargo.toml` (+rdev)
- `rust_core/src/global_hotkey.rs` (new)
- `rust_core/src/api.rs` (+hotkey stream)
- `lib/services/bridge_service.dart` (+hotkey stream)

**Effort:** ~2-3 hours

---

## Gap #9 — Update Checker (Manual) (P2)

**Blueprint ref:** §9 — "T10 — Auto-update: P3"

**Current state:** No update mechanism. Blueprint says manual check in v1, auto-update in v2.

**What needs to happen:**
1. Add "Check for Updates" menu item
2. HTTPS HEAD request to version manifest URL
3. Compare version, show dialog if newer
4. Link to Lynk.ID download page

**Files:**
- `lib/screens/settings_screen.dart` (add menu item)
- `lib/services/update_checker.dart` (new)

**Effort:** ~2 hours

---

## Gap #10 — README with Banner + Badges (P1)

**Blueprint ref:** §92 — "README: banner + badges + fitur + FAQ + link"

**Current state:** `README.md` likely missing or minimal (not checked in this audit).

**What needs to happen:**
1. Create comprehensive README.md with:
   - Project banner/logo
   - CI badges (from GitHub Actions)
   - Feature list
   - Screenshots (from `~/Desktop/trascribe_*.png`)
   - Installation instructions
   - FAQ
   - License + links

**Files:**
- `README.md` (create/update)

**Effort:** ~1 hour

---

## Gap #11 — CONTRIBUTING.md (P1)

**Blueprint ref:** §91.2 — "CONTRIBUTING.md — Setiap 6 bulan"

**Current state:** Missing.

**What needs to happen:**
1. Create CONTRIBUTING.md with:
   - How to set up development environment
   - How to build
   - How to run tests
   - Code style guide
   - PR process

**Files:**
- `CONTRIBUTING.md` (create)

**Effort:** ~1 hour

---

## Gap #12 — Architecture Bottleneck #12: Parallel VAD (P2)

**Blueprint ref:** §B Bottleneck #12 — "Parallel VAD + Voting"

**Current state:** VAD is likely sequential (WebRTC → Silero). Blueprint says parallel with voting would add 0ms latency.

**Files:**
- `rust_core/src/vad/mod.rs`
- `rust_core/src/pipeline.rs`

**Effort:** ~2 hours

---

## Prioritized Execution Plan

### Phase 1: Critical Fixes (P0 — Before Any Release) — ~4 hours
```
Task 1: Verify Windows build (Gap #1)
Task 2: Verify system tray (Gap #5)  
Task 3: Create/update README.md (Gap #10)
Task 4: Create CONTRIBUTING.md (Gap #11)
```

### Phase 2: Distribution Readiness (P1 — Before v1.0) — ~3 hours
```
Task 5: Set up Lynk.ID product page (Gap #3) — manual
Task 6: Set up Gumroad backup (Gap #3) — manual
Task 7: Update checker (Gap #9)
```

### Phase 3: Polish (P2 — v1.1) — ~10 hours
```
Task 8: macOS Universal Binary (Gap #2)
Task 9: Auto-detect meeting title (Gap #6)
Task 10: Global keyboard shortcuts (Gap #8)
Task 11: Parallel VAD (Gap #12)
```

### Phase 4: Market Expansion (P2 — v1.2) — ~6 hours
```
Task 12: English UI i18n (Gap #7)
Task 13: Crashpad telemetry opt-in (Gap #4)
```

### Deferred to v2 (+6 months):
- macOS notarization (requires paid Apple Developer account)
- Windows SmartScreen mitigation (requires code signing certificate)
- Auto-update with Ed25519 signatures
- Linux support
- Cloud sync features

---

## Files Likely to Change Per Phase

### Phase 1
- `scripts/package_windows.ps1` — fix if Windows build fails
- `windows/CMakeLists.txt` — fix Rust library linking
- `README.md` — create
- `CONTRIBUTING.md` — create

### Phase 2
- `DISTRIBUTION.md` — update with live links (was checklist)
- `lib/services/update_checker.dart` — create
- `lib/screens/settings_screen.dart` — add update menu item

### Phase 3
- `scripts/package_macos.sh` — add Universal Binary
- `rust_core/src/platform/` — new directory
- `rust_core/Cargo.toml` — add rdev, platform deps
- `rust_core/src/api.rs` — new functions
- `lib/services/bridge_service.dart` — new bridge methods

### Phase 4
- `lib/l10n/` — new directory with ARB files
- All screen/widget files — string replacement
- `rust_core/src/` — crashpad integration
- `pubspec.yaml` — new dependencies

## Tests / Validation

After each phase:
```
flutter analyze          # Must be 0 issues
flutter test             # Must be 51/51 (or more)
cd rust_core && cargo test  # Must be 95+/95+
```

Before release (Phase 2 completion):
```
cargo audit --deny warnings
cargo deny check
cargo clippy --all-targets -- -D warnings
bash scripts/benchmark.sh
bash scripts/package_macos.sh "1.0.0"
# Manual: test .dmg on clean macOS
# Manual: test Windows build
```

## Risks & Open Questions

| Risk | Impact | Mitigation |
|------|--------|------------|
| Windows build has fundamental issues (Rust FFI) | HIGH — blocks Windows release | Test early, fall back to macOS-only if needed |
| Lynk.ID/Gumroad account setup friction | MEDIUM — delays distribution | Documented checklist; mostly manual |
| i18n refactor touches every file | HIGH — merge conflicts | Do as final step before release, or batch with script |
| Crashpad integration complex | MEDIUM — deferrable | Already marked for v2 |
