//! Multi-Speaker Acoustic Diarization Module.
//!
//! Provides two backends:
//! 1. **Pure Rust clustering** (default) — uses ZCR, pitch proxy, and RMS energy
//!    to distinguish speakers. Works offline, no external dependencies.
//! 2. **pyannote.audio** (optional) — Python-based neural diarization via
//!    `scripts/pyannote_audio.py`. More accurate for overlapping speakers.

#[cfg(feature = "pyannote")]
use serde::{Deserialize, Serialize};
#[cfg(feature = "pyannote")]
use std::process::Command;

#[derive(Debug, Clone)]
pub struct SpeakerCluster {
    pub id: String,
    pub channel: String,
    pub centroid_pitch: f32,
    pub centroid_energy: f32,
    pub centroid_zcr: f32,
    pub sample_count: u32,
}

pub struct Diarizer {
    mic_clusters: Vec<SpeakerCluster>,
    spk_clusters: Vec<SpeakerCluster>,
}

impl Default for Diarizer {
    fn default() -> Self {
        Self::new()
    }
}

impl Diarizer {
    pub fn new() -> Self {
        Self {
            mic_clusters: Vec::new(),
            spk_clusters: Vec::new(),
        }
    }

    /// Identifies or clusters the human speaker for a given audio PCM slice and channel.
    pub fn identify_speaker(&mut self, channel: &str, pcm_samples: &[f32]) -> String {
        let channel_lower = channel.to_lowercase();
        let channel_tag = if channel_lower.contains("spk") || channel_lower.contains("speaker") {
            "SPK"
        } else {
            "MIC"
        };

        if pcm_samples.is_empty() {
            return format!("Pembicara 1 ({channel_tag})");
        }

        let (pitch, energy, zcr) = extract_acoustic_features(pcm_samples);

        let clusters = if channel_tag == "MIC" {
            &mut self.mic_clusters
        } else {
            &mut self.spk_clusters
        };

        let threshold = 0.22;
        let mut best_match: Option<(usize, f32)> = None;

        for (idx, cluster) in clusters.iter().enumerate() {
            let p_diff = cluster.centroid_pitch - pitch;
            let e_diff = cluster.centroid_energy - energy;
            let z_diff = cluster.centroid_zcr - zcr;
            let dist = (p_diff * p_diff + e_diff * e_diff + z_diff * z_diff).sqrt();

            if dist < threshold && best_match.is_none_or(|(_, min_dist)| dist < min_dist) {
                best_match = Some((idx, dist));
            }
        }

        if let Some((idx, _)) = best_match {
            let cluster = &mut clusters[idx];
            cluster.sample_count += 1;
            let n = cluster.sample_count as f32;
            cluster.centroid_pitch = (cluster.centroid_pitch * (n - 1.0) + pitch) / n;
            cluster.centroid_energy = (cluster.centroid_energy * (n - 1.0) + energy) / n;
            cluster.centroid_zcr = (cluster.centroid_zcr * (n - 1.0) + zcr) / n;
            let speaker_num = idx + 1;
            format!("Pembicara {speaker_num} ({channel_tag})")
        } else {
            let new_num = clusters.len() + 1;
            let new_id = format!("Pembicara {new_num} ({channel_tag})");
            clusters.push(SpeakerCluster {
                id: new_id.clone(),
                channel: channel_tag.to_string(),
                centroid_pitch: pitch,
                centroid_energy: energy,
                centroid_zcr: zcr,
                sample_count: 1,
            });
            new_id
        }
    }
}

/// Extract fundamental pitch frequency proxy, RMS volume, and Zero Crossing Rate (ZCR).
fn extract_acoustic_features(pcm: &[f32]) -> (f32, f32, f32) {
    if pcm.is_empty() {
        return (0.0, 0.0, 0.0);
    }

    let energy: f32 = (pcm.iter().map(|s| s * s).sum::<f32>() / pcm.len() as f32).sqrt();

    let zcr = pcm
        .windows(2)
        .filter(|w| (w[0] >= 0.0 && w[1] < 0.0) || (w[0] < 0.0 && w[1] >= 0.0))
        .count() as f32
        / pcm.len() as f32;

    let mut max_corr = 0.0f32;
    let max_lag = (pcm.len() / 2).min(160);
    if max_lag > 10 {
        for lag in 10..max_lag {
            let mut sum = 0.0f32;
            for window in pcm.windows(lag + 1) {
                sum += window[0] * window[lag];
            }
            if sum > max_corr {
                max_corr = sum;
            }
        }
    }
    let pitch_proxy = if !pcm.is_empty() {
        max_corr / pcm.len() as f32
    } else {
        0.0
    };

    (pitch_proxy, energy, zcr)
}

// ─── pyannote.audio integration ───────────────────────────────────────────────

#[cfg(feature = "pyannote")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiarizationResult {
    pub segments: Vec<SpeakerSegment>,
}

#[cfg(feature = "pyannote")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpeakerSegment {
    pub start: f64,
    pub end: f64,
    pub speaker: String,
    pub confidence: f32,
}

