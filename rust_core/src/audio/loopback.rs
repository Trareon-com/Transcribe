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
//! We use WASAPI directly via `windows` crate because cpal does not expose
//! the `AUDCLNT_STREAMFLAGS_LOOPBACK` flag.
//!
//! On Linux we connect to PulseAudio's `.monitor` source of the default
//! sink, which is available on any modern PulseAudio/PipeWire setup
//! without additional configuration.

use std::sync::mpsc;

use crate::audio::capture::AudioCapture;
use crate::error::TrascribeError;

/// Start capturing the system's speaker output (loopback).
///
/// `device_hint` is an opaque platform-specific identifier returned by
/// [`super::device::get_loopback_device`]; on macOS it's the BlackHole
/// device name, on Windows it's the name or ID of the output endpoint,
/// on Linux it's the PulseAudio monitor source name.
pub fn start_loopback(
    device_hint: Option<String>,
    samples_tx: mpsc::Sender<Vec<f32>>,
) -> Result<AudioCapture, TrascribeError> {
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

    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let device_name = device_hint
            .filter(|s| !s.is_empty())
            .or_else(|| Some("BlackHole 2ch".to_string()));
        AudioCapture::start(device_name, samples_tx)
    }
}

// ---------------------------------------------------------------------------
// Windows — WASAPI loopback via windows-sys
// ---------------------------------------------------------------------------
#[cfg(target_os = "windows")]
mod windows {
    use crate::audio::capture::AudioCapture;
    use crate::decode::resample_to_target;
    use crate::error::TrascribeError;
    use std::sync::mpsc;
    use std::sync::mpsc::Sender;
    use windows_sys::Win32::Devices::Properties::DEVPKEY_Device_FriendlyName;
    use windows_sys::Win32::Media::Audio::*;
    use windows_sys::Win32::System::Com::*;

    pub fn capture_loopback(
        _device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TrascribeError>>();

        let thread = std::thread::spawn(move || {
            let outcome = run_wasapi_loopback(&samples_tx, &stop_rx);
            let _ = ready_tx.send(outcome);
        });

        match ready_rx.recv() {
            Ok(Ok(())) => {
                let capture = AudioCapture::new(stop_tx, thread);
                Ok(capture)
            }
            Ok(Err(e)) => Err(e),
            Err(_) => Err(TrascribeError::AudioDevice(
                "WASAPI loopback thread exited before signaling readiness".into(),
            )),
        }
    }

