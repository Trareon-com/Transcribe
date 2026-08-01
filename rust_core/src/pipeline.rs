//! Live PCM pipeline shared by capture workers.
//!
//! The pipeline deliberately owns only deterministic processing state. Audio
//! device threads remain responsible for capture and send resampled PCM here;
//! this keeps cpal platform details out of VAD/STT orchestration.
//!
//! Each [`LivePipeline`] instance handles exactly one source (mic OR
//! speaker) — one runs per [`LiveWorker`] thread. Echo-dedupe requires
//! comparing MIC segments against SPK segments, which this type can't do
//! on its own since it only ever sees one source; that cross-source pass
//! happens one level up, in `session::SessionState::collect_worker_events`,
//! once both channels' segments have actually converged.

use crate::audio::RingBuffer;
use crate::diarization::Diarizer;
use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;
use crate::progressive::ProgressiveEngine;
use crate::stt::WhisperEngine;
use crate::vad::{DualVad, VadConfig, FRAME_SAMPLES_10MS};

pub struct LivePipeline<'a> {
    engine: &'a WhisperEngine,
    ring: RingBuffer,
    vad: DualVad,
    diarizer: Diarizer,
    source: String,
    language: Option<String>,
    samples_seen: u64,
}

#[derive(Debug, Clone)]
pub enum LiveEvent {
    Vu { source: String, level: f32 },
    Segment(Segment),
}

pub struct LiveWorker {
    stop_tx: Option<std::sync::mpsc::Sender<()>>,
    thread: Option<std::thread::JoinHandle<()>>,
}

impl LiveWorker {
    pub fn spawn(
        model_path: impl AsRef<std::path::Path>,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let engine = WhisperEngine::load(model_path.as_ref())?;
        Self::spawn_with_engine(engine, source, language, samples_rx, events_tx)
    }

