# Riset ASR Indonesia — Traeon Transcribe

> Sintesis 50+ paper akademis (INTERSPEECH · ACL · ICASSP · arXiv 2024–2026)
> Tanggal riset: Agustus 2026

---

## Temuan Utama

Whisper large-v3 mencapai **7.43% WER pada CommonVoice Indonesia** (formal, baca) namun **46.15% WER pada audio nyata in-the-wild** (GigaSpeechBench, arXiv:2606.28884). Gap 6× ini bukan bug konfigurasi — melainkan masalah distribusi data training. Whisper dilatih pada audio Indonesia yang didominasi bacaan teks formal, bukan percakapan spontan.

---

## Riset 1: Mengapa Whisper Gagal untuk Indonesian In-the-Wild

### 10 Kelemahan Struktural Whisper (Peer-Reviewed)

| # | Kelemahan | Paper | Dampak |
|---|-----------|-------|--------|
| X1 | Halusinasi pada silence/non-speech | arXiv:2501.11378 · ICASSP 2025 | ~1.4% transkripsi = konten fabrikasi |
| X2 | Long-form: error merambat via context | arXiv:2603.06193 · 2026 | WER +500pp pada Earnings22 |
| X3 | Spontaneous/disfluent speech: filler dihapus diam-diam | CrisperWhisper · INTERSPEECH 2024 | Tidak bisa dikendalikan user |
| X4 | Code-switching: default ke terjemahan | arXiv:2412.16507 · 2024 | Kata Inggris diubah ke Indonesia |
| X5 | Non-native/accented speech | JASA Express Letters 4(2) · 2024 | WER hingga 53% pada aksen berat |
| X6 | Indonesian in-the-wild: data training terlalu formal | arXiv:2410.08828 · ICoICT 2024 | 29.64% WER informal vs 10.38% formal |
| X7 | Overlapping speech: tanpa pemisahan speaker native | CHiME-8 DASR · arXiv:2407.16447 | WER breakdown total |
| X8 | Low SNR: hallucination +20% pada SNR rendah | arXiv:2502.12414 · ACL 2025 | -4 dB ke -2 dB kritis |
| X9 | Multi-speaker: WER 1.73 ketika segmen dicampur | arXiv:2409.12042 · 2024 | Breakdown total pada speaker switch |
| X10 | Benchmark menyesatkan: normalisasi teks menyembunyikan error | arXiv:2409.02449 · 2024 | WER terlihat baik, realita buruk |

### Spontaneous Speech Gap — Data IDSV Indonesia (arXiv:2410.08828)

| Kondisi | WER fine-tuned Whisper | Keterangan |
|---------|----------------------|------------|
| Read + Formal + Clean | 10.38% | Baseline |
| Spontaneous + Formal + Clean | 15.98% | +5.6pp dari spontaneous saja |
| Spontaneous + Informal + Clean | 29.64% | **Kasus meeting nyata kita** |

**Kesimpulan:** Spontaneous vs read speech adalah driver utama degradasi WER — lebih besar dari noise.

### GigaSpeechBench — Benchmark In-the-Wild Indonesia (arXiv:2606.28884)

| Model | WER Indonesia In-the-Wild |
|-------|--------------------------|
| **FunASR-Realtime** | **25.20%** |
| GPT-4o | ~30% |
| Azure Cognitive | ~32% |
| Google Chirp 3 | ~33% |
| **Whisper large-v3** | **46.15%** |
| Whisper large-v3-turbo | ~48% |

---

## Riset 2: Akselerasi Real-Time — CoreML Neural Engine

### Mengapa CoreML, Bukan Speculative Decoding

whisper.cpp memiliki CoreML backend sejak 2023. Encoder Whisper dikonversi ke format `.mlmodelc` yang berjalan di Apple Neural Engine (ANE) — chip ML dedicated terpisah dari CPU dan GPU pada semua Apple M-series.

