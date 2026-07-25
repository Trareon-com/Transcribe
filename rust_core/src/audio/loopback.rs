//! Platform-specific speaker loopback capture.
//!
//! | Platform | Technique |
//! |----------|-----------|
//! | macOS    | BlackHole 2ch via cpal (primary) + ffmpeg avfoundation (fallback) |
//! | Windows  | WASAPI loopback (`AUDCLNT_STREAMFLAGS_LOOPBACK`) |
//! | Linux    | ffmpeg PulseAudio monitor (primary) + parec (fallback) |

use crate::audio::capture::AudioCapture;
use crate::error::TrascribeError;
use std::sync::mpsc;

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
        let _ = (device_hint, samples_tx);
        Err(TrascribeError::AudioDevice("loopback not supported".into()))
    }
}

// ---------------------------------------------------------------------------
// macOS — BlackHole via cpal, fallback to ffmpeg avfoundation
// ---------------------------------------------------------------------------
#[cfg(target_os = "macos")]
pub(crate) mod macos {
    use crate::audio::capture::AudioCapture;
    use crate::error::TrascribeError;
    use std::io::Read;
    use std::process::{Command, Stdio};
    use std::sync::mpsc;

    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let device_name = device_hint
            .filter(|s| !s.is_empty())
            .or_else(|| Some("BlackHole 2ch".to_string()));

        // Try cpal with BlackHole first (if installed)
        let cpal_result = AudioCapture::start(device_name.clone(), samples_tx.clone());
        if cpal_result.is_ok() {
            return cpal_result;
        }

        // Fallback: ffmpeg avfoundation system audio capture
        // ffmpeg -f avfoundation -i ":default" -ac 1 -ar 16000 -f f32le pipe:1
        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TrascribeError>>();

        let thread = std::thread::spawn(move || {
            let result = (|| -> Result<(), TrascribeError> {
                let mut child = Command::new("ffmpeg")
                    .args([
                        "-hide_banner",
                        "-loglevel",
                        "error",
                        "-f",
                        "avfoundation",
                        "-i",
                        ":default",
                        "-ac",
                        "1",
                        "-ar",
                        "16000",
                        "-f",
                        "f32le",
                        "-",
                    ])
                    .stdout(Stdio::piped())
                    .stderr(Stdio::null())
                    .spawn()
                    .map_err(|e| {
                        TrascribeError::AudioDevice(format!(
                            "ffmpeg not found. Install: brew install ffmpeg ({e})"
                        ))
                    })?;

                let stdout = child
                    .stdout
                    .take()
                    .ok_or_else(|| TrascribeError::AudioDevice("no stdout from ffmpeg".into()))?;

                let _ = ready_tx.send(Ok(()));
                let mut reader = std::io::BufReader::new(stdout);
                let mut buf = [0u8; 8192];

                loop {
                    if stop_rx.try_recv().is_ok() {
                        let _ = child.kill();
                        break;
                    }
                    match reader.read(&mut buf) {
                        Ok(0) => break,
                        Ok(n) if n >= 4 => {
                            let f32s: Vec<f32> = buf[..n]
                                .chunks(4)
                                .filter_map(|c| {
                                    if c.len() == 4 {
                                        Some(f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                                    } else {
                                        None
                                    }
                                })
                                .collect();
                            if !f32s.is_empty() {
                                let _ = samples_tx.send(f32s);
                            }
                        }
                        _ => {}
                    }
                }
                let _ = child.wait();
                Ok(())
            })();
            let _ = ready_tx.send(result);
        });

        match ready_rx.recv() {
            Ok(Ok(())) => Ok(AudioCapture::new(stop_tx, thread)),
            Ok(Err(e)) => Err(e),
            Err(_) => Err(TrascribeError::AudioDevice("ffmpeg thread failed".into())),
        }
    }
}

