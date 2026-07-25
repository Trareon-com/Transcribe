//! Live audio capture: opens a cpal input stream and forwards resampled
//! 16kHz mono f32 PCM to a channel. Runs the stream on a dedicated OS
//! thread since `cpal::Stream` isn't `Send` on most platforms.
//!
//! Config resolution and error paths are unit-tested; actually opening a
//! stream requires a real audio device and is exercised via manual smoke
//! test (see the project test plan), not CI.

use std::sync::mpsc;
use std::thread::JoinHandle;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, StreamConfig};

use crate::decode::resample_to_target;
use crate::error::TrascribeError;

/// A running capture session. Dropping this stops the stream and joins
/// the capture thread. Not FRB-exposed — driven from Rust-side session
/// orchestration, not directly from Dart.
#[flutter_rust_bridge::frb(ignore)]
pub struct AudioCapture {
    stop_tx: Option<mpsc::Sender<()>>,
    thread: Option<JoinHandle<()>>,
}

impl AudioCapture {
    /// Start capturing from the named device (or the system default input
    /// if `device_name` is `None`). Resampled mono f32 PCM chunks are sent
    /// on `samples_tx` as they arrive; the receiver end typically feeds a
    /// [`crate::audio::RingBuffer`].
    pub fn start(
        device_name: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<Self, TrascribeError> {
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TrascribeError>>();
        let (stop_tx, stop_rx) = mpsc::channel::<()>();

        let thread = std::thread::spawn(move || {
            let outcome = Self::run_capture_thread(device_name, samples_tx, stop_rx, &ready_tx);
            // If run_capture_thread returned before signaling readiness
            // (e.g. device/config resolution failed), make sure the
            // caller's ready_rx.recv() below still unblocks.
            let _ = ready_tx.send(outcome);
        });

        match ready_rx.recv() {
            Ok(Ok(())) => Ok(Self {
                stop_tx: Some(stop_tx),
                thread: Some(thread),
            }),
            Ok(Err(e)) => Err(e),
            Err(_) => Err(TrascribeError::AudioDevice(
                "capture thread exited before signaling readiness".into(),
            )),
        }
    }

    fn run_capture_thread(
        device_name: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
        stop_rx: mpsc::Receiver<()>,
        ready_tx: &mpsc::Sender<Result<(), TrascribeError>>,
    ) -> Result<(), TrascribeError> {
        let host = cpal::default_host();
        let device = resolve_device(&host, device_name.as_deref())?;
        let config = resolve_input_config(&device)?;

        let stream = build_input_stream(&device, &config, samples_tx)?;
        stream
            .play()
            .map_err(|e| TrascribeError::AudioDevice(format!("failed to start stream: {e}")))?;

        // Signal readiness now that the stream is actually playing.
        let _ = ready_tx.send(Ok(()));

        // Block until told to stop; the stream keeps running on cpal's
        // own callback thread(s) in the meantime.
        let _ = stop_rx.recv();
        drop(stream);
        Ok(())
    }

    pub fn stop(&mut self) {
        if let Some(tx) = self.stop_tx.take() {
            let _ = tx.send(());
        }
        if let Some(handle) = self.thread.take() {
            let _ = handle.join();
        }
    }
}

impl Drop for AudioCapture {
    fn drop(&mut self) {
        self.stop();
    }
}

fn resolve_device(
    host: &cpal::Host,
    device_name: Option<&str>,
) -> Result<cpal::Device, TrascribeError> {
    match device_name {
        None => host
            .default_input_device()
            .ok_or_else(|| TrascribeError::AudioDevice("no default input device available".into())),
        Some(name) => {
            let devices = host
                .input_devices()
                .map_err(|e| TrascribeError::AudioDevice(e.to_string()))?;
            devices
                .into_iter()
                .find(|d| d.name().map(|n| n == name).unwrap_or(false))
                .ok_or_else(|| TrascribeError::AudioDevice(format!("device '{name}' not found")))
        }
    }
}

fn resolve_input_config(
    device: &cpal::Device,
) -> Result<cpal::SupportedStreamConfig, TrascribeError> {
    device
        .default_input_config()
        .map_err(|e| TrascribeError::AudioDevice(format!("no supported input config: {e}")))
}

fn build_input_stream(
    device: &cpal::Device,
    supported_config: &cpal::SupportedStreamConfig,
    samples_tx: mpsc::Sender<Vec<f32>>,
) -> Result<cpal::Stream, TrascribeError> {
    let config: StreamConfig = supported_config.config();
    let sample_format = supported_config.sample_format();
    let channels = config.channels as usize;
    let source_rate = config.sample_rate.0;

    let err_fn = |e: cpal::StreamError| {
        tracing::error!("audio input stream error: {e}");
    };

    let make_stream = |mono_from: fn(&[f32], usize) -> Vec<f32>| {
        let tx = samples_tx.clone();
        device.build_input_stream(
            &config,
            move |data: &[f32], _| {
                let mono = mono_from(data, channels);
                if let Ok(resampled) = resample_to_target(&mono, source_rate) {
                    let _ = tx.send(resampled);
                }
            },
            err_fn,
            None,
        )
    };

    let stream = match sample_format {
        SampleFormat::F32 => make_stream(downmix_f32),
        other => {
            return Err(TrascribeError::AudioDevice(format!(
                "unsupported sample format: {other:?} (only f32 input streams are handled)"
            )));
        }
    };

    stream.map_err(|e| TrascribeError::AudioDevice(format!("failed to build input stream: {e}")))
}

fn downmix_f32(data: &[f32], channels: usize) -> Vec<f32> {
    if channels <= 1 {
        return data.to_vec();
    }
    data.chunks(channels)
        .map(|frame| frame.iter().sum::<f32>() / channels as f32)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn downmix_mono_passthrough() {
        let data = vec![0.1, 0.2, 0.3];
        assert_eq!(downmix_f32(&data, 1), data);
    }

    #[test]
    fn downmix_stereo_averages_channels() {
        let data = vec![1.0, -1.0, 0.5, 0.5];
        let mono = downmix_f32(&data, 2);
        assert_eq!(mono, vec![0.0, 0.5]);
    }

    #[test]
    fn downmix_empty_is_empty() {
        assert!(downmix_f32(&[], 2).is_empty());
    }

    #[test]
    fn resolve_named_device_not_found_errors_not_panics() {
        let host = cpal::default_host();
        let result = resolve_device(&host, Some("definitely-not-a-real-device-xyz123"));
        assert!(result.is_err());
    }

    #[test]
    fn start_capture_on_missing_device_errors_not_panics() {
        // No real device on CI runners is fine — this must return Err
        // cleanly rather than panicking or hanging.
        let (tx, _rx) = mpsc::channel();
        let result =
            AudioCapture::start(Some("definitely-not-a-real-device-xyz123".to_string()), tx);
        assert!(result.is_err());
    }

    #[test]
    fn target_sample_rate_matches_decode_module() {
        // Sanity check that capture and decode agree on the pipeline's
        // target rate — a mismatch here would silently produce
        // double-resampled or wrong-rate audio downstream.
        assert_eq!(crate::decode::TARGET_SAMPLE_RATE, 16_000);
    }
}