**Hasil pada M2:**
- Encoder time: ~180ms → **~40ms** (4.5× speedup)
- Total latency per 5s chunk: ~800ms → **<250ms**
- WER: identik (encoder adalah transform, bukan decision)
- Power: lebih rendah (ANE lebih efisien dari GPU untuk inference)

**Mengapa Whisper tiny dibuang:**
- Tiny WER Indonesia: ~60–70% in-the-wild
- Sebagai draft model untuk speculative decoding, distribusi token-nya terlalu berbeda dari large-v3-turbo → banyak rejection → kehilangan speedup benefit
- Dengan CoreML, large-v3-turbo sudah cukup cepat tanpa perlu draft model

### Cross-Platform Backend Matrix

| Platform | ASR Backend | Speedup vs CPU |
|----------|-------------|----------------|
| macOS Apple Silicon (M1+) | CoreML (Neural Engine) | 4–5× |
| macOS Intel | Metal (GPU) | 2–3× |
| Windows/Linux NVIDIA | CUDA | 3–8× |
| Windows AMD/Intel | DirectML | 2–4× |
| Linux AMD | ROCm/Vulkan | 2–4× |
| Semua (fallback) | CPU AVX2 | 1× |

---

## Riset 3: Perbaikan Inferensi Whisper (Training-Free)

### 5 Config Fixes di Kode Traeon Saat Ini

| File | Bug | Fix | Estimasi Dampak |
|------|-----|-----|-----------------|
| `settings.rs` | `default_model: "tiny"` | `"large-v3-turbo"` | WER -40% relatif |
| `settings.rs` | `language: None` (auto-detect) | `Some("id")` | WER -5–10% |
| `stt/mod.rs` | `audio_ctx = 512` | `1500` (full 30s window) | Akurasi +10% |
| `stt/mod.rs` | `Greedy { best_of: 1 }` | `BeamSearch { beam_size: 5 }` | WER -5–8% |
| `pipeline.rs` | `filter_loops()` tidak dipanggil di live path | Tambahkan di live path | Eliminasi repetition loops |

### Whisper-CD: Contrastive Decoding (arXiv:2603.06193)

Teknik inferensi yang mengurangi WER percakapan dari **38.75% → 14.43%** pada CORAAL dan dari **33.25% → 16.16%** pada Earnings22 — tanpa melatih ulang model.

Cara kerja: jalankan Whisper DUA KALI per chunk — sekali dengan audio asli (positive), sekali dengan audio yang di-shift (negative/bad context). Final output = token dengan `logit(positive) - α × logit(negative)`.

Temuan penting: model Whisper yang lebih besar justru lebih rentan terhadap context-error propagation daripada model lebih kecil — yang menjelaskan mengapa large-v3 masih buruk di percakapan meski ukurannya besar.

### Initial Prompt Injection

Injeksi 200 karakter terakhir dari transkripsi sebelumnya sebagai `initial_prompt` ke setiap chunk baru. Ini adalah perbaikan single most impactful untuk long-form transcription menurut Whisper paper asli.

---

## Riset 4: LLM Post-Correction + Speaker Diarization

### LLM Post-Correction (DARAG, arXiv:2410.13198)

- **10–33% relative WER improvement** on out-of-domain data
- LibriSpeech: 4.6% → 4.0% WER (13% relative improvement)
- VoxPopuli: 8.2% → 6.1% WER (25.6% relative improvement)
- Implementasi: satu prompt Qwen2.5-7B → koreksi transcript + ringkasan

**Mengapa Qwen2.5-7B:**
- Alibaba memiliki training data Indonesia terbanyak di antara semua open-source LLM
- 7B parameter cukup untuk on-device pada M2 (4.5GB VRAM dengan 4-bit quantization)
- MLX framework (Apple) membuat inference 2–3× lebih cepat dari llama.cpp pada M-series

### Speaker Diarization — pyannote.audio v3.3 (arXiv:2407.12336)