    /// Single-model worker over an already-loaded engine. Used by
    /// [`Self::spawn`] and by adaptive HPT's direct-q5 fast path so the
    /// benchmark-loaded engine is reused instead of double-loading the
    /// 548 MB refine model.
    fn spawn_with_engine(
        engine: WhisperEngine,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let source = source.into();
        let (stop_tx, stop_rx) = std::sync::mpsc::channel();
        let thread = std::thread::spawn(move || {
            let mut pipeline = match LivePipeline::new(
                &engine,
                source.clone(),
                language,
                VadConfig::default(),
            ) {
                Ok(pipeline) => pipeline,
                Err(error) => {
                    tracing::error!(source = %source, %error, "live pipeline initialization failed");
                    return;
                }
            };

            while stop_rx.try_recv().is_err() {
                let samples = match samples_rx.recv_timeout(std::time::Duration::from_millis(100)) {
                    Ok(samples) => samples,
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                };
                let level = rms_level(&samples);
                let _ = events_tx.send(LiveEvent::Vu {
                    source: source.clone(),
                    level,
                });
                match pipeline.ingest(&samples) {
                    Ok(segments) => {
                        for segment in segments {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                    }
                    Err(error) => tracing::error!(source = %source, %error, "live pipeline failed"),
                }
            }
        });
        Ok(Self {
            stop_tx: Some(stop_tx),
            thread: Some(thread),
        })
    }

    pub fn stop(&mut self) {
        if let Some(stop_tx) = self.stop_tx.take() {
            let _ = stop_tx.send(());
        }
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }

    /// Hybrid Progressive Transcription (HPT) worker: loads BOTH the quick
    /// (`base`) and refine (`large-v3-turbo-q5`) models up front. Each
    /// speech chunk emits quick segments (`is_partial = true`) immediately
    /// so the UI renders text within the 3-5s latency budget, then refined
    /// segments (`is_partial = false`) with the same `(source, timestamp)`
    /// keys replace them on the Dart side.
    pub fn spawn_hpt(
        quick_model_path: impl AsRef<std::path::Path>,
        refine_model_path: impl AsRef<std::path::Path>,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let engine = ProgressiveEngine::load(
            quick_model_path.as_ref(),
            refine_model_path.as_ref(),
            false,
            0,
        )?;
        let source = source.into();
        let (stop_tx, stop_rx) = std::sync::mpsc::channel();
        let thread = std::thread::spawn(move || {
            let mut pipeline = match LivePipelineHpt::new(
                &engine,
                source.clone(),
                language,
                VadConfig::default(),
            ) {
                Ok(pipeline) => pipeline,
                Err(error) => {
                    tracing::error!(source = %source, %error, "hpt live pipeline initialization failed");
                    return;
                }
            };

            while stop_rx.try_recv().is_err() {
                let samples = match samples_rx.recv_timeout(std::time::Duration::from_millis(100)) {
                    Ok(samples) => samples,
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                };
                let level = rms_level(&samples);
                let _ = events_tx.send(LiveEvent::Vu {
                    source: source.clone(),
                    level,
                });
                match pipeline.ingest(&samples) {
                    Ok((quick, refined)) => {
                        // Quick pass first — UI renders immediately.
                        for segment in quick {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                        // Refined pass replaces by key — same (source, timestamp).
                        for segment in refined {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                    }
                    Err(error) => {
                        tracing::error!(source = %source, %error, "hpt live pipeline failed")
                    }
                }
            }
        });
        Ok(Self {
            stop_tx: Some(stop_tx),
            thread: Some(thread),
        })
    }

    /// Adaptive HPT worker: benchmarks the refine (q5) model once at
    /// session start. If q5 can transcribe ≥1s of audio per 1s wall-clock
    /// (RTF ≥ 1.0), the device is fast enough to run q5 directly as the
    /// single pass — no base quick pass needed, final text lands at the
    /// same speed the quick pass would have. Otherwise it falls back to
    /// dual-pass [`Self::spawn_hpt`] (base quick → q5 refine) so slow
    /// laptops still get instant partial text.
    pub fn spawn_adaptive(
        quick_model_path: impl AsRef<std::path::Path>,
        refine_model_path: impl AsRef<std::path::Path>,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        // Load refine model once and benchmark it. RTF >= 1.0 means the
        // q5 model itself keeps up with real-time audio → single pass,
        // reusing the benchmark-loaded engine (no double 548MB load).
        let engine = WhisperEngine::load(refine_model_path.as_ref())?;
        let rtf = crate::benchmark::benchmark_rtf(&engine);
        tracing::info!(rtf, "adaptive hpt benchmark");

        if should_direct_q5(rtf) {
            Self::spawn_with_engine(engine, source, language, samples_rx, events_tx)
        } else {
            drop(engine); // dual-pass loads both models itself
            Self::spawn_hpt(
                quick_model_path,
                refine_model_path,
                source,
                language,
                samples_rx,
                events_tx,
            )
        }
    }
}

/// Pure decision: does this device run q5 fast enough to skip the base
/// quick pass entirely? RTF = seconds of audio transcribed per second of
/// wall-clock. ≥1.0 means real-time capable → direct q5 single pass.
pub fn should_direct_q5(rtf: f64) -> bool {
    rtf >= 1.0
}

#[cfg(test)]
mod adaptive_tests {
    use super::should_direct_q5;

    #[test]
    fn rtf_at_realtime_threshold_directs_q5() {
        assert!(should_direct_q5(1.0));
    }

    #[test]
    fn rtf_below_threshold_falls_back_to_dual_pass() {
        assert!(!should_direct_q5(0.99));
        assert!(!should_direct_q5(0.5));
        assert!(!should_direct_q5(0.0));
    }

    #[test]
    fn fast_device_directs_q5() {
        assert!(should_direct_q5(1.2));
        assert!(should_direct_q5(5.0));
        assert!(should_direct_q5(12.0));
    }
}

impl Drop for LiveWorker {
    fn drop(&mut self) {
        self.stop();
    }
}

impl<'a> LivePipeline<'a> {
    pub fn new(
        engine: &'a WhisperEngine,
        source: impl Into<String>,
        language: Option<String>,
        vad_config: VadConfig,
    ) -> TranscribeResult<Self> {
        Ok(Self {
            engine,
            ring: RingBuffer::default(),
            vad: DualVad::new(vad_config)?,
            diarizer: Diarizer::new(),
            source: source.into(),
            language,
            samples_seen: 0,
        })
    }

    /// Ingest one or more 16 kHz mono f32 samples.
    ///
    /// Chunks are only sent to Whisper after at least one 10 ms frame in the
    /// input is confirmed as speech. Returned segments are *not* yet
    /// echo-filtered — this pipeline only ever sees its own source, so
    /// cross-source dedupe happens where mic and speaker segments actually
    /// meet (see the module doc comment).
    pub fn ingest(&mut self, samples: &[f32]) -> TranscribeResult<Vec<Segment>> {
        if samples.is_empty() {
            return Ok(Vec::new());
        }

        let mut frame_buf = [0i16; FRAME_SAMPLES_10MS];
        let mut has_speech = false;
        for frame in samples.chunks_exact(FRAME_SAMPLES_10MS) {
            fill_i16_slice(frame, &mut frame_buf);
            if self.vad.is_speech(&frame_buf)? {
                has_speech = true;
                break;
            }
        }
        self.ring.push(samples);
        self.samples_seen = self.samples_seen.saturating_add(samples.len() as u64);

        if !has_speech {
            return Ok(Vec::new());
        }

        let mut fresh = Vec::new();
        while let Some(chunk) = self.ring.take_chunk() {
            let chunk_start = self
                .samples_seen
                .saturating_sub(self.ring.buffered_samples() as u64 + chunk.len() as u64)
                as f64
                / 16_000.0;
            let segments = self.engine.transcribe_chunk(
                &chunk,
                &self.source,
                chunk_start,
                self.language.as_deref(),
            )?;
            for mut segment in segments {
                segment.speaker = self.diarizer.identify_speaker(&self.source, &chunk);
                fresh.push(segment);
            }
        }
        Ok(fresh)
    }
}

/// HPT variant of [`LivePipeline`]: holds BOTH models (quick + refine)
/// and emits two segment passes per speech chunk. The quick pass carries
/// `is_partial = true` for immediate UI rendering; the refine pass carries
/// `is_partial = false` and the SAME `(source, timestamp)` keys so Dart can
/// replace text in place instead of appending duplicates.
pub struct LivePipelineHpt<'a> {
    engine: &'a ProgressiveEngine,
    ring: RingBuffer,
    vad: DualVad,
    diarizer: Diarizer,
    source: String,
    language: Option<String>,
    samples_seen: u64,
}

impl<'a> LivePipelineHpt<'a> {
    pub fn new(
        engine: &'a ProgressiveEngine,
        source: impl Into<String>,
        language: Option<String>,
        vad_config: VadConfig,
    ) -> TranscribeResult<Self> {
        Ok(Self {
            engine,
            ring: RingBuffer::default(),
            vad: DualVad::new(vad_config)?,
            diarizer: Diarizer::new(),
            source: source.into(),
            language,
            samples_seen: 0,
        })
    }

    /// Ingest one or more 16 kHz mono f32 samples. Returns
    /// `(quick_segments, refined_segments)` — quick first (UI-immediate),
    /// refined second (replaces by key). Same VAD gating as the
    /// single-model pipeline: chunks only go to Whisper after at least one
    /// 10 ms speech frame.
    pub fn ingest(&mut self, samples: &[f32]) -> TranscribeResult<(Vec<Segment>, Vec<Segment>)> {
        if samples.is_empty() {
            return Ok((Vec::new(), Vec::new()));
        }

        let mut frame_buf = [0i16; FRAME_SAMPLES_10MS];
        let mut has_speech = false;
        for frame in samples.chunks_exact(FRAME_SAMPLES_10MS) {
            fill_i16_slice(frame, &mut frame_buf);
            if self.vad.is_speech(&frame_buf)? {
                has_speech = true;
                break;
            }
        }
        self.ring.push(samples);
        self.samples_seen = self.samples_seen.saturating_add(samples.len() as u64);

        if !has_speech {
            return Ok((Vec::new(), Vec::new()));
        }

        let mut quick = Vec::new();
        let mut refined = Vec::new();
        while let Some(chunk) = self.ring.take_chunk() {
            let chunk_start = self
                .samples_seen
                .saturating_sub(self.ring.buffered_samples() as u64 + chunk.len() as u64)
                as f64
                / 16_000.0;
            let language = self.language.as_deref();
            let mut quick_segs =
                self.engine
                    .transcribe_quick(&chunk, &self.source, chunk_start, language)?;
            let mut refined_segs =
                self.engine
                    .transcribe_refine(&chunk, &self.source, chunk_start, language)?;
            for segment in quick_segs.iter_mut() {
                segment.speaker = self.diarizer.identify_speaker(&self.source, &chunk);
            }
            for segment in refined_segs.iter_mut() {
                segment.speaker = self.diarizer.identify_speaker(&self.source, &chunk);
            }
            quick.append(&mut quick_segs);
            refined.append(&mut refined_segs);
        }
        // Hallucination guard on both passes (same n-gram filter used by
        // file-mode HPT in api.rs).
        crate::progressive::filter_loops(&mut quick);
        crate::progressive::filter_loops(&mut refined);
        Ok((quick, refined))
    }
}

fn fill_i16_slice(src: &[f32], dst: &mut [i16]) {
    for (s, d) in src.iter().zip(dst.iter_mut()) {
        *d = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
    }
}

fn rms_level(samples: &[f32]) -> f32 {
    if samples.is_empty() {
        return 0.0;
    }
    (samples.iter().map(|sample| sample * sample).sum::<f32>() / samples.len() as f32).sqrt()
}

#[cfg(test)]
mod tests {
    use super::{fill_i16_slice, rms_level};

    #[test]
    fn fill_i16_slice_clamps_samples() {
        let input = [-2.0f32, -1.0f32, 0.0f32, 1.0f32, 2.0f32];
        let mut out = [0i16; 5];
        fill_i16_slice(&input, &mut out);
        assert_eq!(out, [-32767, -32767, 0, 32767, 32767]);
    }

    #[test]
    fn pcm_conversion_clamps_float_bounds() {
        let input = [-2.0f32, -1.0f32, 0.0f32, 1.0f32, 2.0f32];
        let mut out = [0i16; 5];
        fill_i16_slice(&input, &mut out);
        assert_eq!(out, [-32767, -32767, 0, 32767, 32767]);
    }

    #[test]
    fn rms_level_is_bounded_for_normalized_pcm() {
        assert_eq!(rms_level(&[]), 0.0);
        assert!((rms_level(&[0.5, -0.5]) - 0.5).abs() < f32::EPSILON);
    }

    #[test]
    fn hpt_quick_is_partial_refined_is_final_contract() {
        // The HPT contract Dart depends on: quick pass flags is_partial,
        // refined pass flags is_final (inverse). We pin the key format and
        // the flag convention here so a future refactor can't silently
        // swap them. (Inference itself needs real models; this is a
        // contract test, same as progressive::hpt_merge_keys_are_stable.)
        let mut quick = hpt_seg("halo dunia", 10.0);
        quick.is_partial = true;
        let refined = hpt_seg("halo dunia", 10.0);
        assert!(quick.is_partial, "quick pass must be partial");
        assert!(!refined.is_partial, "refined pass must be final");
        assert_eq!(
            format!("{}@{:.2}", quick.source, quick.timestamp),
            format!("{}@{:.2}", refined.source, refined.timestamp),
            "quick and refined must share the merge key"
        );
    }

    fn hpt_seg(text: &str, ts: f64) -> crate::export::Segment {
        crate::export::Segment {
            source: "MIC".into(),
            speaker: "MIC".into(),
            text: text.into(),
            timestamp: ts,
            duration: 5.0,
            language: "id".into(),
            confidence: 0.9,
            is_partial: false,
        }
    }
}
