# Trascribe — Rencana Task Bertahap (Flutter + Rust, DevSecOps)

## Context

Repo `Traeon Transcribe` saat ini kosong (greenfield) kecuali dokumen `TRASCRIBE-BLUEPRINT.md` (5914 baris) — gabungan PRD, competitive analysis, RFC/ADR arsitektur, backend API schema, design brief, application flow, test plan, distribusi, task separation, code review checklist, market analysis, feasibility, friction analysis, dan security/performance/release/accessibility audit.

Tujuan: pecah blueprint menjadi rencana kerja bertahap (banyak task kecil, dieksekusi berurutan per fase) untuk membangun **Trascribe** — aplikasi transkripsi offline mic+speaker (Flutter UI + Rust engine via `flutter_rust_bridge` V2, whisper-rs/whisper.cpp), target macOS + Windows — sambil menerapkan DevSecOps sejak hari pertama (bukan ditempel di akhir), sesuai §86–§92 blueprint yang sudah eksplisit soal ini.

Blueprint sudah punya kerangka task 5-agent (BAGIAN 11, baris 3769–4092) dan checklist keamanan/rilis (BAGIAN 18, baris 5548–5914). Rencana ini mengonversi itu jadi urutan task konkret, ditambah gate DevSecOps di tiap fase (bukan hanya di akhir).

## Prinsip DevSecOps yang Diterapkan di Setiap Fase

- **Shift-left security**: `cargo audit`, `cargo deny`, `cargo clippy -D warnings`, `flutter analyze` dijalankan di CI sejak commit pertama, bukan menjelang rilis.
- **Secrets & signing**: tidak ada API key/secret di source; code signing (ad-hoc macOS, self-signed Windows) dan checksum model (SHA256) di-set up di fase infra, bukan fase akhir.
- **Dependency hygiene**: `Cargo.lock`/`pubspec.lock` di-commit sejak awal; Dependabot config (`.github/dependabot.yml`) dibuat di fase 0.
- **Least-privilege by design**: zero network call saat transkripsi, tulis file hanya ke path yang di-approve user, tidak ada telemetry non-opt-in — ini divalidasi di setiap fase yang menyentuh network/filesystem.
- **CI sebagai gate**, bukan sekadar build: setiap PR/merge lolos test + lint + security scan sebelum lanjut ke task berikutnya.

---

## FASE 0 — Fondasi Repo & DevSecOps Baseline (sebelum kode fitur apa pun)

1. Init struktur repo sesuai `§7 Directory Structure` blueprint (baris ~1963–2035): `lib/` (screens, widgets, state, services, theme), `rust_core/src/` (audio, vad, stt, dedupe, export), `models/`, `test/`, `integration_test/`, `scripts/`, `pubspec.yaml`, `rust_core/Cargo.toml`.
2. `flutter create` + `cargo init` di `rust_core/`, wiring `flutter_rust_bridge` V2 codegen dasar (skeleton `api.rs` kosong, tanpa logic).
3. Setup `.gitignore` yang benar (build artifacts, model besar, `.dart_tool`, `target/`).
4. **DevSecOps baseline**:
   - `.github/workflows/ci.yml`: jalankan `cargo test`, `cargo clippy -- -D warnings`, `cargo fmt --check`, `cargo audit`, `cargo deny check`, `flutter analyze`, `flutter test` di setiap PR.
   - `.github/dependabot.yml` sesuai §89.4 (ecosystem cargo di `/rust_core`, pub di `/`, weekly, limit 10 PR).
   - `SECURITY.md` awal (kebijakan network-zero, cara report vuln).
   - Commit `Cargo.lock` dan `pubspec.lock`.
5. Definisikan `TrascribeError` (Rust) sebagai error type tunggal untuk seluruh API publik — no `unwrap`/`expect`/`panic!` di library code (aturan §Code Review 4093–4307 dan §86.3).

## FASE 1 — Rust Engine Core (Task 1 / Agent A di blueprint, baris 3769–4092, subtask 1.1–1.14)

