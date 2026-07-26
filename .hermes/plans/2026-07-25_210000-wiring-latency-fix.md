# Transcribe — Wiring, Latency & Cross-Platform Fix Plan

> **For Hermes:** Use subagent-driven-development to implement this plan task-by-task.

**Goal:** Fix the Flutter↔Rust bridge wiring so the UI actually displays live transcription data, reduce latency to 3-5s, and ensure cross-platform (macOS + Windows + Linux) functionality.

**Architecture:**
The current data flow has multiple silent-failure points:
```
Flutter UI ← Riverpod StreamProvider ← RustEngineBridge._poll() (100ms Timer)
    → rust_session.pollEvents() FRB call ← Rust SessionState.pending_events
    ← AudioCapture ← cpal input (mic) / loopback (speaker)
```

**Key problems identified:**
1. `_poll()` swallows ALL errors (`on Object catch (_)`) — any failure is invisible
2. VU meter uses `vuLevelProvider` (StreamProvider) but SessionNotifier now also has `micLevel/speakerLevel` — dual path causes confusion
3. `start()` checks `File(state.config.modelPath).existsSync()` — model path is like `models/ggml-tiny.bin` which is relative, not absolute, so this check ALWAYS fails with `RustEngineBridge`
4. `_resolveDevices()` calls `listOutputAudioDevices()` which might not exist on the Rust side
5. Polling timer at 100ms might be too frequent and cause cascading drops via the `_polling` re-entrancy guard
6. No `start_capture()` on Rust side when `device_name` is `None` (treated as "setup not completed")
7. SessionConfig's `mic_device_id` defaults to `None` on Rust side

**Tech Stack:** Flutter 3.27+, Rust 1.80+, flutter_rust_bridge 2.12, cpal, symphonia, whisper-rs

---

## Task 1: Fix `start()` Model Path Check

**Objective:** The model path check `File(state.config.modelPath).existsSync()` uses a relative path like `models/ggml-tiny.bin`, which never exists relative to the running app's cwd. This causes `start()` to always throw `StateError` when using `RustEngineBridge`.

**Files:**
- Modify: `lib/state/session_model.dart:152-157`

**The fix:**
Replace the simple existence check with a smarter one that:
1. Tries the path as-is first
2. If not found, tries `libraryPath + '/' + modelPath` (the Rust-side resolved path)
3. If still not found, tries the known cache locations
4. If all fail, show the error to the user rather than crashing silently

**Step 1:** Read `lib/state/session_model.dart` around line 152
**Step 2:** Read `lib/state/models.dart` to understand `modelPathForId` and `AppSettings`
**Step 3:** Modify the model check to be more robust — check multiple possible locations
**Step 4:** Test with `flutter test` — ensure all 47 tests pass
**Step 5:** Test with real Rust build — verify session starts without "Model tidak ditemukan" error

---

## Task 2: Fix `_resolveDevices()` — Device Name Resolution

**Objective:** `start()` calls `_resolveDevices()` which queries `listOutputAudioDevices()`. But on first run without a setup wizard completion, device lists may be empty or the Rust function may not be exposed via FRB. This causes `startSession` to receive `None` device ids, causing the Rust side to skip capture entirely.

**Files:**
- Modify: `lib/state/session_model.dart:200-230` (`_resolveDevices`)
- Modify: `lib/services/bridge_service.dart` (add `listOutputAudioDevices` import)

**The fix:**
1. For mic: use `listAudioDevices()` (already working) to find the default input
2. For speaker: use `listOutputAudioDevices()` but with a graceful fallback — if it fails or returns empty, try `listAudioDevices()` and find a device named "BlackHole" or "loopback"
3. If ALL device queries fail, still proceed with `None` device ids (the Rust side handles this gracefully by returning `Ok(None)` from `start_capture()`)

---

## Task 3: Fix VU Meter — Eliminate Dual Path Confusion