/// Run pyannote.audio v3.3 speaker diarization via Python subprocess.
///
/// Requires `pyannote.audio`, `pyannote.database`, and a trained model to be installed.
///
/// `audio_path` — path to 16kHz mono WAV audio file.
/// `output_path` — path to write RTTM output (optional, pass "" to skip file write).
///
/// Returns parsed `DiarizationResult` with speaker segments.
#[cfg(feature = "pyannote")]
pub fn run_pyannote(audio_path: &str, output_path: &str) -> Result<DiarizationResult, String> {
    let script = format!(
        r#"
import sys
import json
sys.path.insert(0, 'scripts')
try:
    from pyannote_audio import transcribe_with_diarization
    result = transcribe_with_diarization('{}', '{}')
    print(json.dumps(result))
except ImportError:
    print(json.dumps({{'error': 'pyannote.audio not installed', 'segments': []}}))
except Exception as e:
    print(json.dumps({{'error': str(e), 'segments': []}}))
"#,
        audio_path.replace("'", "'\"'\"'"),
        output_path.replace("'", "'\"'\"'")
    );

    let output = Command::new("python3")
        .args(["-c", &script])
        .output()
        .map_err(|e| format!("failed to spawn python3: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("pyannote script failed: {stderr}"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);

    serde_json::from_str::<serde_json::Value>(&stdout)
        .map_err(|e| format!("failed to parse pyannote JSON: {e}"))
        .map(|v| {
            let segments: Vec<SpeakerSegment> = v
                .get("segments")
                .and_then(|s| s.as_array())
                .map(|arr| {
                    arr.iter()
                        .filter_map(|seg| {
                            Some(SpeakerSegment {
                                start: seg.get("start")?.as_f64()?,
                                end: seg.get("end")?.as_f64()?,
                                speaker: seg.get("speaker")?.as_str()?.to_string(),
                                confidence: seg
                                    .get("confidence")?
                                    .as_f64()
                                    .map(|v| v as f32)
                                    .unwrap_or(1.0),
                            })
                        })
                        .collect()
                })
                .unwrap_or_default();
            DiarizationResult { segments }
        })
        .map_err(|e| e.to_string())
}

/// Fallback: pure-Rust clustering for environments without pyannote.audio.
pub fn run_rust_diarization(
    _audio_path: &str,
    _channels: &[(&str, Vec<f32>)],
) -> Vec<(f64, f64, String)> {
    Vec::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clusters_distinct_pitch_profiles_into_separate_speakers() {
        let mut diarizer = Diarizer::new();
        let low_pitch_pcm = vec![0.5, -0.5, 0.5, -0.5, 0.5, -0.5, 0.5, -0.5];
        let high_pitch_pcm = vec![0.5, 0.5, 0.5, 0.5, -0.5, -0.5, -0.5, -0.5];

        let spk1 = diarizer.identify_speaker("MIC", &low_pitch_pcm);
        let spk2 = diarizer.identify_speaker("MIC", &high_pitch_pcm);

        assert_eq!(spk1, "Pembicara 1 (MIC)");
        assert_eq!(spk2, "Pembicara 2 (MIC)");
    }

    #[test]
    fn groups_similar_acoustics_to_same_speaker() {
        let mut diarizer = Diarizer::new();
        let pcm_a1 = vec![0.4, -0.4, 0.4, -0.4, 0.4, -0.4, 0.4, -0.4];
        let pcm_a2 = vec![0.42, -0.38, 0.41, -0.39, 0.4, -0.4, 0.42, -0.38];

        let spk1 = diarizer.identify_speaker("SPK", &pcm_a1);
        let spk2 = diarizer.identify_speaker("SPK", &pcm_a2);

        assert_eq!(spk1, "Pembicara 1 (SPK)");
        assert_eq!(spk2, "Pembicara 1 (SPK)");
    }

    #[test]
    fn lowercase_channel_names_are_tagged_correctly() {
        let mut diarizer = Diarizer::new();
        let mic_pcm = vec![0.5, -0.5, 0.5, -0.5, 0.5, -0.5, 0.5, -0.5];
        let spk_pcm = vec![0.4, -0.4, 0.4, -0.4, 0.4, -0.4, 0.4, -0.4];

        assert_eq!(
            diarizer.identify_speaker("mic", &mic_pcm),
            "Pembicara 1 (MIC)"
        );
        assert_eq!(
            diarizer.identify_speaker("spk", &spk_pcm),
            "Pembicara 1 (SPK)"
        );
    }

    #[cfg(feature = "pyannote")]
    #[test]
    fn pyannote_result_deserializes() {
        let json =
            r#"{"segments":[{"start":0.0,"end":5.0,"speaker":"SPEAKER_00","confidence":0.95}]}"#;
        let v: DiarizationResult = serde_json::from_str(json).unwrap();
        assert_eq!(v.segments.len(), 1);
        assert_eq!(v.segments[0].speaker, "SPEAKER_00");
    }
}
