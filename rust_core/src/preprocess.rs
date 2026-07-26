//! Audio preprocessing: simple noise reduction before STT.
//!
//! Implements a basic high-pass filter + normalization pipeline
//! to improve Whisper accuracy in noisy environments.

/// Apply preprocessing to raw f32 PCM audio (16kHz mono).
///
/// Pipeline:
/// 1. DC blocker — remove DC offset
/// 2. Simple high-pass filter (~80Hz cutoff) — reduce rumble/low noise
/// 3. Normalize — scale to -3dB peak
pub fn preprocess(samples: &[f32]) -> Vec<f32> {
    if samples.is_empty() {
        return samples.to_vec();
    }

    let mut out = samples.to_vec();

    // 1. DC Blocker: y[n] = x[n] - x[n-1] + 0.995 * y[n-1]
    let mut prev_x = 0.0f32;
    let mut prev_y = 0.0f32;
    for sample in out.iter_mut() {
        let x = *sample;
        let y = x - prev_x + 0.995 * prev_y;
        prev_x = x;
        prev_y = y;
        *sample = y;
    }

    // 2. Simple high-pass (first-order IIR, ~80Hz at 16kHz)
    //    H(z) = (1 - a) / (1 - a*z^-1), a = exp(-2*pi*80/16000)
    let a = 0.969_07f32; // exp(-2*pi*80/16000)
    let b = 1.0 - a;     // 0.03093
    prev_y = 0.0f32;
    for sample in out.iter_mut() {
        let x = *sample;
        let y = b * x + a * prev_y;
        prev_y = y;
        *sample = y;
    }

    // 3. Normalize: find peak, scale to -3dB (0.707)
    let peak = out
        .iter()
        .map(|s| s.abs())
        .fold(0.0f32, f32::max);
    if peak > 0.001 {
        let gain = (0.707 / peak).min(3.0); // max 3x gain to avoid amplifying noise too much
        for sample in out.iter_mut() {
            *sample = (*sample * gain).clamp(-1.0, 1.0);
        }
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dc_blocker_removes_dc_offset() {
        let dc_audio = vec![0.5f32; 1000];
        let result = preprocess(&dc_audio);
        // DC should be reduced (may not fully converge in 1000 samples)
        let mean = result.iter().sum::<f32>() / result.len() as f32;
        assert!(mean.abs() < 0.3, "DC offset not reduced: mean={}", mean);
        // Last 100 samples should be closer to zero
        let tail_mean = result[result.len()-100..].iter().sum::<f32>() / 100.0;
        assert!(tail_mean.abs() < 0.2, "DC tail not converging: mean={}", tail_mean);
    }

    #[test]
    fn empty_input_returns_empty() {
        assert!(preprocess(&[]).is_empty());
    }

    #[test]
    fn normalization_works() {
        let loud = vec![0.9f32; 100];
        let result = preprocess(&loud);
        let peak = result.iter().map(|s| s.abs()).fold(0.0f32, f32::max);
        assert!(peak <= 1.0, "Peak too high: {}", peak);
        assert!(peak > 0.0, "Silence after normalization");
    }

    #[test]
    fn sine_wave_preserved() {
        let sine: Vec<f32> = (0..1600)
            .map(|i| (i as f32 * 440.0 * 2.0 * std::f32::consts::PI / 16000.0).sin())
            .collect();
        let result = preprocess(&sine);
        // Should still have signal
        let rms = (result.iter().map(|s| s * s).sum::<f32>() / result.len() as f32).sqrt();
        assert!(rms > 0.01, "Sine wave attenuated too much: rms={}", rms);
    }
}