**Objective:** There are TWO paths for VU levels:
1. `vuLevelProvider` (StreamProvider) — populated by `RustEngineBridge._poll()` every 100ms
2. `SessionUiState.micLevel/speakerLevel` — populated by `SessionNotifier._onVuLevel()` via `_vuSub`

The VU meter widget watches path #1 (`vuLevelProvider`), but the SessionNotifier path #2 is redundant. Having both is confusing and may cause stale data.

**Files:**
- Modify: `lib/state/session_model.dart` — remove `micLevel`/`speakerLevel` from `SessionUiState`, remove `_vuSub`
- Modify: `lib/widgets/vu_meter.dart` — keep using `vuLevelProvider` (already correct)

**The fix:**
1. Remove `micLevel`, `speakerLevel`, `averageConfidence` from `SessionUiState`
2. Remove `_vuSub` from `SessionNotifier`
3. Remove `copyWith` params for micLevel/speakerLevel
4. Keep `vuLevelProvider` as the single source of truth for VU data

---

## Task 4: Fix `_poll()` Error Handling — Stop Swallowing Errors

**Objective:** `_poll()` catches ALL errors silently (`on Object catch (_) {}`), making it impossible to debug when events aren't flowing.

**Files:**
- Modify: `lib/services/bridge_service.dart:222-254`

**The fix:**
```dart
} on Object catch (e) {
  // Log the error so developers can see when polling fails
  // eslint-disable-next-line no-console
  debugPrint('RustBridge._poll error: $e');
  // Only swallow specific expected errors (session shutdown races)
  // Unexpected errors should propagate during development
} finally {
  _polling.remove(sessionId);
}
```

Also reduce the polling interval from 100ms to 200ms to reduce CPU pressure while keeping responsiveness at <1 frame (200ms < 16ms * 12 = 192ms ≈ fine).

```dart
_pollTimers[id] = Timer.periodic(const Duration(milliseconds: 200), (_) => _poll(id));
```

---

## Task 5: Verify Rust `poll_events()` Returns Data

**Objective:** Confirm that the Rust side actually produces events when a session is running. If `poll_events()` returns empty Vec constantly, the frontend will never get data regardless of wiring fixes.

**Test approach:**
Create a small Rust binary test (similar to `device_probe.rs` already in `src/bin/`) that:
1. Starts a session with `mic_enabled: true`
2. Sleeps 5 seconds  
3. Calls `poll_events()` in a loop
4. Prints events received

**Files:**
- Create: `rust_core/src/bin/poll_probe.rs` (temporary test binary)

**Verification:**
```bash
cd rust_core && cargo run --bin poll_probe
```

If `poll_events()` returns data, the Rust pipeline works. If not, the bug is in `session.rs`'s `collect_worker_events()` or the shared `registry()` mutex.

---

## Task 6: Verify Rust `AudioCapture.start()` Works with Real Hardware

**Objective:** The `AudioCapture::start()` function runs on a dedicated thread and signals readiness via `ready_tx`. But the `SessionConfig.mic_device_id` defaults to `None`, which causes `start_capture()` in `session.rs` to return `Ok(None)` — the capture thread is NEVER spawned.

**Files:**
- Modify: `lib/state/session_model.dart` (ensure device IDs are populated from wizard)
- Read: `rust_core/src/session.rs` lines 122-143 (`start_capture`)

**The fix:**
When the user clicks "Mulai" (Start) on the main screen:
1. The wizard should have already set `mic_device_id` and `speaker_device_id` in the session config
2. If not set, use the system default input device name
3. Call `cpal::default_host().default_input_device()?.name()` to get the actual device name
4. Pass it as `mic_device_id`

On the Rust side, ensure `start_capture()` logs when it skips capture due to `None` device_id:
```rust
if !enabled || device_name.is_none() {
    tracing::warn!("start_capture({source}): skipping — enabled={enabled}, device=None");
    return Ok(None);
}
```

---