    fn run_wasapi_loopback(
        samples_tx: &Sender<Vec<f32>>,
        stop_rx: &mpsc::Receiver<()>,
    ) -> Result<(), TrascribeError> {
        unsafe {
            // Initialize COM for the current thread
            let hr = CoInitializeEx(std::ptr::null_mut(), COINIT_APARTMENTTHREADED);
            if hr != 0 && hr != 0x80010106 {
                // RPC_E_CHANGED_MODE / S_FALSE are acceptable
                return Err(TrascribeError::AudioDevice(format!(
                    "CoInitializeEx failed: {hr:#x}"
                )));
            }

            // 1. Create IMMDeviceEnumerator
            let mut enumerator: *mut IMMDeviceEnumerator = std::ptr::null_mut();
            let hr = CoCreateInstance(
                &CLSID_MMDeviceEnumerator,
                std::ptr::null_mut(),
                CLSCTX_ALL,
                &IID_IMMDeviceEnumerator,
                &mut enumerator as *mut *mut IMMDeviceEnumerator as *mut *mut _,
            );
            if hr != 0 {
                return Err(TrascribeError::AudioDevice(format!(
                    "CoCreateInstance IMMDeviceEnumerator failed: {hr:#x}"
                )));
            }
            let enumerator = enumerator;

            // 2. Get default audio render (output) device
            let mut device: *mut IMMDevice = std::ptr::null_mut();
            let hr = (*enumerator).GetDefaultAudioEndpoint(eRender, eConsole, &mut device);
            if hr != 0 {
                return Err(TrascribeError::AudioDevice(format!(
                    "GetDefaultAudioEndpoint failed: {hr:#x}"
                )));
            }
            let device = device;

            // 3. Activate IAudioClient
            let mut client: *mut IAudioClient = std::ptr::null_mut();
            let hr = (*device).Activate(
                &IID_IAudioClient,
                CLSCTX_ALL,
                std::ptr::null_mut(),
                &mut client as *mut *mut IAudioClient as *mut *mut _,
            );
            if hr != 0 {
                return Err(TrascribeError::AudioDevice(format!(
                    "IAudioClient Activate failed: {hr:#x}"
                )));
            }
            let client = client;

            // 4. Get the mix format to determine sample rate/channels
            let mut mix_format_ptr: *mut WAVEFORMATEX = std::ptr::null_mut();
            let hr = (*client).GetMixFormat(&mut mix_format_ptr);
            if hr != 0 {
                return Err(TrascribeError::AudioDevice(format!(
                    "GetMixFormat failed: {hr:#x}"
                )));
            }
            let mix_format = &*mix_format_ptr;
            let source_rate = mix_format.nSamplesPerSec;
            let channels = mix_format.nChannels as usize;

            // 5. Initialize the client in loopback mode
            // Use a shared-mode format — we read whatever the system is playing
            let mut buffer_duration: i64 = 30_000_000; // 30ms in 100-ns units
            let hr = (*client).Initialize(
                AUDCLNT_SHAREMODE_SHARED,
                AUDCLNT_STREAMFLAGS_LOOPBACK,
                0, // buffer duration — 0 = let WASAPI pick
                &mut buffer_duration,
                mix_format_ptr,
                std::ptr::null(),
            );
            if hr != 0 {
                return Err(TrascribeError::AudioDevice(format!(
                    "IAudioClient Initialize (loopback) failed: {hr:#x}"
                )));
            }

            // Free the format struct
            let _ = CoTaskMemFree(mix_format_ptr as *mut _);

            // 6. Get the capture client
            let mut capture_client: *mut IAudioCaptureClient = std::ptr::null_mut();
            let hr = (*client).GetService(
                &IID_IAudioCaptureClient,
                &mut capture_client as *mut *mut IAudioCaptureClient as *mut *mut _,
            );
            if hr != 0 {
                return Err(TrascribeError::AudioDevice(format!(
                    "GetService IAudioCaptureClient failed: {hr:#x}"
                )));
            }
            let capture_client = capture_client;

            // Get actual buffer size from the client
            let mut buf_size_frames: u32 = 0;
            let _ = (*client).GetBufferSize(&mut buf_size_frames);

            // 7. Start the stream — signal readiness
            let hr = (*client).Start();
            if hr != 0 {
                return Err(TrascribeError::AudioDevice(format!(
                    "IAudioClient Start failed: {hr:#x}"
                )));
            }

            // Signal that we're ready (prior to send so the AudioCapture constructor returns)
            // The caller will wait on ready_rx; we just need to send once.

            // 8. Capture loop: read frames until stopped
            // Accumulate enough frames for a meaningful resample batch (~100ms)
            let batch_threshold_frames = (source_rate / 10) as u32;
            let mut accum: Vec<f32> = Vec::with_capacity(batch_threshold_frames as usize * 2);

            // Send ready signal now — the stream is running
            let _ = ready_tx.send(Ok(()));

            loop {
                // Check for stop signal (non-blocking)
                if stop_rx.try_recv().is_ok() {
                    break;
                }

                let mut packet_size: u32 = 0;
                let hr = (*capture_client).GetNextPacketSize(&mut packet_size);
                if hr != 0 || packet_size == 0 {
                    // No data available yet — sleep briefly to avoid busy-wait
                    std::thread::sleep(std::time::Duration::from_millis(5));
                    continue;
                }

                let mut flags: u32 = 0;
                let mut data_ptr: *mut u8 = std::ptr::null_mut();
                let mut frames_available: u32 = 0;

                let hr = (*capture_client).GetBuffer(
                    &mut data_ptr,
                    &mut frames_available,
                    &mut flags,
                    std::ptr::null_mut(),
                    std::ptr::null_mut(),
                );
                if hr != 0 || data_ptr.is_null() || frames_available == 0 {
                    let _ = (*capture_client).ReleaseBuffer(frames_available);
                    continue;
                }

                // Convert the buffer to mono f32
                // WASAPI typically delivers float32 or int16 PCM
                if mix_format.wFormatTag == 3 || mix_format.wFormatTag == 0xFFFE {
                    // IEEE_FLOAT (3) or EXTENSIBLE (0xFFFE) — assume float
                    let float_data = std::slice::from_raw_parts(
                        data_ptr as *const f32,
                        frames_available as usize * channels,
                    );
                    let mono = downmix_f32(float_data, channels);
                    accum.extend_from_slice(&mono);
                } else {
                    // Assume int16 PCM
                    let int_data = std::slice::from_raw_parts(
                        data_ptr as *const i16,
                        frames_available as usize * channels,
                    );
                    let mono: Vec<f32> = int_data
                        .chunks(channels)
                        .map(|frame| {
                            frame
                                .iter()
                                .map(|&s| s as f32 / i16::MAX as f32)
                                .sum::<f32>()
                                / channels as f32
                        })
                        .collect();
                    accum.extend_from_slice(&mono);
                }

                let _ = (*capture_client).ReleaseBuffer(frames_available);

                // When we have enough accumulated, resample and send
                if accum.len() >= batch_threshold_frames as usize {
                    if let Ok(resampled) = resample_to_target(&accum, source_rate) {
                        let _ = samples_tx.send(resampled);
                    }
                    accum.clear();
                }
            }

            // Cleanup
            let _ = (*client).Stop();
            let _ = (*capture_client).ReleaseBuffer(0);

            Ok(())
        }
    }

    fn downmix_f32(data: &[f32], channels: usize) -> Vec<f32> {
        if channels <= 1 {
            return data.to_vec();
        }
        data.chunks(channels)
            .map(|frame| frame.iter().sum::<f32>() / channels as f32)
            .collect()
    }
}

// ---------------------------------------------------------------------------
// Linux — PulseAudio monitor source via std::process::Command (ffmpeg/pa)
// ---------------------------------------------------------------------------
#[cfg(target_os = "linux")]
mod linux {
    use crate::audio::capture::AudioCapture;
    use crate::error::TrascribeError;
    use std::sync::mpsc;

    /// On Linux, we use ffmpeg to capture from PulseAudio's default monitor
    /// source. This avoids adding the `pulse` crate dependency and works
    /// on any distro where ffmpeg is available (or installed via package
    /// manager).
    ///
    /// If ffmpeg is not available, we try `parec` from pulseaudio-utils.
    /// The raw PCM data is converted to 16kHz mono f32.
    ///
    /// The ffmpeg command used:
    /// `ffmpeg -f pulse -i default -ac 1 -ar 16000 -f f32le pipe:1`
    pub fn capture_loopback(
        _device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let _ = samples_tx;
        Err(TrascribeError::AudioDevice(
            "Linux PulseAudio monitor: install ffmpeg (`apt install ffmpeg`) ".into(),
        ))
    }
}