// ---------------------------------------------------------------------------
// Windows — WASAPI loopback
// ---------------------------------------------------------------------------
#[cfg(target_os = "windows")]
pub(crate) mod windows {
    use crate::audio::capture::AudioCapture;
    use crate::decode::resample_to_target;
    use crate::error::TrascribeError;
    use std::sync::mpsc;
    // The `windows` crate (not `windows-sys`) is used here specifically because
    // it generates ergonomic method-call bindings for COM interfaces
    // (`client.Start()`, etc). `windows-sys` only gives raw `*mut c_void`
    // pointers with no vtable dispatch and no per-interface IID constants, so
    // none of the interface method calls below would compile against it.
    use windows::Win32::Media::Audio::{
        eConsole, eRender, IAudioCaptureClient, IAudioClient, IMMDeviceEnumerator,
        MMDeviceEnumerator, AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK,
    };
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoTaskMemFree, CLSCTX_ALL, COINIT_APARTMENTTHREADED,
    };

    pub fn capture_loopback(
        _device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TrascribeError>>();

        let thread = std::thread::spawn(move || {
            let result = unsafe { run_wasapi_loopback(&samples_tx, &stop_rx, &ready_tx) };
            let _ = ready_tx.send(result);
        });

        match ready_rx.recv() {
            Ok(Ok(())) => Ok(AudioCapture::new(stop_tx, thread)),
            Ok(Err(e)) => Err(e),
            Err(_) => Err(TrascribeError::AudioDevice("WASAPI thread failed".into())),
        }
    }

    unsafe fn run_wasapi_loopback(
        samples_tx: &mpsc::Sender<Vec<f32>>,
        stop_rx: &mpsc::Receiver<()>,
        ready_tx: &mpsc::Sender<Result<(), TrascribeError>>,
    ) -> Result<(), TrascribeError> {
        let _ = CoInitializeEx(None, COINIT_APARTMENTTHREADED);

        let enumerator: IMMDeviceEnumerator =
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)
                .map_err(|e| TrascribeError::AudioDevice(format!("CoCreateInstance: {e}")))?;

        let device = enumerator
            .GetDefaultAudioEndpoint(eRender, eConsole)
            .map_err(|e| TrascribeError::AudioDevice(format!("GetDefaultAudioEndpoint: {e}")))?;

        let client: IAudioClient = device
            .Activate(CLSCTX_ALL, None)
            .map_err(|e| TrascribeError::AudioDevice(format!("Activate: {e}")))?;

        let fmt = client
            .GetMixFormat()
            .map_err(|e| TrascribeError::AudioDevice(format!("GetMixFormat: {e}")))?;
        let sr = (*fmt).nSamplesPerSec;
        let ch = (*fmt).nChannels as usize;

        client
            .Initialize(
                AUDCLNT_SHAREMODE_SHARED,
                AUDCLNT_STREAMFLAGS_LOOPBACK,
                0,
                0,
                fmt,
                None,
            )
            .map_err(|e| TrascribeError::AudioDevice(format!("Initialize: {e}")))?;
        CoTaskMemFree(Some(fmt.cast()));

        let cc: IAudioCaptureClient = client
            .GetService()
            .map_err(|e| TrascribeError::AudioDevice(format!("GetService: {e}")))?;

        client
            .Start()
            .map_err(|e| TrascribeError::AudioDevice(format!("Start: {e}")))?;
        let _ = ready_tx.send(Ok(()));

        let batch = (sr / 10) as u32;
        let mut accum: Vec<f32> = Vec::with_capacity(batch as usize * 2);

        loop {
            if stop_rx.try_recv().is_ok() {
                break;
            }
            let sz = cc.GetNextPacketSize().unwrap_or(0);
            if sz == 0 {
                std::thread::sleep(std::time::Duration::from_millis(5));
                continue;
            }
            let mut ptr: *mut u8 = std::ptr::null_mut();
            let mut frames: u32 = 0;
            let mut flags: u32 = 0;
            if cc
                .GetBuffer(&mut ptr, &mut frames, &mut flags, None, None)
                .is_err()
                || ptr.is_null()
                || frames == 0
            {
                let _ = cc.ReleaseBuffer(frames);
                continue;
            }

            let float_data = std::slice::from_raw_parts(ptr as *const f32, frames as usize * ch);
            let mono: Vec<f32> = float_data
                .chunks(ch)
                .map(|f| f.iter().sum::<f32>() / ch as f32)
                .collect();
            accum.extend(mono);
            let _ = cc.ReleaseBuffer(frames);

            if accum.len() >= batch as usize {
                if let Ok(r) = resample_to_target(&accum, sr) {
                    let _ = samples_tx.send(r);
                }
                accum.clear();
            }
        }
        let _ = client.Stop();
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Linux — ffmpeg PulseAudio monitor, fallback to parec
// ---------------------------------------------------------------------------
#[cfg(target_os = "linux")]
pub(crate) mod linux {
    use crate::audio::capture::AudioCapture;
    use crate::error::TrascribeError;
    use std::io::Read;
    use std::process::{Command, Stdio};
    use std::sync::mpsc;

    pub fn capture_loopback(
        _device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TrascribeError> {
        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TrascribeError>>();

        let thread = std::thread::spawn(move || {
            let result = run_linux_loopback(&samples_tx, &stop_rx, &ready_tx);
            let _ = ready_tx.send(result);
        });

        match ready_rx.recv() {
            Ok(Ok(())) => Ok(AudioCapture::new(stop_tx, thread)),
            Ok(Err(e)) => Err(e),
            Err(_) => Err(TrascribeError::AudioDevice(
                "Linux loopback thread failed".into(),
            )),
        }
    }

    fn run_linux_loopback(
        samples_tx: &mpsc::Sender<Vec<f32>>,
        stop_rx: &mpsc::Receiver<()>,
        ready_tx: &mpsc::Sender<Result<(), TrascribeError>>,
    ) -> Result<(), TrascribeError> {
        // ffmpeg -f pulse -i default -ac 1 -ar 16000 -f f32le -
        // fallback: parec --rate=16000 --channels=1 --format=float32le
        let mut child = Command::new("ffmpeg")
            .args([
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "pulse",
                "-i",
                "default",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-f",
                "f32le",
                "-",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn();

        if child.is_err() {
            child = Command::new("parec")
                .args(["--rate=16000", "--channels=1", "--format=float32le"])
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .spawn();
        }

        let mut child =
            child.map_err(|e| TrascribeError::AudioDevice(format!("need ffmpeg or parec: {e}")))?;
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| TrascribeError::AudioDevice("no stdout".into()))?;

        let _ = ready_tx.send(Ok(()));
        let mut reader = std::io::BufReader::new(stdout);
        let mut buf = [0u8; 8192];

        loop {
            if stop_rx.try_recv().is_ok() {
                let _ = child.kill();
                break;
            }
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) if n >= 4 => {
                    let f32s: Vec<f32> = buf[..n]
                        .chunks(4)
                        .filter_map(|c| {
                            if c.len() == 4 {
                                Some(f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                            } else {
                                None
                            }
                        })
                        .collect();
                    if !f32s.is_empty() {
                        let _ = samples_tx.send(f32s);
                    }
                }
                _ => {}
            }
        }
        let _ = child.wait();
        Ok(())
    }
}