6. Audio device enumeration (`list_audio_devices`, `get_loopback_device`) via `cpal`.
7. Audio capture: dual stream mic+speaker, thread terpisah, ring buffer 30s + overlap 10s, watchdog reconnect.
8. Resample ke 16kHz mono 16-bit PCM (rubato).
9. VAD dual: WebRTC VAD (gate cepat) → Silero VAD (konfirmasi), threshold configurable.
10. STT engine: integrasi `whisper-rs`, load model GGUF, chunking 30s, partial→final segment, satu inference thread + mpsc queue.
11. Echo-dedupe: banding teks MIC vs SPK window 5 detik, >80% identik → dedupe.
12. Export module: WAV per-track+merged, Markdown, TXT, JSON, SRT/VTT.
13. Audio file decode (Symphonia — pure Rust, tanpa ffmpeg) + file STT (`transcribe_file`, `transcribe_files_batch` dengan progress stream, Rayon-based parallel batch).
14. Settings persistence (`AppSettings` load/save).
15. Session management (`start_session`, `stop_session`, `toggle_mic/speaker`, `set_session_mode`, streams: `vu_meter_stream`, `transcript_stream`, `session_status_stream`).
16. Fixture generator (`scripts/gen_fixtures.rs`) untuk test tanpa mic real.
17. Unit test Rust per modul (target >90% coverage sesuai §Test Plan) — audio, VAD, STT, dedupe, export, decode.
18. **DevSecOps gate fase ini**: model download via HTTPS + verifikasi SHA256 (checksum dibundle di binary, bukan didownload terpisah — cegah MITM, sesuai STRIDE §86.1); pastikan tidak ada network call di path transkripsi kecuali saat user eksplisit download model; `cargo audit`/`clippy` harus bersih sebelum lanjut ke Fase 2.

## FASE 2 — Flutter UI Utama & State Management (Task 2 / Agent B, subtask di 3769–4092)

19. Setup tema (light/dark, color tokens dari Design Brief §5), custom title bar (macOS traffic lights, Windows custom).
20. State models (Riverpod): `SessionModel`, `SettingsModel`, `AudioStreamModel`.
21. Widget: mode selector (Webinar/Online/Offline), stream toggle mic/speaker, VU meter, transcript view (virtualized `ListView.builder` untuk performa banyak segmen), resource HUD.
22. Bridge service: wiring Dart ↔ Rust via FRB, termasuk `RustBridgeMock` agar UI bisa dikembangkan paralel tanpa backend real.
23. Main screen assembly + system tray integration (minimize-to-tray tetap transkrip jalan).
24. Widget test untuk komponen di atas.
25. **DevSecOps gate**: pastikan tidak ada state/log yang menulis path sensitif ke console (`tracing`, bukan `print`), validasi semua input dari FRB bridge (bounds-check, no blind trust ke data dari Rust).

## FASE 3 — Setup Wizard & Fitur Sistem (Task 3 / Agent C)

26. Setup wizard 5 langkah: detect spec (CPU/RAM/GPU), pilih model, setup audio (macOS: ScreenCaptureKit default + BlackHole fallback <12.4; Windows: WASAPI native), download model dengan progress+resume, tone test.
27. Settings screen (theme, model default, mode default, library path, VAD/dedupe toggle, language override).
28. Singleton instance lock (PID file + mutex) — cegah multi-instance.
29. First-run detection & error handling UI (device gagal, model corrupt, disk penuh).
30. **DevSecOps gate**: download model resume via HTTP Range Request + verifikasi ulang SHA256 setelah resume; permission request (Screen Recording macOS) di-handle eksplisit dengan penjelasan ke user, bukan silent request.

## FASE 4 — Library, Export & Player (Task 4 / Agent D)

31. Library screen (list session, search, delete dengan soft-delete 7 hari ke `.trash/`, rename).
32. Export dialog + service (multi-format checkbox, naming `YYYYMMDD-judul/`).
33. Transcript player dengan seek & speed control.
34. File upload zone (drag&drop via `desktop_drop` + file picker), batch queue UI dengan progress per file.
35. Integration test alur library/export/upload.
36. **DevSecOps gate**: validasi path saat delete/rename (no path traversal dari nama file/judul rapat yang di-generate otomatis dari window title); sanitasi nama file sebelum dipakai sebagai path filesystem.

## FASE 5 — Integrasi, CI/CD Build Pipeline & Release (Task 5 / Agent E)

37. FRB codegen final, build macOS (dmg) dan Windows (exe/msi via Inno Setup atau MSIX).
38. Code signing: macOS ad-hoc (`codesign --force --deep --sign -`), Windows self-signed cert — didokumentasikan sebagai keterbatasan v1 (bukan notarized) sesuai ADR-12.
39. CI GitHub Actions penuh: build matrix macOS+Windows, bundle model `tiny` ke installer, jalankan smoke test matrix.
40. Release workflow: tag → build → package → upload manual ke Lynk.ID (bukan GitHub Releases binary, sesuai keputusan distribusi).
41. **DevSecOps gate rilis** (checklist §86.4 + §92 Final Master Checklist):
    - `cargo audit` 0 vulnerability HIGH+, `cargo deny` 0 issue lisensi.
    - `cargo clippy -D warnings` dan `flutter analyze` 0 warning/error.
    - Verifikasi tidak ada `unsafe` tanpa justification comment, tidak ada `unwrap/expect` di library code.
    - Verifikasi **zero network call** saat sesi transkripsi berjalan (uji dengan network monitor / Privacy Report built-in — "0 network calls since launch").
    - `codesign -dv` (macOS) dan `sigcheck` (Windows) untuk verifikasi signing sebelum distribusi.
    - Crash recovery test: force-quit saat rekam → restart → prompt recovery dari `.inprogress` file.

