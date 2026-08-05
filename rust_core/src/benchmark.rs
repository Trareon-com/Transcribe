use crate::stt::WhisperEngine;
use std::time::Instant;

pub fn benchmark_rtf(engine: &WhisperEngine) -> f64 {
    // Generate 5s dummy sine wave (16kHz)
    let samples = (0..80000)
        .map(|i| ((i as f32 / 16000.0) * 440.0 * 2.0 * std::f32::consts::PI).sin())
        .collect::<Vec<f32>>();
    let start = Instant::now();
    let _ = engine.transcribe_chunk(&samples, "benchmark", 0.0, Some("id"), None);
    let elapsed = start.elapsed().as_secs_f64();
    if elapsed == 0.0 {
        10.0
    } else {
        5.0 / elapsed
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn benchmark_sine_wave_is_five_seconds() {
        let samples = (0..80000)
            .map(|i| ((i as f32 / 16000.0) * 440.0 * 2.0 * std::f32::consts::PI).sin())
            .collect::<Vec<f32>>();
        assert_eq!(samples.len(), 80_000);
        assert_eq!(samples.len() as f32 / 16_000.0, 5.0);
    }
}
