//! Generates synthetic WAV fixtures for tests that need real audio files
//! without a live mic (silence, tone, and DC-offset edge cases).
//!
//! Usage: `cargo run --bin gen_fixtures -- <output_dir>`

use std::env;
use std::path::PathBuf;

fn write_wav(path: &PathBuf, samples: &[f32], sample_rate: u32) {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer = hound::WavWriter::create(path, spec).expect("create wav writer");
    for &s in samples {
        let clamped = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
        writer.write_sample(clamped).expect("write sample");
    }
    writer.finalize().expect("finalize wav");
}

fn main() {
    let out_dir = env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("test/fixtures"));
    std::fs::create_dir_all(&out_dir).expect("create fixtures dir");

    let sample_rate = 16_000u32;
    let one_sec = sample_rate as usize;

    // Silence — VAD should reject every frame.
    write_wav(
        &out_dir.join("silence_1s.wav"),
        &vec![0.0f32; one_sec],
        sample_rate,
    );

    // 440Hz tone — clear speech-like energy for VAD/decode smoke tests.
    let tone: Vec<f32> = (0..one_sec)
        .map(|i| (2.0 * std::f32::consts::PI * 440.0 * i as f32 / sample_rate as f32).sin() * 0.8)
        .collect();
    write_wav(&out_dir.join("tone_440hz_1s.wav"), &tone, sample_rate);

    // Empty file (0 samples) — decode must error cleanly, not panic.
    write_wav(&out_dir.join("empty.wav"), &[], sample_rate);

    // Clipping edge case — samples pinned at full scale.
    let clipped = vec![1.0f32; one_sec / 2];
    write_wav(&out_dir.join("clipped_0_5s.wav"), &clipped, sample_rate);

    println!("Fixtures written to {}", out_dir.display());
}
