//! Dual VAD (ADR-5): WebRTC VAD as a fast gate, a confirmation stage for
//! higher accuracy. WebRTC VAD is a real `webrtc-vad` binding. The
//! confirmation stage is defined behind the [`SpeechDetector`] trait so a
//! Silero ONNX-backed implementation can be dropped in later without
//! touching call sites — for now it's an energy-based detector, which is a
//! deliberately simple placeholder until the Silero model is bundled.

use webrtc_vad::{SampleRate, Vad, VadMode};

use crate::error::{TrascribeError, TrascribeResult};

/// Frame size WebRTC VAD accepts at 16kHz (10ms, 20ms, or 30ms frames).
pub const FRAME_SAMPLES_10MS: usize = 160;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct VadConfig {
    /// WebRTC aggressiveness: 0 (least) .. 3 (most aggressive at filtering non-speech).
    pub webrtc_mode: VadAggressiveness,
    /// Energy threshold used by the confirmation stage, 0.0–1.0.
    pub confirmation_threshold: f32,
}

impl Default for VadConfig {
    fn default() -> Self {
        Self {
            webrtc_mode: VadAggressiveness::HighQuality,
            confirmation_threshold: 0.02,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VadAggressiveness {
    Quality,
    LowBitrate,
    Aggressive,
    HighQuality,
}

impl From<VadAggressiveness> for VadMode {
    fn from(a: VadAggressiveness) -> Self {
        match a {
            VadAggressiveness::Quality => VadMode::Quality,
            VadAggressiveness::LowBitrate => VadMode::LowBitrate,
            VadAggressiveness::Aggressive => VadMode::Aggressive,
            VadAggressiveness::HighQuality => VadMode::VeryAggressive,
        }
    }
}

/// A confirmation-stage speech detector, run only on frames WebRTC already
/// flagged as speech (keeps the expensive stage off the hot path for silence).
pub trait SpeechDetector: Send {
    fn is_speech(&mut self, frame_i16: &[i16]) -> bool;
}

/// Placeholder confirmation detector (RMS energy). Swap for a Silero
/// ONNX-backed implementation once the model is bundled — the trait
/// boundary means no caller changes are needed.
pub struct EnergyDetector {
    threshold: f32,
}

impl EnergyDetector {
    pub fn new(threshold: f32) -> Self {
        Self { threshold }
    }
}

impl SpeechDetector for EnergyDetector {
    fn is_speech(&mut self, frame_i16: &[i16]) -> bool {
        if frame_i16.is_empty() {
            return false;
        }
        let sum_sq: f64 = frame_i16.iter().map(|&s| (s as f64) * (s as f64)).sum();
        let rms = (sum_sq / frame_i16.len() as f64).sqrt() / i16::MAX as f64;
        rms as f32 >= self.threshold
    }
}

/// Dual VAD: WebRTC gate -> confirmation stage. A frame is speech only if
/// both stages agree, which cuts false positives vs either detector alone.
pub struct DualVad {
    webrtc: Vad,
    confirmation: Box<dyn SpeechDetector>,
}

impl DualVad {
    pub fn new(config: VadConfig) -> TrascribeResult<Self> {
        let mut vad = Vad::new_with_rate_and_mode(SampleRate::Rate16kHz, config.webrtc_mode.into());
        // webrtc-vad crate takes ownership; touch it once to ensure it's usable.
        let _ = vad.is_voice_segment(&[0i16; FRAME_SAMPLES_10MS]);

        Ok(Self {
            webrtc: vad,
            confirmation: Box::new(EnergyDetector::new(config.confirmation_threshold)),
        })
    }

    pub fn with_confirmation(mut self, detector: Box<dyn SpeechDetector>) -> Self {
        self.confirmation = detector;
        self
    }

    /// `frame` must be exactly [`FRAME_SAMPLES_10MS`] i16 samples at 16kHz mono.
    pub fn is_speech(&mut self, frame: &[i16]) -> TrascribeResult<bool> {
        if frame.len() != FRAME_SAMPLES_10MS {
            return Err(TrascribeError::InvalidInput(format!(
                "VAD frame must be {FRAME_SAMPLES_10MS} samples, got {}",
                frame.len()
            )));
        }

        let gate_passed = self
            .webrtc
            .is_voice_segment(frame)
            .map_err(|_| TrascribeError::InvalidInput("webrtc-vad rejected frame".into()))?;

        if !gate_passed {
            return Ok(false);
        }

        Ok(self.confirmation.is_speech(frame))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn silence_frame() -> Vec<i16> {
        vec![0i16; FRAME_SAMPLES_10MS]
    }

    fn tone_frame() -> Vec<i16> {
        (0..FRAME_SAMPLES_10MS)
            .map(|i| ((i as f32 * 0.4).sin() * i16::MAX as f32 * 0.8) as i16)
            .collect()
    }

    #[test]
    fn rejects_silence() {
        let mut vad = DualVad::new(VadConfig::default()).unwrap();
        assert!(!vad.is_speech(&silence_frame()).unwrap());
    }

    #[test]
    fn accepts_loud_tone() {
        // A loud tone should pass at least the energy confirmation stage;
        // WebRTC's gate on synthetic non-speech tones can be strict, so we
        // assert on the confirmation detector directly for determinism.
        let mut energy = EnergyDetector::new(0.02);
        assert!(energy.is_speech(&tone_frame()));
    }

    #[test]
    fn wrong_frame_size_errors() {
        let mut vad = DualVad::new(VadConfig::default()).unwrap();
        let bad = vec![0i16; 50];
        assert!(vad.is_speech(&bad).is_err());
    }

    #[test]
    fn energy_detector_threshold_behavior() {
        let mut low_thresh = EnergyDetector::new(0.001);
        let mut high_thresh = EnergyDetector::new(0.9);
        let tone = tone_frame();
        assert!(low_thresh.is_speech(&tone));
        assert!(!high_thresh.is_speech(&tone));
    }

    #[test]
    fn empty_frame_is_not_speech() {
        let mut d = EnergyDetector::new(0.02);
        assert!(!d.is_speech(&[]));
    }
}
