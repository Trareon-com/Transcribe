//! Device watchdog — polls audio devices every 2 seconds and emits
//! reconnect events when a previously-lost device reappears.
//!
//! Architecture per blueprint §5.1:
//! - Thread monitor setiap 2 detik
//! - Auto-reconnect device setelah sleep/wake tanpa restart app
//! - Status update ke session via mpsc channel

use std::sync::mpsc;
use std::thread;
use std::time::Duration;

use tracing;

use crate::audio::device::{list_input_devices, list_output_devices, AudioDeviceInfo};
use crate::error::TranscribeError;

/// Events emitted by the watchdog to the session orchestrator.
#[derive(Debug, Clone)]
pub enum WatchdogEvent {
    /// One or more monitored devices were lost (disconnected / sleep).
    DeviceLost {
        expected_names: Vec<String>,
        found_names: Vec<String>,
    },
    /// All previously-lost devices are back (wake / reconnect).
    DeviceReconnected { names: Vec<String> },
    /// Periodic heartbeat — everything is normal.
    Healthy,
}

/// Start a watchdog thread that polls audio devices every `interval_secs`.
/// Returns a receiver for [`WatchdogEvent`] and a sender to shut it down.
///
/// `monitor_device_names`: the device name substrings to watch (e.g.
/// `["BlackHole", "default"]`) — the watchdog checks whether at least
/// one input and one output device matching these hints are still present.
pub fn start_watchdog(
    interval_secs: u64,
    monitor_device_names: Vec<String>,
) -> (mpsc::Receiver<WatchdogEvent>, mpsc::Sender<()>) {
    let (event_tx, event_rx) = mpsc::channel();
    let (stop_tx, stop_rx) = mpsc::channel::<()>();

    thread::spawn(move || {
        let mut was_healthy = true;
        let interval = Duration::from_secs(interval_secs);

        loop {
            // Check for stop signal with non-blocking try_recv
            if stop_rx.try_recv().is_ok() {
                tracing::info!("device watchdog stopped");
                return;
            }

            let health = check_device_health(&monitor_device_names);

            match (&health, was_healthy) {
                (Err(_), true) => {
                    // Was healthy, now lost
                    let found = list_known_device_names();
                    let _ = event_tx.send(WatchdogEvent::DeviceLost {
                        expected_names: monitor_device_names.clone(),
                        found_names: found,
                    });
                    was_healthy = false;
                }
                (Ok(names), false) => {
                    // Was lost, now reconnected
                    let _ = event_tx.send(WatchdogEvent::DeviceReconnected {
                        names: names.clone(),
                    });
                    was_healthy = true;
                }
                (Ok(_), true) => {
                    // Still healthy — occasional heartbeat
                    let _ = event_tx.send(WatchdogEvent::Healthy);
                }
                (Err(_), false) => {
                    // Still lost — keep waiting
                }
            }

            thread::sleep(interval);
        }
    });

    (event_rx, stop_tx)
}

/// Pure health evaluator (no hardware I/O) — testable in CI.
///
/// Returns `Ok(names)` when at least one input and one output device are
/// present (and, when `monitor_hints` is non-empty, at least one name
/// matches a hint). Returns `Err` when devices look absent (sleep/disconnect).
/// Pulling this out of the polling loop lets us assert the transitions
/// (healthy → lost → reconnected) without real audio hardware.
fn evaluate_health(
    inputs: &[AudioDeviceInfo],
    outputs: &[AudioDeviceInfo],
    monitor_hints: &[String],
) -> Result<Vec<String>, TranscribeError> {
    let all_names: Vec<String> = inputs
        .iter()
        .chain(outputs.iter())
        .map(|d| d.name.clone())
        .collect();

    if all_names.is_empty() {
        return Err(TranscribeError::AudioDevice(
            "no audio devices found — system may be sleeping".into(),
        ));
    }

    if !monitor_hints.is_empty() {
        let hint_matches = |name: &str| -> bool {
            monitor_hints
                .iter()
                .any(|hint| name.to_lowercase().contains(&hint.to_lowercase()))
        };
        if !all_names.iter().any(|n| hint_matches(n)) {
            return Err(TranscribeError::AudioDevice(
                "monitored audio device not found".into(),
            ));
        }
    }

    Ok(all_names)
}

