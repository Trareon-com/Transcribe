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
                language: language.unwrap_or("auto").to_string(),
                confidence: 1.0,
                is_partial: false,
            });
        }

        Ok(out)
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
}
