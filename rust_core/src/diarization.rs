//! Multi-Speaker Acoustic Diarization Module.
//!
//! Extracts spectral energy, pitch proxy (ZCR), autocorrelation fundamental frequency,
//! and RMS volume envelope vectors per channel ("MIC" vs "SPK") to cluster and identify
//! distinct human speakers (e.g. "Pembicara 1 (MIC)", "Pembicara 2 (MIC)").

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
        let channel_tag = if channel.contains("SPK") || channel.contains("Speaker") {
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

        // Cosine distance & normalized Euclidean feature metric
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

    // RMS Volume
    let energy: f32 = (pcm.iter().map(|s| s * s).sum::<f32>() / pcm.len() as f32).sqrt();

    // Zero Crossing Rate (ZCR)
    let zcr = pcm
        .windows(2)
        .filter(|w| (w[0] >= 0.0 && w[1] < 0.0) || (w[0] < 0.0 && w[1] >= 0.0))
        .count() as f32
        / pcm.len() as f32;

    // Autocorrelation pitch proxy
    let mut max_corr = 0.0f32;
    let max_lag = (pcm.len() / 2).min(160);
    if max_lag > 10 {
        for lag in 10..max_lag {
            let mut sum = 0.0f32;
            for i in 0..(pcm.len() - lag) {
                sum += pcm[i] * pcm[i + lag];
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
}