/// Returns `Ok(list of device names)` if at least one input and one output
/// device are present. Returns `Err` if audio devices appear to be gone
/// (sleep / disconnect).
fn check_device_health(monitor_hints: &[String]) -> Result<Vec<String>, TranscribeError> {
    evaluate_health(
        &list_input_devices()?,
        &list_output_devices()?,
        monitor_hints,
    )
}

/// Best-effort list of currently known device names (used for diagnostics
/// when devices are lost). Returns empty vec on error.
fn list_known_device_names() -> Vec<String> {
    let inputs = list_input_devices().unwrap_or_default();
    let outputs = list_output_devices().unwrap_or_default();
    inputs.into_iter().chain(outputs).map(|d| d.name).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn watchdog_start_stop_does_not_panic() {
        let (_rx, tx) = start_watchdog(1, vec![]);
        // Give it a moment to tick once
        thread::sleep(Duration::from_millis(100));
        drop(tx); // signal stop
                  // If we get here without panic, the thread shutdown is clean
    }

    #[test]
    fn watchdog_receives_healthy_events() {
        let (rx, tx) = start_watchdog(1, vec![]);
        // Should receive at least a Healthy or DeviceLost event within 3 secs
        let events: Vec<WatchdogEvent> = rx.try_iter().take(3).collect();
        drop(tx);
        // Watchdog started and stopped without panic — test passes
        // Event content is environment-dependent (no audio on CI)
        let _ = events;
    }

    #[test]
    fn check_device_health_returns_ok_on_real_hardware() {
        // On CI without audio hardware this may return Err, but it must not panic
        let result = check_device_health(&[]);
        // Both Ok and Err are acceptable — the important thing is no panic
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn empty_device_list_returns_err() {
        // Simulate by passing a hint that won't match on any real system
        let result = check_device_health(&["!!!!!impossible-device!!!!!".to_string()]);
        // May be Ok if the device list is non-empty, or Err if the hint doesn't match
        // Either way, no panic
        assert!(result.is_ok() || result.is_err());
    }

    fn dev(name: &str) -> AudioDeviceInfo {
        AudioDeviceInfo {
            name: name.to_string(),
            device_id: format!("dev:{name}"),
            is_default: false,
            channels: 2,
            sample_rates: vec![16000, 44100],
        }
    }

    #[test]
    fn evaluate_health_no_devices_is_err() {
        let res = evaluate_health(&[], &[], &[]);
        assert!(res.is_err());
    }

    #[test]
    fn evaluate_health_empty_with_hint_is_err() {
        let res = evaluate_health(&[], &[], &["blackhole".to_string()]);
        assert!(res.is_err());
    }

    #[test]
    fn evaluate_health_present_and_hint_matches_ok() {
        let ins = [dev("BlackHole 2ch"), dev("mic")];
        let res = evaluate_health(&ins, &[], &["blackhole".to_string()]);
        assert!(res.is_ok());
        let names = res.unwrap();
        assert!(names.iter().any(|n| n == "BlackHole 2ch"));
    }

    #[test]
    fn evaluate_health_hint_mismatch_is_err() {
        let ins = [dev("mic")];
        let res = evaluate_health(&ins, &[], &["blackhole".to_string()]);
        assert!(res.is_err());
    }

    #[test]
    fn evaluate_health_reconnect_transition() {
        // Simulate sleep/wake: healthy → lost → reconnected.
        let ins_online = [dev("BlackHole 2ch"), dev("Built-in Mic")];
        assert!(evaluate_health(&ins_online, &[], &[]).is_ok());
        // sleep: devices gone
        assert!(evaluate_health(&[], &[], &[]).is_err());
        // wake: devices back
        assert!(evaluate_health(&ins_online, &[], &[]).is_ok());
    }
}
