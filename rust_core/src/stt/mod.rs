//! STT engine: whisper-rs binding to whisper.cpp. One inference context per
//! loaded model, guarded by a mutex — whisper.cpp state is not safely
//! shared across concurrent `full()` calls, so callers must serialize
//! through a single inference thread/queue (see api.rs session handling).

use std::path::Path;
use std::sync::Mutex;

use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;

pub mod file;

pub struct WhisperEngine {
    context: Mutex<WhisperContext>,
    model_path: String,
    use_gpu: bool,
}

impl WhisperEngine {
    /// Load a GGML/GGUF model from disk. Returns an error (never panics)
    /// if the file is missing, unreadable, or not a valid whisper model.
    pub fn load(model_path: &Path) -> TranscribeResult<Self> {
        Self::load_with_gpu(model_path, false, 0)
    }

    /// Load a GGML/GGUF model with optional GPU acceleration.
    /// `use_gpu`: enable GPU inference (Metal on macOS, CUDA on Windows/Linux).
    /// `gpu_device`: GPU device index (0 = default).
    pub fn load_with_gpu(
        model_path: &Path,
        use_gpu: bool,
        gpu_device: i32,
    ) -> TranscribeResult<Self> {
        if !model_path.exists() {
            return Err(TranscribeError::Model(format!(
                "model file not found: {}",
                model_path.display()
            )));
        }

        let path_str = model_path
            .to_str()
            .ok_or_else(|| TranscribeError::Model("model path is not valid UTF-8".into()))?;

        let mut params = WhisperContextParameters::new();
        params.use_gpu(use_gpu).gpu_device(gpu_device);

        let context = WhisperContext::new_with_params(path_str, params)
            .map_err(|e| TranscribeError::Model(format!("failed to load model: {e}")))?;

        Ok(Self {
            context: Mutex::new(context),
            model_path: path_str.to_string(),
            use_gpu,
        })
    }

    pub fn model_path(&self) -> &str {
        &self.model_path
    }

    /// Whether this engine was loaded with GPU acceleration requested
    /// (Metal on macOS, CUDA on Windows/Linux) — surfaced for
    /// diagnostics/settings UI, not read internally after construction.
    pub fn gpu_enabled(&self) -> bool {
        self.use_gpu
    }

    /// Transcribe a chunk of 16kHz mono f32 PCM. `language` is `None` for
    /// auto-detect (per-segment code-switching per PRD), or an ISO-639-1
    /// code to force a language.
    pub fn transcribe_chunk(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
    ) -> TranscribeResult<Vec<Segment>> {
        if samples.is_empty() {
            return Err(TranscribeError::InvalidInput(
                "cannot transcribe empty audio buffer".into(),
            ));
        }

        // Apply noise reduction preprocessing
        let processed = crate::preprocess::preprocess(samples);

        let ctx = self
            .context
            .lock()
            .map_err(|_| TranscribeError::Transcription("whisper context lock poisoned".into()))?;

        let mut state = ctx
            .create_state()
            .map_err(|e| TranscribeError::Transcription(format!("failed to create state: {e}")))?;

        let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);
        params.set_language(language.or(Some("auto")));
        params.set_audio_ctx(512);
        // params.token_timestamps(true);  // disabled until FRB regen

        state
            .full(params, &processed)
            .map_err(|e| TranscribeError::Transcription(format!("inference failed: {e}")))?;

        let num_segments = state
            .full_n_segments()
            .map_err(|e| TranscribeError::Transcription(e.to_string()))?;

        let mut out = Vec::with_capacity(num_segments as usize);
        for i in 0..num_segments {
            let text = state
                .full_get_segment_text(i)
                .map_err(|e| TranscribeError::Transcription(e.to_string()))?;
            let t0 = state
                .full_get_segment_t0(i)
                .map_err(|e| TranscribeError::Transcription(e.to_string()))?
                as f64
                / 100.0;
            let t1 = state
                .full_get_segment_t1(i)
                .map_err(|e| TranscribeError::Transcription(e.to_string()))?
                as f64
                / 100.0;

            out.push(Segment {
                source: source.to_string(),
                speaker: source.to_uppercase(),
                text: text.trim().to_string(),
                timestamp: chunk_start_secs + t0,
                duration: (t1 - t0).max(0.0),
                language: segment_language(&text, language).to_string(),
                confidence: 1.0,
                is_partial: false,
            });
        }