## Task 7: Latency Optimization — Reduce Chunk Size & Increase Poll Rate

**Objective:** Current latency is ~30s (CHUNK_SECS=30). Already changed to 5s in `ring_buffer.rs` but other factors affect perceived latency.

**Files:**
- Already modified: `rust_core/src/audio/ring_buffer.rs` (CHUNK_SECS=5, OVERLAP_SECS=1)
- Modify: `lib/services/bridge_service.rs:183` (poll timer from 100ms → 200ms for CPU efficiency, not latency)
- Verify: `rust_core/src/audio/ring_buffer.rs` — ensure chunk readiness check doesn't add extra delay

**Latency budget:**
```
Audio capture (cpal callback) → 0-10ms buffer accumulation
Ring buffer fill (5s chunk)  → 5000ms
VAD process (WebRTC)         → ~5ms
Whisper inference (tiny)     → ~500-1500ms  
FRB poll (200ms)             → ~100ms avg
UI render                     → ~16ms (60fps)
──────────────────────────────────────
Total: ~5.6-6.5s
```

This is under the 3-5s target for tiny model. For larger models, chunk could be 3s instead.

**Optional:** Add a `partial` flag to early-output whisper segments while still processing the full chunk (streaming mode). This requires whisper-rs API support.

---

## Task 8: Linux Platform — Complete Loopback Implementation

**Objective:** The current Linux loopback uses `ffmpeg` or `parec` subprocess. For an optimal experience without external deps, implement native PulseAudio monitor capture.

**Files:**
- Modify: `rust_core/src/audio/loopback.rs` (Linux module)
- Possible new dep: `pulse` crate or `libpulse-binding`

**Current state:** The Linux module spawns `ffmpeg -f pulse -i default ...` and reads f32le PCM from stdout. The fix was already applied (`ready_tx` threading). What's needed:
1. Test with actual PulseAudio/PipeWire
2. If ffmpeg not available, try `parec` 
3. If neither available, show clear error message

This is lower priority — the subprocess approach is functional where ffmpeg is installed.

---

## Task 9: Windows Platform — Test WASAPI Loopback

**Objective:** Windows WASAPI loopback implementation needs testing on a real Windows machine. The IID constants fix has been applied but can't be verified on macOS.

**Files:**
- Already fixed: `rust_core/src/audio/loopback.rs` (IID constants, ready_tx)
- Test binary: `rust_core/src/bin/dual_capture_probe.rs` (already exists)

**Verification on Windows:**
```bash
cd rust_core && cargo run --bin dual_capture_probe
```

Should print:
- Default output device found: OK
- WASAPI loopback initialized: OK 
- Audio frames received: OK (frame count > 0 after 3 seconds)

---

## Execution Order

```
Task 1 (model path)        → P0 — blocking session start
Task 2 (device resolution) → P0 — blocking capture activation  
Task 6 (Rust device wiring) → P0 — blocking capture activation
Task 4 (poll error logging) → P1 — debugging enabler
Task 3 (VU meter cleanup)  → P1 — UI correctness
Task 5 (Rust event verify) → P1 — validation
Task 7 (latency)           → P1 — partially done (ring_buffer)
Task 8 (Linux)             → P2 — subprocess works
Task 9 (Windows test)      → P2 — needs Windows machine
```

**P0 tasks must complete first** to get anything showing in the UI. P1/P2 are optimizations and cross-platform hardening.

---

## Verification

After all tasks:
```bash
cd rust_core && cargo test --lib                    # 102+ tests pass
cd .. && flutter test                                # 47+ tests pass
flutter analyze                                      # No issues
flutter build macos --release                        # 53.8MB
cd rust_core && cargo build --release --lib          # Release build
```

Manual smoke test on macOS:
1. Launch app via `open build/macos/Build/Products/Debug/transcribe.app`
2. Complete setup wizard
3. Click "Mulai" → VU meter moves, transcript appears within 5 seconds
4. Click "Stop" → session saved
