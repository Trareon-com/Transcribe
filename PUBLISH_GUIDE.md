# Lynk.ID & Gumroad — Panduan Publikasi

> Dokumen ini berisi konten yang siap di-copy-paste ke halaman produk Lynk.ID dan Gumroad.
> Screenshot ada di `~/Desktop/trascribe_*.png` — pilih yang terbaik untuk hero image.

---

## Lynk.ID Product Page

### Title
**Trareon Transcribe — Offline Meeting Transcriber**

### Price
**$5** (atau Rp75.000 — sesuaikan kurs)

### Hero Image
Gunakan salah satu dari:
- `~/Desktop/trascribe_main_screen.png` — Main screen dengan mode selector
- `~/Desktop/wizard_main_screen.png` — Setelah wizard selesai
- `~/Desktop/hwtest_recording_state.png` — Saat recording aktif

### Description (copy-paste)

```
# Trareon Transcribe — Transkripsi Offline 100%

Trareon Transcribe adalah aplikasi desktop untuk merekam dan mentranskrip
microphone + system speaker secara SIMULTAN, 100% OFFLINE,
tanpa cloud, tanpa biaya berlangganan.

## Keunggulan

✅ 100% OFFLINE — tidak ada data dikirim ke cloud
✅ Dual capture: Mic + Speaker dalam satu sesi
✅ 3 mode: Webinar, Rapat Online, Rapat Offline
✅ Zero external dependency — install langsung jalan
✅ Export: Markdown, TXT, JSON, SRT, VTT, HTML, DOCX, WAV
✅ Batch transkripsi file audio/video
✅ Bahasa Indonesia + English + code-switching
✅ Open source (MIT)

## Cara Kerja

1. Install aplikasi (macOS .dmg atau Windows .zip)
2. Jalankan → Setup wizard 5 langkah
3. Klik "Mulai" → transkripsi berjalan real-time
4. Export hasil ke berbagai format

## Spesifikasi

- Platform: macOS (Apple Silicon + Intel), Windows 11
- Model STT: whisper.cpp tiny (bundled), upgrade ke large opsional
- RAM: 2-6 GB tergantung model
- Binary size: ~40MB + model ~75MB = ~115MB total

## ⚠️ Penting — Sebelum Membeli

**macOS:** Aplikasi ini di-sign dengan ad-hoc signing (bukan Apple Developer).
Pertama kali buka:
1. Klik kanan → Open
2. Klik "Open Anyway" di System Preferences → Privacy & Security
3. Setelah itu, app bisa dibuka normal tanpa warning

**Windows:** Aplikasi ini di-self-sign. Windows SmartScreen mungkin
menampilkan peringatan "Windows protected your PC" pada pertama kali.
Klik "More info" → "Run anyway". Setelah beberapa kali dijalankan,
SmartScreen akan belajar dan berhenti memperingatkan.

**Tidak ada auto-update di versi 1.0.** Cek pembaruan manual via menu
Help → Check for Updates.

Download model besar (>tiny) butuh koneksi internet sekali.
Setelah itu 100% offline selamanya.
```

### Screenshots Gallery

Upload dari `~/Desktop/`:
1. Setup wizard — `wizard_step1.png`
2. Model selection — `wizard_step2.png`
3. Main screen — `trascribe_main_screen.png`  
4. Recording active — `hwtest_recording_state.png`
5. Settings — `settings_main.png`
6. Privacy Report — `privacy_report.png`

---

## Gumroad Backup Page

### Title
**Trareon Transcribe — 100% Offline Meeting Transcriber (macOS + Windows)**

### Price
**$5**

### Description
Sama dengan deskripsi Lynk.ID di atas (copy-paste).

### Gumroad-specific settings
- Allow quantity: No (single purchase)
- Allow customers to set their own price: No
- Enable customer notes: Yes
- Product type: Digital download

### Files to upload
1. `trascribe-1.0.0-macos.dmg` (build dari CI)
2. `trascribe-1.0.0-windows.zip` (build dari CI)

---

## Checklist Pra-Publish

- [ ] Lynk.ID akun sudah dibuat
- [ ] Gumroad akun sudah dibuat
- [ ] macOS .dmg sudah di-download dari CI artifact
- [ ] Windows .zip sudah di-download dari CI artifact
- [ ] SHA256 checksum diverifikasi
- [ ] Screenshots sudah di-upload
- [ ] Harga: $5 (sama di kedua platform)
- [ ] Known limitations sudah tercantum (ad-hoc signing, SmartScreen)
- [ ] Link ke GitHub source (MIT)
- [ ] Link DISTRIBUTION.md di-update dengan URL live
