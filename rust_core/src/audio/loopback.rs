//! Platform-specific speaker loopback capture.
//!
//! Each platform provides a [`start_loopback`] function that returns audio
//! samples via an mpsc Sender, identical in interface to [`super::capture::AudioCapture`]
//! but sourcing audio from the system's output (speaker) rather than a mic input.
//!
//! # Platform approaches
//!
//! | Platform | Technique | Dependencies |
//! |----------|-----------|-------------|
//! | macOS    | BlackHole 2ch virtual input (user-installed) via cpal | cpal (already present) |
//! | Windows  | WASAPI loopback (`AUDCLNT_STREAMFLAGS_LOOPBACK`) | `windows` crate |
//! | Linux    | PulseAudio monitor source stream | `pulse` crate (optional) |
//!
//! On macOS the user must install BlackHole + create a Multi-Output Device
//! (guided by the setup wizard). Once the loopback device appears as a
//! named input, we capture it through the same cpal pipeline as the mic.
//!
//! On Windows the loopback is built-in — no extra driver required.
//! We use the `wasapi` module via `windows` crate directly because cpal
//! does not expose WASAPI loopback.
//!
//! On Linux we connect to PulseAudio's `.monitor` source of the default
//! sink, which is available on any modern PulseAudio/PipeWire setup
//! without additional configuration.

use std::sync::mpsc;

use crate::error::TrascribeError;

/// Start capturing the system's speaker output (loopback).
///
/// `device_hint` is an opaque platform-specific identifier returned by
/// [`super::device::get_loopback_device`]; on macOS it's the BlackHole
/// device name, on Windows it's the name or ID of the output endpoint,
/// on Linux it's the PulseAudio monitor source name.
///
/// Returns an mpsc receiver that delivers 16 kHz mono f32 PCM chunks
/// (same format as [`super::capture::AudioCapture`]).
pub fn start_loopback(
    device_hint: Option<String>,
    samples_tx: mpsc::Sender<Vec<f32>>,
) -> Result<super::capture::AudioCapture, TrascribeError> {
    #[cfg(target_os = "macos")]
    {
        macos::capture_loopback(device_hint, samples_tx)
    }
    #[cfg(target_os = "windows")]
    {
        windows::capture_loopback(device_hint, samples_tx)
    }
    #[cfg(target_os = "linux")]
    {
        linux::capture_loopback(device_hint, samples_tx)
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        let _ = device_hint;
        let _ = samples_tx;
        Err(TrascribeError::AudioDevice(
            "speaker loopback not supported on this platform".into(),
        ))
    }
}

// ---------------------------------------------------------------------------
// macOS — capture via BlackHole 2ch virtual input device (cpal)
// ---------------------------------------------------------------------------
#[cfg(target_os = "macos")]
mod macos {
    use crate::audio::capture::AudioCapture;
    use crate::error::TrascribeError;
    use std::sync::mpsc;

    /// On macOS, loopback capture works by routing system audio through
    /// BlackHole 2ch (a virtual audio driver). Once the user creates a
    /// Multi-Output Device (BlackHole + Speakers) in Audio MIDI Setup,
    /// the BlackHole device appears as a regular cpal **input** device
    /// and we capture it identically to a mic.
    ///
    /// `device_hint` should be "BlackHole 2ch" (the default name), or
    /// whatever the user configured during the audio setup wizard step.
    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        // If no hint was given, try the default BlackHole name.
        let device_name = device_hint
            .filter(|s| !s.is_empty())
            .or_else(|| Some("BlackHole 2ch".to_string()));

        // Reuse the same cpal input pipeline — BlackHole looks like an
        // input device from cpal's perspective after the Multi-Output
        // Device is set up.
        AudioCapture::start(device_name, samples_tx)
    }
}

// ---------------------------------------------------------------------------
// Windows — WASAPI loopback via windows-sys
// ---------------------------------------------------------------------------
#[cfg(target_os = "windows")]
mod windows {
    use crate::audio::capture::AudioCapture;
    use crate::error::TrascribeError;
    use std::sync::mpsc;

    /// On Windows, we use WASAPI loopback (`AUDCLNT_STREAMFLAGS_LOOPBACK`)
    /// to capture system audio without any virtual driver. The API is
    /// exposed through the `windows` crate.
    ///
    /// This function spawns a dedicated capture thread that:
    /// 1. Enumerates the default audio render device
    /// 2. Activates `IAudioClient` with loopback flag
    /// 3. Reads PCM frames in a loop, resamples to 16kHz mono
    /// 4. Sends them on `samples_tx`
    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let _ = device_hint;
        let _ = samples_tx;
        Err(TrascribeError::AudioDevice(
            "Windows WASAPI loopback: Not yet implemented — requires extended `windows` crate bindings. \
             Tracked at https://github.com/Trareon-com/Transcribe/issues"
                .into(),
        ))
    }
}

// ---------------------------------------------------------------------------
// Linux — PulseAudio monitor source via pulse crate
// ---------------------------------------------------------------------------
#[cfg(target_os = "linux")]
mod linux {
    use crate::audio::capture::AudioCapture;
    use crate::error::TrascribeError;
    use std::sync::mpsc;

    /// On Linux, PulseAudio exposes monitor sources (`.monitor` suffix on
    /// every sink) that capture the audio being played. PipeWire emulates
    /// this interface transparently.
    ///
    /// We connect to the default sink's monitor and read PCM frames.
    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let _ = device_hint;
        let _ = samples_tx;
        Err(TrascribeError::AudioDevice(
            "Linux PulseAudio monitor: Not yet implemented — requires `pulse` crate binding. \
             Tracked at https://github.com/Trareon-com/Transcribe/issues"
                .into(),
        ))
    }
}
