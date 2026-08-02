//! Run: cargo run --example transcribe_sample -- <audio> [model_name]
//!   model_name: tiny (default), small, base, medium
use std::path::Path;
use std::time::Instant;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let audio_path = args
        .get(1)
        .map(|s| s.as_str())
        .unwrap_or("/tmp/sample_test.wav");
    let model_name = args.get(2).map(|s| s.as_str()).unwrap_or("tiny");

    let model_file = format!("ggml-{}.bin", model_name);
    let model_path = {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home/kali".into());
        format!("{}/.cache/whisper/{}", home, model_file)
    };

    if !Path::new(&model_path).exists() {
        return Err(format!("❌ Model not found: {}. Download with:\n  curl -L -o {} https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{}",
            model_path, model_path, model_file).into());
    }

    println!("📦 Model: {}", model_path);
    println!("🔊 Audio: {}", audio_path);

    // 2. Decode audio
    let decode_start = Instant::now();
    let audio = rust_core::decode::decode_audio_file(Path::new(audio_path))
        .map_err(|e| format!("Decode error: {}", e))?;
    println!(
        "📐 Decoded: {:.1}s ({} samples @ {}Hz) in {:?}",
        audio.duration_secs,
        audio.samples.len(),
        16000,
        decode_start.elapsed()
    );

    // 3. Load engine
    let load_start = Instant::now();
    let engine = rust_core::stt::WhisperEngine::load(Path::new(&model_path))
        .map_err(|e| format!("Model load error: {}", e))?;
    println!("🧠 Model loaded in {:?}", load_start.elapsed());

    // 4. Transcribe
    let transcribe_start = Instant::now();
    let result = engine
        .transcribe_chunk(&audio.samples, "sample", 0.0, Some("id"))
        .map_err(|e| format!("Transcribe error: {}", e))?;

    println!("⏱️  Transcribed in {:?}", transcribe_start.elapsed());
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("📝 HASIL TRANSKRIPSI:");
    println!();

    if result.is_empty() {
        println!("   (tidak ada teks terdeteksi — mungkin model terlalu kecil atau audio terlalu pendek)");
    } else {
        for seg in &result {
            println!(
                "   [{:>6.1}s - {:>6.1}s] {}",
                seg.timestamp,
                seg.timestamp + seg.duration,
                seg.text
            );
        }
    }

    println!();
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("✅ Selesai dalam {:?}", transcribe_start.elapsed());

    Ok(())
}
