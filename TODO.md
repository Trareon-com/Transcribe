# TODO — Trareon Transcribe Development Roadmap

> Status: Aktif. Clone kerja: `/home/kali/workspace/transcribe`
> Blueprint: `~/Trascribe-Docs/TRASCRIBE-BLUEPRINT.md`
> Skill: `flutter-rust-desktop-master`, `flutter-rust-architecture`, `flutter-rust-desktop`

---

## Batch 1: Engine Inti (Zero Friction)

- [ ] **Symphonia + Rubato decoding** — Full pure-Rust audio decode (MP3/M4A/OGG/FLAC) → PCM 16kHz. Matikan ffmpeg total.
  - File: `rust_core/src/decode/`
  - Verify: `cargo test` + decode fixture MP3/M4A tanpa ffmpeg
- [ ] **SSE Codec (FRB v2)** — Aktifkan `#[frb(serialize)]` untuk transfer buffer audio 30 detik tanpa latency.
  - Verify: benchmark buffer transfer Rust→Dart
- [ ] **Dual Capture Probe** — WASAPI loopback (Windows) + CoreAudio Process Taps (macOS 14.4+) + PipeWire (Linux) tanpa intervensi user.
  - Existing: `rust_core/src/bin/dual_capture_probe.rs`
- [ ] **Watchdog reconnect** — Auto-reconnect device <5s setelah sleep/wake.
  - Existing: `rust_core/src/watchdog.rs` (sudah ada, verifikasi)

## Batch 2: Hybrid Progressive Transcription (HPT) ⭐

**Konsep:** Base dulu (latency <1s, UI responsif), lalu large-v3-turbo-q5 refine (ganti teks, akurasi maksimal). Target: teks muncul 3-5 detik setelah suara, tapi akurasi setara Q5.

- [ ] **Dual-Context Model Loader** — Load `base` + `large-v3-turbo-q5` simultan di `rust_core/src/model.rs`. RAM ~700MB.
- [ ] **Priority Inference Queue** — Chunk masuk → Base dulu (stream ke Dart `is_final: false`) → Q5 menyusul (ganti via segment ID, `is_final: true`).
  - File: `rust_core/src/pipeline.rs`, `rust_core/src/stt/`
- [ ] **UUID Segment Tracking** — Tiap chunk dapat ID stabil. Rust kirim `Segment { id, text, is_final, source }`. Dart update by ID, bukan append.
  - Verify: test update-by-id di Dart state
- [ ] **UI Refinement Indicator** — Teks Base: italic/abu (placeholder). Teks Q5: normal. Transisi animasi halus.
- [ ] **Hallucination Guard** — Jika Base vs Q5 divergen besar (Levenshtein >80%), log warning + prioritas Q5.
- [ ] **Echo-Dedupe Sync** — Dedupe Mic vs SPK jalan di level Base agar UI tidak double teks.

## Batch 3: UI & UX Polish

- [ ] **4-step Setup Wizard** — Spec detect → model bundle → audio setup → tone test. (Sebagian sudah ada di `setup_wizard_screen.dart`)
- [ ] **Interactive Transcript** — RichText + highlight search + color-coding 8 speaker. (Sebagian sudah ada)
- [ ] **OBS-style Side-panel Settings** — Settings inline, bukan layar terpisah. `Ctrl+,`
- [ ] **Smart Auto-scroll** — Bottom anchor: on saat di bawah, off saat scroll up.

## Batch 4: Model & Accuracy

- [ ] **2-Model Bundle Default** — `base` (142MB) + `large-v3-turbo-q5` (548MB) di assets, tanpa download.
- [ ] **Hallucination Filter** — n-gram scan O(n), collapse pengulangan identik >3x.
- [ ] **Per-segment ID/EN detection** — Code-switching Indonesia↔Inggris.
- [ ] **Model ID Sync Check** — `rust_core/src/model.rs` vs `lib/state/models.dart` harus 100% sinkron (cegah runtime crash).

## Batch 5: Distribusi & Hygiene

- [ ] **Portable ZIP** — macOS (.app) + Windows (.exe), tanpa installer/admin.
- [ ] **AppImage Linux** — via `flutter_distributor` (zero-dep).
- [ ] **Privacy Report** — Bukti 0 network calls saat transkrip. (Sebagian sudah ada)
- [ ] **Repo Cleanup** — Hapus boilerplate FRB mati, `rust_core/--output/`, `rust_core/--help/`.
- [ ] **CI Fix** — `cargo fmt` + `clippy` di workflow GitHub Actions.

---

## Prioritas Eksekusi

1. **B2 HPT dual-model loader** — jantung nilai produk
2. **B1 Symphonia** — fondasi zero-friction
3. **B4 accuracy** — kualitas hasil
4. **B3 UI** — polish
5. **B5 distribusi** — pengiriman

## Acceptance Criteria HPT

- [ ] Teks pertama muncul <5 detik setelah suara (base)
- [ ] Teks di-refine ke Q5 dalam <15 detik (ganti by ID, tanpa duplikat)
- [ ] RAM stabil <2GB total saat dual model aktif
- [ ] 0 network call selama transkripsi
- [ ] 110/110 test existing tetap hijau