        Ok(out)
    }
}

/// Per-segment language classifier for Indonesian↔English code-switching.
///
/// Heuristics (pure std, O(n) over the word tokens — no external deps):
///   - `language` forced by caller wins outright.
///   - count pure-ASCII-alpha tokens (EN-like) and exact EN
///     stopword hits.
///   - ≥2 EN keywords + >50% Latin → `"en"`
///   - ≥1 EN keyword + >30% Latin (mixed) → `"id-en"` (code-switch)
///   - else → `"id"`
///
/// This runs cheap after inference; it does not re-encode audio.
fn segment_language(text: &str, explicit: Option<&str>) -> &'static str {
    if let Some(l) = explicit {
        match l {
            "en" => return "en",
            "id" => return "id",
            "id-en" => return "id-en",
            _ => {} // "auto"/""/unknown → fall through to heuristics
        }
    }
    const EN_KEYWORDS: &[&str] = &[
        "the", "and", "to", "of", "in", "is", "it", "for", "on", "with", "you", "that", "we",
        "they", "he", "she", "this", "have", "from", "or", "as", "at", "by", "be", "not", "but",
        "an", "were", "our", "us", "so",
    ];
    const ID_KEYWORDS: &[&str] = &[
        "terima", "kasih", "bisa", "gak", "nggak", "kirim", "saya", "kamu", "itu", "halo", "bro",
        "di", "dari", "akan", "sudah", "udah", "ada", "aja", "juga", "ya", "dong", "deh", "tuhan",
        "lho", "tolong", "bukan", "ini", "itu", "ya", "makasih",
    ];
    let words: Vec<&str> = text
        .split(|c: char| c.is_whitespace() || c.is_ascii_punctuation())
        .filter(|w| !w.is_empty())
        .collect();
    if words.is_empty() {
        return "id";
    }
    let ascii_alpha = words
        .iter()
        .filter(|w| !w.is_empty() && w.chars().all(|c| c.is_ascii_alphabetic()))
        .count();
    let en_hits = words
        .iter()
        .filter(|w| EN_KEYWORDS.contains(&w.to_ascii_lowercase().as_str()))
        .count();
    let id_hits = words
        .iter()
        .filter(|w| ID_KEYWORDS.contains(&w.to_ascii_lowercase().as_str()))
        .count();
    let ratio = ascii_alpha as f32 / words.len() as f32;
    if en_hits >= 2 && ratio > 0.5 {
        "en"
    } else if en_hits >= 1 && id_hits >= 1 {
        // EN keyword + Indonesian keyword in same segment → code-switch
        "id-en"
    } else if en_hits >= 1 && ratio > 0.7 {
        // almost all tokens are Latin, single EN keyword → English
        "en"
    } else {
        "id"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn load_missing_model_errors_not_panics() {
        let result = WhisperEngine::load(Path::new("/nonexistent/model/tiny.gguf"));
        assert!(result.is_err());
    }

    #[test]
    fn load_invalid_model_file_errors() {
        let path = std::env::temp_dir().join("transcribe_not_a_model.gguf");
        std::fs::write(&path, b"not a real ggml model").unwrap();
        let result = WhisperEngine::load(&path);
        assert!(result.is_err());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn classify_pure_english() {
        assert_eq!(segment_language("the quick brown fox is here", None), "en");
    }

    #[test]
    fn classify_pure_indonesian() {
        assert_eq!(segment_language("terima kasih banyak ya", None), "id");
        assert_eq!(segment_language("apa kabar?", None), "id");
    }

    #[test]
    fn classify_codeswitch_id_en() {
        assert_eq!(
            segment_language("halo bro, bisa gak kirim the file?", None),
            "id-en"
        );
        assert_eq!(segment_language("saya butuh the link itu", None), "id-en");
    }

    #[test]
    fn explicit_language_wins() {
        // Forced EN overrides Indonesian-looking text.
        assert_eq!(segment_language("terima kasih", Some("en")), "en");
        // "auto" is treated as unset → falls through to heuristics.
        assert_eq!(segment_language("the quick brown fox", Some("auto")), "en");
    }
}
