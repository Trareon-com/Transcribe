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
use crate::error::{TrascribeError, TrascribeResult};
use crate::export::Segment;
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
    ) -> Result<Self, TrascribeError> {
        let engine = WhisperEngine::load(model_path.as_ref())?;
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
    ) -> TrascribeResult<Self> {
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
    pub fn ingest(&mut self, samples: &[f32]) -> TrascribeResult<Vec<Segment>> {
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
}
