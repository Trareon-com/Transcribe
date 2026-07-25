# Document Audit — Remaining Work

> **For Hermes:** This plan identifies every unfinished item across all project documents.

**Goal:** Close all remaining gaps between current state and "release ready"

**Method:** Cross-reference CHECKLIST.md, CHANGELOG.md, DISTRIBUTION.md, git status, and GitHub Actions CI

---

## Summary: Current State

| Gate | Status | Detail |
|------|--------|--------|
| Flutter analyze | ✅ Clean | No issues |
| Flutter test | ✅ 51/51 | All passed |
| Rust test | ✅ All passed | 100+ tests |
| Build macOS | ✅ Debug + Release | Working |
| CI Run #66 | 🔄 In progress | Action version upgrades |
| Uncommitted work | ⚠️ 18+8 files | Not pushed to GitHub |

---

## Gap #1: Uncommitted Changes (P0 — MUST PUSH)

**18 modified files + 8 new files** from this session are sitting locally:

**Modified (18):**
```
CONTRIBUTING.md, README.md, main_screen.dart, settings_screen.dart,
bridge_service.dart, session_model.dart, AppDelegate.swift, api.rs,
lib.rs, vad/mod.rs, package_macos.sh, package_windows.ps1,
CMakeLists.txt, test/main_screen_recovery_test.dart,
test/session_model_test.dart, test/settings_screen_test.dart,
test/setup_wizard_test.dart, test/widget_test.dart
```

**New/untracked (8):**
```
.hermes/plans/, VERSION, global_hotkey_service.dart,
update_checker.dart, rust_core/src/platform/
```

**Task 1: Commit and push everything**

```bash
git add -A
git commit -m "feat: complete remaining blueprint gaps

- Parallel VAD with thread::scope + voting
- macOS Universal Binary build (lipo x86_64+arm64)
- Global keyboard shortcuts via macOS event monitor
- Meeting title auto-detect via AppleScript
- Manual update checker with VERSION manifest
- English i18n foundations
- README.md + CONTRIBUTING.md comprehensive docs
- WCAG accessibility on all widgets
- Windows build CI + packaging fixes"
git push origin main
```

**Verify:** CI Run #67 triggers automatically, should show green with 0 warnings.

---

## Gap #2: CI Run #66 Verification (P0)

**Current:** Run #66 is "In progress" with the action version upgrades
(`actions/checkout@v7`, `upload-artifact@v7`, `rust-cache@v2.9.1`, `flutter-action@v2.23.0`)

**Task 2: Check Run #66 results**

1. Wait for Run #66 to complete
2. Verify: 0 errors, 0 Node.js 20 deprecation warnings
3. If Run #66 shows green → Gap #2 closed
4. If still failing → investigate and fix

---

## Gap #3: Lynk.ID Product Page (P0 — MANUAL)

**From CHECKLIST.md:** `[ ] Lynk.ID product page live with description`

**From DISTRIBUTION.md:** Full checklist exists but page not created

**Task 3: Create Lynk.ID product page** (manual — requires account signup)

1. Sign up at Lynk.ID
2. Create product with:
   - Title: "Trascribe — Offline Meeting Transcriber"
   - Price: $5 (IDR equivalent)
   - Screenshots: use images from `~/Desktop/trascribe_*.png`
   - Description: 100% offline, zero network calls, macOS+Windows
   - Known limitations: ad-hoc signing, SmartScreen warning
3. Upload macOS `.dmg` and Windows `.zip`
4. Update `DISTRIBUTION.md` with live URL
5. Mark `CHECKLIST.md` item as done

---

## Gap #4: Gumroad Backup Channel (P1 — MANUAL)

**From CHECKLIST.md:** `[ ] Gumroad backup channel set up`

**Task 4: Set up Gumroad** (manual)

1. Sign up at Gumroad
2. Create matching product page
3. Upload same binaries
4. Update `DISTRIBUTION.md` with backup URL

---

## Gap #5: Live Audio Hardware Validation (P1 — MANUAL)

**From CHANGELOG.md:** "Live audio capture still needs real hardware validation"

**Task 5: Test end-to-end with real mic+speaker**
1. Run the app on a Mac with microphone
2. Click "Mulai" (Start)
3. Verify: VU meter moves, transcript appears
4. Verify: mic toggle works
5. Verify: speaker toggle (loopback) captures system audio
6. Fix any issues found

---

## Gap #6: macOS Notarization (P2 — Deferred)

**From CHECKLIST.md:** Not explicitly listed but implied by "Code signing verified"

**Status:** Deferred to post-v1 — requires $99/yr Apple Developer account

**Document in DISTRIBUTION.md:** Already done ✅

---

## Files Summary

| File | Action | Reason |
|------|--------|--------|
| All 18 modified + 8 new files | `git add -A && git commit && git push` | Not yet in remote |
| `DISTRIBUTION.md` | Update after Lynk.ID page created | Add live URL |
| `CHECKLIST.md` | Mark Lynk.ID/Gumroad items ✅ | After pages go live |

## Validation After Push

```
flutter analyze          # Must be 0 issues
flutter test             # Must be 51/51
cd rust_core && cargo test  # Must be all pass
```

CI will auto-run on push. Watch https://github.com/Trareon-com/Transcribe/actions for Run #67.
