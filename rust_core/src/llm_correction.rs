//! LLM-based post-correction and summarization using Qwen2.5-7B.
//!
//! Pipeline: Whisper transcript → Qwen2.5-7B → corrected text + summary.
//!
//! When the `llm` feature is enabled, this delegates to a Python subprocess
//! running either MLX-LM (macOS Apple Silicon, ~55 tok/s) or llama.cpp
//! (other platforms, ~25 tok/s). When the feature is disabled, it returns
//! the input unchanged so the rest of the app keeps working.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LlmCorrection {
    pub corrected_text: String,
    pub summary: String,
    pub per_speaker_summary: Vec<SpeakerSummary>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpeakerSummary {
    pub speaker: String,
    pub summary: String,
}

#[cfg(feature = "llm")]
mod llm_impl {
    use super::*;
    use std::process::Command;

    #[derive(Serialize)]
    struct CorrectionRequest<'a> {
        transcript: &'a str,
        speakers: &'a [String],
        language: &'a str,
    }

    #[derive(Deserialize)]
    struct CorrectionResponse {
        corrected_text: String,
        summary: String,
        per_speaker_summary: Vec<SpeakerSummary>,
    }

    /// Run correction + summary via a Python subprocess.
    /// The Python side handles model loading, MLX/llama.cpp selection, and prompt templating.
    pub fn correct_and_summarize(
        transcript: &str,
        speakers: &[String],
    ) -> Result<LlmCorrection, String> {
        let req = CorrectionRequest {
            transcript,
            speakers,
            language: "id",
        };
        let json = serde_json::to_string(&req).map_err(|e| e.to_string())?;

        let output = Command::new("python3")
            .arg("scripts/qwen_correction.py")
            .arg(&json)
            .output()
            .map_err(|e| format!("failed to launch python: {e}"))?;

        if !output.status.success() {
            return Err(format!(
                "python script failed: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }

        let resp: CorrectionResponse =
            serde_json::from_slice(&output.stdout).map_err(|e| e.to_string())?;
        Ok(LlmCorrection {
            corrected_text: resp.corrected_text,
            summary: resp.summary,
            per_speaker_summary: resp.per_speaker_summary,
        })
    }
}

#[cfg(not(feature = "llm"))]
pub fn correct_and_summarize(
    transcript: &str,
    speakers: &[String],
) -> Result<LlmCorrection, String> {
    // No-op pass-through: the rest of the pipeline still works.
    Ok(LlmCorrection {
        corrected_text: transcript.to_string(),
        summary: String::new(),
        per_speaker_summary: speakers
            .iter()
            .map(|s| SpeakerSummary {
                speaker: s.clone(),
                summary: String::new(),
            })
            .collect(),
    })
}

#[cfg(feature = "llm")]
pub use llm_impl::correct_and_summarize as correct_and_summarize_impl;

/// Build the prompt that we send to Qwen2.5-7B.
pub fn build_correction_prompt(transcript: &str) -> String {
    format!(
        "Anda adalah asisten transkripsi berbahasa Indonesia.\n\
         Tugas: Koreksi kesalahan pengucapan dari hasil ASR, lalu buat ringkasan.\n\
         Aturan:\n\
         - Pertahankan nama orang, istilah teknis, dan angka.\n\
         - Jangan menambahkan informasi yang tidak ada di transkrip.\n\
         - Tulis ringkasan dalam 3 poin singkat.\n\n\
         Transkrip:\n{transcript}\n\n\
         Format jawaban:\nKOREKSI: <teks terkoreksi>\nRINGKASAN:\n- <poin 1>\n- <poin 2>\n- <poin 3>"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pass_through_when_disabled() {
        let r = correct_and_summarize("halo dunia", &["A".into()]).unwrap();
        assert_eq!(r.corrected_text, "halo dunia");
    }

    #[test]
    fn prompt_includes_transcript() {
        let p = build_correction_prompt("uji coba");
        assert!(p.contains("uji coba"));
        assert!(p.contains("KOREKSI"));
    }
}
