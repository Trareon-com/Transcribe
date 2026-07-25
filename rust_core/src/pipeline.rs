//! Live PCM pipeline shared by capture workers.
//!
//! The pipeline deliberately owns only deterministic processing state. Audio
//! device threads remain responsible for capture and send resampled PCM here;
//! this keeps cpal platform details out of VAD/STT orchestration.

use crate::audio::RingBuffer;
use crate::dedupe::is_echo;
use crate::error::{TrascribeError, TrascribeResult};
use crate::export::Segment;
use crate::stt::WhisperEngine;
use crate::vad::{DualVad, VadConfig, FRAME_SAMPLES_10MS};

pub struct LivePipeline<'a> {
    engine: &'a WhisperEngine,
    ring: RingBuffer,
    vad: DualVad,
    source: String,
    language: Option<String>,
    samples_seen: u64,
    emitted: Vec<Segment>,
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
            source: source.into(),
            language,
            samples_seen: 0,
            emitted: Vec::new(),
        })
    }

    /// Ingest one or more 16 kHz mono f32 samples.
    ///
    /// Chunks are only sent to Whisper after at least one 10 ms frame in the
    /// input is confirmed as speech. Returned segments have already passed
    /// cross-source echo filtering against previously emitted segments.
    pub fn ingest(&mut self, samples: &[f32]) -> TrascribeResult<Vec<Segment>> {
        if samples.is_empty() {
            return Ok(Vec::new());
        }

        let has_speech = samples
            .chunks_exact(FRAME_SAMPLES_10MS)
            .try_fold(false, |found, frame| {
                Ok::<bool, TrascribeError>(found || self.vad.is_speech(&to_i16(frame))?)
            })?;
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
            for segment in segments {
                if !is_echo(&segment, &self.emitted) {
                    self.emitted.push(segment.clone());
                    fresh.push(segment);
                }
            }
        }
        Ok(fresh)
    }

    pub fn emitted_segments(&self) -> &[Segment] {
        &self.emitted
    }
}

fn to_i16(samples: &[f32]) -> Vec<i16> {
    samples
        .iter()
        .map(|sample| (sample.clamp(-1.0, 1.0) * i16::MAX as f32) as i16)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::to_i16;

    #[test]
    fn pcm_conversion_clamps_float_bounds() {
        assert_eq!(
            to_i16(&[-2.0, -1.0, 0.0, 1.0, 2.0]),
            vec![-32767, -32767, 0, 32767, 32767]
        );
    }
}