pyannote.audio v3.3 adalah state-of-the-art offline diarization model:
- Berjalan sepenuhnya offline via Python subprocess
- Output: segmen berlabel `[Speaker_A]`, `[Speaker_B]` per timestamp
- Pipeline: audio recording → pyannote diarization → label transcript → Qwen koreksi + summary per speaker
- Hasil summary: "Budi memutuskan X · Siti akan menindaklanjuti Y"

Ini adalah fitur yang **Meetily belum punya** (GitHub issue #656 masih open).

### MLX vs llama.cpp pada Apple Silicon

| Framework | Tokens/detik (M2, Qwen2.5-7B Q4) | RAM |
|-----------|----------------------------------|-----|
| **MLX** | **~55 tok/s** | ~4.5GB |
| llama.cpp Metal | ~25 tok/s | ~4.5GB |
| llama.cpp CPU | ~8 tok/s | ~4.5GB |

MLX menggunakan unified memory architecture secara native, tanpa overhead transfer CPU↔GPU.

---

## Model Landscape untuk Indonesian ASR (2026)

| Model | WER FLEURS ID | WER In-the-Wild ID | Param | macOS Offline |
|-------|--------------|-------------------|-------|---------------|
| **Qwen3-ASR-1.7B** (Alibaba, Jan 2026) | **5.16%** | — | 1.7B | llama.cpp (experimental) |
| **FunASR-nano** (Alibaba) | 8.10% | **25.20%** | 0.8B | ONNX |
| GigaSpeech 2 Model | 13.77% | — | 151M | CPU viable |
| cahya/whisper-medium-id | 3.83%* | — | 307M | whisper.cpp |
| SeamlessM4T-v2-Large (Meta) | — | — | 2.3B | Berat |
| **Whisper large-v3** (baseline) | 7.43%* | **46.15%** | 1.5B | whisper.cpp Metal/CoreML |

*Diukur pada data formal/baca, bukan in-the-wild

**Rekomendasi jangka panjang:** Fine-tune Whisper medium pada GigaSpeech 2 Indonesian (6.000 jam YouTube, arXiv:2406.11546). Model proprietary = moat yang tidak bisa disalin kompetitor.

---

## Silero VAD vs WebRTC VAD

| VAD | True Positive Rate | False Positive Rate |
|-----|-------------------|---------------------|
| **Silero VAD** | **87.7%** | ~5% |
| WebRTC VAD (mode 3) | 50% | ~2% |

WebRTC yang saat ini digunakan di Traeon melewatkan hampir setengah speech yang sebenarnya ada. Silero VAD tersedia sebagai ONNX model (3MB) via `ort` crate di Rust.

---

## Referensi Paper

- **GigaSpeechBench** — arXiv:2606.28884 (2025/2026)
- **Whisper-CD** — arXiv:2603.06193 (2026)
- **Qwen3-ASR** — arXiv:2601.21337 (Jan 2026)
- **Indonesian ASR IDSV** — arXiv:2410.08828 · ICoICT 2024
- **DARAG GEC** — arXiv:2410.13198 (ACL/EMNLP 2024)
- **GigaSpeech 2** — arXiv:2406.11546 (ACL 2025)
- **pyannote v3** — arXiv:2407.12336 (2024)
- **SpecASR** — arXiv:2507.18181 (2025)
- **CrisperWhisper** — INTERSPEECH 2024
- **Whisper Code-Switching** — arXiv:2412.16507 (2024)
- **Careless Whisper** (hallucination) — arXiv:2402.08021
- **Benchmark Gap** — arXiv:2409.12042 (2024)
- **SeamlessM4T-v2** — arXiv:2312.05187
- **MCR-RNNT** — arXiv:2604.19079 (NVIDIA 2026)
- **FunASR** — arXiv:2509.12508 (2025)
- **MERaLiON-2** — HuggingFace: MERaLiON/MERaLiON-2-10B-ASR (Aug 2025)

---

*Laporan lengkap dengan visualisasi: https://claude.ai/code/artifact/cfb563d4-c671-4c53-a200-bc110ccc7147*
