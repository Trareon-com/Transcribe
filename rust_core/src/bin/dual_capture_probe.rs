use rust_core::audio::capture::AudioCapture;
use rust_core::audio::loopback::start_loopback;
use std::sync::mpsc;
use std::thread::sleep;
use std::time::Duration;

fn main() {
    println!("Starting mic capture (default input device)...");
    let (mic_tx, mic_rx) = mpsc::channel::<Vec<f32>>();
    let mut mic = AudioCapture::start(None, mic_tx).expect("mic AudioCapture::start failed");
    println!("Mic capture started OK.");

    println!("Starting speaker loopback capture...");
    let (spk_tx, spk_rx) = mpsc::channel::<Vec<f32>>();
    let mut spk = start_loopback(None, spk_tx).expect("start_loopback failed");
    println!("Speaker loopback capture started OK.");

    sleep(Duration::from_millis(500));

    let mic_chunks: Vec<_> = mic_rx.try_iter().collect();
    let spk_chunks: Vec<_> = spk_rx.try_iter().collect();
    let mic_samples: usize = mic_chunks.iter().map(|c| c.len()).sum();
    let spk_samples: usize = spk_chunks.iter().map(|c| c.len()).sum();

    println!(
        "Mic: {} chunks, {} samples received in ~500ms",
        mic_chunks.len(),
        mic_samples
    );
    println!(
        "Speaker: {} chunks, {} samples received in ~500ms",
        spk_chunks.len(),
        spk_samples
    );

    mic.stop();
    spk.stop();
    println!("Both streams stopped cleanly.");
}