## FASE 6 — Hardening: Performance, Accessibility, Operational Excellence (§87, §90, §91)

42. Performance benchmark otomatis di CI dengan gate warning/block (STT latency, startup time, RAM growth, export time, VAD processing) sesuai tabel §87.2.
43. Accessibility pass (WCAG 2.2 AA): semantic labels, kontras warna, keyboard nav, screen reader test (VoiceOver/NVDA/Narrator), target tap ≥24x24pt.
44. Dokumentasi operasional: `ARCHITECTURE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, update `SECURITY.md` (siklus review 6 bulan), User Guide.
45. Opt-in crash telemetry (Crashpad/Breakpad) — eksplisit opt-in, path-sanitized, tidak default-on.

## FASE 7 — Architecture Bottleneck Fixes (BAGIAN 16 §B, baris 4886–5030)

46. STT queue jadi priority queue (mic > speaker) — bukan FIFO polos.
47. Model pre-load di background saat splash screen, bukan blocking di main screen.
48. Streaming/chunked decode untuk file besar (30s per chunk) — hindari load seluruh file ke memori.
49. Chunked processing file besar (~10MB per chunk, bukan load 230MB sekaligus).
50. Batch transfer segmen FRB tiap 10 detik (bukan per-segment) untuk kurangi overhead FFI.
51. Export paralel per format (thread terpisah per format, bukan sekuensial).
52. Chunked UI update (10 segmen per 16ms) agar UI thread tidak blocking saat data besar masuk.
53. Core budgeting eksplisit antar thread (mic/speaker/STT/export/UI) agar tidak rebutan resource.
54. Auto-save I/O dibatch (metadata 10s, audio 60s, transcript 30s) — bukan tulis tiap event.
55. Model switching async graceful (unload lama → load baru tanpa freeze UI).
56. Virtualisasi transcript list (`ListView.builder`, const constructor, itemExtent) untuk sesi panjang.
57. VAD paralel WebRTC+Silero dengan voting (bukan sequential gate→confirm) untuk kurangi latency.

## FASE 8 — Reliability & Painpoint Fixes P0 (BAGIAN 17, PP-1..25, baris 5045–5541)

58. Pause/resume recording (bukan hanya start/stop).
59. Konfirmasi sebelum accidental-stop dan saat quit-while-recording.
60. VU meter feedback instan, feedback visual saat drag-drop file.
61. Progress bar untuk semua operasi lama (export, download, batch transcribe) + notifikasi selesai.
62. Delete dengan soft-delete/undo ke `.trash/` (7 hari) — sudah disinggung di Fase 4, pastikan undo UX-nya eksplisit.
63. Full-text search lintas semua session di Library.
64. Auto-stop timer (opsional, untuk sesi tak terjaga).
65. Crash recovery end-to-end (atomic write 3 file per 10 detik, deteksi `.inprogress`, prompt recovery) — validasi ulang di sini sebagai P0 reliability, bukan hanya smoke test rilis.

## FASE 9 — Fitur P1/P2 Tambahan (BAGIAN 10 §Improvement, baris 3413–3766 & PP lanjutan)

66. Export tambahan: DOCX, PDF, HTML (selain MD/TXT/JSON/SRT/VTT/WAV).
67. Global keyboard shortcuts (`rdev` crate) + panel bantuan shortcut yang visible di UI.
68. Konfigurasi GPU acceleration (Apple Neural Engine / CUDA) sebagai opsi user, bukan hardcoded.
69. Inline transcript editing + session merge.
70. Compare transcripts (side-by-side) dan TAG segmen penting.
71. Teleprompter mode.
72. Word-level timestamp, auto-detected meeting title (window title detection macOS AppleScript / Windows win32 API).
73. Drag-to-dock (macOS `CFBundleDocumentTypes`) dan "Open With" (Windows) file association.
74. Native share sheet, usage dashboard, theme-follow-system, update checker (manual check, bukan auto-update — auto-update penuh dengan Ed25519 signature masuk roadmap fase 2 terpisah, lihat §86.1).
75. Internationalization: Bahasa Indonesia + English (P0 bahasa), Chinese/Japanese/Korean/Spanish (P2, backlog setelah rilis awal).

## FASE 10 — Distribusi & Monetisasi (BAGIAN 8, baris 2789–2972)

76. Setup produk di Lynk.ID ($5, source-open MIT + binary berbayar) — pastikan deskripsi jelas soal ad-hoc signing/self-signed (macOS "Apple cannot verify" & Windows SmartScreen warning didokumentasikan di halaman produk).
77. Siapkan backup channel (Gumroad) sesuai mitigasi risiko outage Lynk.ID di blueprint.
78. Semantic versioning + changelog format final; hotfix protocol (`hotfix/vX.Y.Z`, target 24 jam untuk bug kritis).

## FASE 11 — Item Acceptance Criteria & Risk yang Belum Eksplisit (baris 185–207, 847–864)

79. **CLI mode**: `trascribe --batch "*.mp3" --output ./transkrip/` — reuse `transcribe_files_batch` dari Fase 1, expose sebagai binary CLI terpisah (`trascribe-cli` atau flag di binary utama) untuk power user, tanpa perlu buka UI.
80. **Privacy Report** built-in: layar/panel yang menampilkan "0 network calls since launch" secara live — reuse network-monitor internal dari validasi gate Fase 5 (§41) sebagai fitur user-facing, bukan hanya alat verifikasi internal.
81. **Auto-split sesi panjang (>4 jam)**: split otomatis per 1 jam + memory pressure handling (flush ring buffer saat RAM >80%) — perluasan dari batching auto-save di Fase 7 (§54), tapi khusus untuk sesi live yang sangat panjang.
82. **Download model resume** end-to-end test: pastikan test case eksplisit untuk putus-sambung koneksi saat download, verifikasi lanjut dari byte terakhir + SHA256 re-check (melengkapi §30, dijadikan test case bukan hanya implementasi).

## Urutan Eksekusi & Paralelisasi

- **Wajib sekuensial**: Fase 0 → Fase 1 (Rust core harus ada dulu sebelum UI bisa dites nyata, meski `RustBridgeMock` di Fase 2 memungkinkan Fase 2 mulai lebih awal secara paralel dengan Fase 1).
- **Bisa paralel** (sesuai Task Separation blueprint, BAGIAN 11): Fase 2 (UI utama), Fase 3 (wizard), Fase 4 (library/export) bisa dikerjakan bersamaan setelah `api.rs` skeleton + mock bridge tersedia dari Fase 0–1, lalu disatukan di Fase 5 (integrasi & build).
- **Fase 7 (bottleneck fixes)** sebaiknya dikerjakan sebagai *hardening pass* setelah Fase 1–5 fungsional, bukan diimplementasi prematur sebelum ada baseline yang bisa diukur.
- **Fase 8–9 (painpoint & fitur P1/P2)** adalah backlog pasca-MVP — dikerjakan setelah Final Master Checklist P0 (Fase 5 §41 + Fase 6) lulus, sejalan dengan Phasing Plan RFC (P0 MVP → P1 Accuracy → P2 Usability → P3 Polish, baris 867–874).
- **Fase 10 (distribusi/monetisasi)** baru relevan setelah build pertama lolos semua gate keamanan di Fase 5 §41.
- **Fase 11** disisipkan paralel di Fase 1 (CLI, auto-split) dan Fase 3 (Privacy Report UI, download-resume test) — bukan fase terpisah secara waktu, hanya dikelompokkan di sini agar tidak terlewat saat tracking.

## Catatan Proses: Git Commit Authorship

- Repo target: `https://github.com/Trareon-com/Transcribe`.
- **Setiap commit yang dibuat selama eksekusi task-task di atas TIDAK BOLEH menyertakan Claude sebagai co-author** — jangan tambahkan trailer `Co-Authored-By: Claude ...` pada commit message. Ini berlaku untuk seluruh fase implementasi, bukan hanya commit pertama.

## Verifikasi End-to-End

- Jalankan seluruh CI gate (`cargo test`, `cargo clippy`, `cargo audit`, `cargo deny`, `flutter test`, `flutter analyze`) hijau di setiap fase sebelum lanjut ke fase berikutnya — jangan menumpuk technical debt ke akhir.
- Smoke test manual 10-case dari §Test Plan (baris 2039–2787) dijalankan setelah Fase 4 dan sebelum Fase 5 rilis.
- Final Master Checklist P0 (§92, baris 5853–5906) harus 100% selesai sebelum build pertama didistribusikan ke Lynk.ID.
- Setelah plan ini disetujui, task-task di atas sebaiknya dieksekusi satu per satu (atau per kelompok kecil dalam satu fase) di sesi-sesi terpisah — jangan coba implementasi seluruh app dalam satu batch besar.
