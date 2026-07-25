//! Session registry: tracks live capture sessions by UUID and their
//! mic/speaker toggle state. Actual audio thread wiring (cpal streams,
//! VAD/STT pipeline hookup) is a hardware-dependent integration step
//! exercised via manual smoke tests, not CI unit tests — this module owns
//! the pure state machine so it stays fully testable.

use std::collections::HashMap;
use std::sync::{mpsc, Mutex, OnceLock};

use serde::Serialize;
use uuid::Uuid;

use crate::audio::{AudioCapture, SessionConfig, SessionMode};
use crate::error::TrascribeError;
use crate::memory;
use crate::pipeline::{LiveEvent, LiveWorker};

/// Long sessions (>4h) auto-split per hour to bound memory growth (PP-21).
pub const AUTO_SPLIT_INTERVAL_SECS: u64 = 3600;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum AutoSplitReason {
    TimeBoundary,
    MemoryPressure,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionStatus {
    pub session_id: String,
    pub elapsed_seconds: f64,
    pub mic_enabled: bool,
    pub speaker_enabled: bool,
    pub segments_count: u32,
    pub model_loaded: bool,
}

struct SessionState {
    config: SessionConfig,
    started_at: std::time::Instant,
    last_split_at: std::time::Instant,
    segments_count: u32,
    mic_capture: Option<CaptureChannel>,
    speaker_capture: Option<CaptureChannel>,
}

struct CaptureChannel {
    _capture: AudioCapture,
    _worker: LiveWorker,
    events_rx: mpsc::Receiver<LiveEvent>,
}

/// Pure decision logic — trivially unit-testable without real timers or a
/// real memory read.
fn should_split(elapsed_since_last_split_secs: u64, memory_ratio: f32) -> Option<AutoSplitReason> {
    if memory::is_under_memory_pressure(memory_ratio) {
        Some(AutoSplitReason::MemoryPressure)
    } else if elapsed_since_last_split_secs >= AUTO_SPLIT_INTERVAL_SECS {
        Some(AutoSplitReason::TimeBoundary)
    } else {
        None
    }
}

fn registry() -> &'static Mutex<HashMap<String, SessionState>> {
    static REGISTRY: OnceLock<Mutex<HashMap<String, SessionState>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn start_session(config: SessionConfig) -> Result<String, TrascribeError> {
    let id = Uuid::new_v4().to_string();
    let now = std::time::Instant::now();
    let mic_capture = start_capture(
        config.mic_enabled,
        config.mic_device_id.clone(),
        &config.model_path,
        "mic",
    )?;
    let speaker_capture = start_capture(
        config.speaker_enabled,
        config.speaker_device_id.clone(),
        &config.model_path,
        "spk",
    )?;
    let state = SessionState {
        config,
        started_at: now,
        last_split_at: now,
        segments_count: 0,
        mic_capture,
        speaker_capture,
    };
    registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?
        .insert(id.clone(), state);
    Ok(id)
}

fn start_capture(
    enabled: bool,
    device_name: Option<String>,
    model_path: &str,
    source: &str,
) -> Result<Option<CaptureChannel>, TrascribeError> {
    // A missing device id means the session has not completed audio setup yet.
    // Keep the state machine usable in CI and let the setup wizard provide the
    // explicit device before enabling hardware capture.
    if !enabled || device_name.is_none() {
        return Ok(None);
    }

    let (samples_tx, samples_rx) = mpsc::channel();
    let capture = AudioCapture::start(device_name, samples_tx)?;
    let (events_tx, events_rx) = mpsc::channel();
    let worker = LiveWorker::spawn(model_path, source, None, samples_rx, events_tx)?;
    Ok(Some(CaptureChannel {
        _capture: capture,
        _worker: worker,
        events_rx,
    }))
}

pub fn stop_session(session_id: &str) -> Result<(), TrascribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?;
    reg.remove(session_id)
        .map(|_| ())
        .ok_or_else(|| TrascribeError::SessionNotFound(session_id.to_string()))
}

pub fn toggle_mic(session_id: &str, enabled: bool) -> Result<(), TrascribeError> {
    with_session_mut(session_id, |s| s.config.mic_enabled = enabled)
}

pub fn toggle_speaker(session_id: &str, enabled: bool) -> Result<(), TrascribeError> {
    with_session_mut(session_id, |s| s.config.speaker_enabled = enabled)
}

pub fn set_session_mode(session_id: &str, mode: SessionMode) -> Result<(), TrascribeError> {
    with_session_mut(session_id, |s| {
        let (mic, spk) = mode.default_toggles();
        s.config.mode = mode;
        s.config.mic_enabled = mic;
        s.config.speaker_enabled = spk;
    })
}

pub fn record_segment(session_id: &str) -> Result<(), TrascribeError> {
    with_session_mut(session_id, |s| s.segments_count += 1)
}

/// Call periodically (e.g. every minute) from the live capture loop. If it
/// returns `Some`, the caller should flush the current chunk to disk and
/// start a new file segment, then call [`mark_split`].
pub fn check_auto_split(session_id: &str) -> Result<Option<AutoSplitReason>, TrascribeError> {
    let reg = registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get(session_id)
        .ok_or_else(|| TrascribeError::SessionNotFound(session_id.to_string()))?;

    let elapsed = state.last_split_at.elapsed().as_secs();
    let memory_ratio = memory::system_memory_usage_ratio();
    Ok(should_split(elapsed, memory_ratio))
}

pub fn mark_split(session_id: &str) -> Result<(), TrascribeError> {
    with_session_mut(session_id, |s| s.last_split_at = std::time::Instant::now())
}

pub fn get_status(session_id: &str) -> Result<SessionStatus, TrascribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get_mut(session_id)
        .ok_or_else(|| TrascribeError::SessionNotFound(session_id.to_string()))?;
    state.collect_worker_events();

    Ok(SessionStatus {
        session_id: session_id.to_string(),
        elapsed_seconds: state.started_at.elapsed().as_secs_f64(),
        mic_enabled: state.config.mic_enabled,
        speaker_enabled: state.config.speaker_enabled,
        segments_count: state.segments_count,
        model_loaded: true,
    })
}

impl SessionState {
    fn collect_worker_events(&mut self) {
        for capture in [&self.mic_capture, &self.speaker_capture]
            .into_iter()
            .flatten()
        {
            while let Ok(event) = capture.events_rx.try_recv() {
                if matches!(event, LiveEvent::Segment(_)) {
                    self.segments_count = self.segments_count.saturating_add(1);
                }
            }
        }
    }
}

fn with_session_mut(
    session_id: &str,
    f: impl FnOnce(&mut SessionState),
) -> Result<(), TrascribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get_mut(session_id)
        .ok_or_else(|| TrascribeError::SessionNotFound(session_id.to_string()))?;
    f(state);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_config() -> SessionConfig {
        SessionConfig::for_mode(SessionMode::Online, "tiny".into())
    }

    #[test]
    fn start_stop_roundtrip() {
        let id = start_session(test_config()).unwrap();
        assert!(get_status(&id).is_ok());
        stop_session(&id).unwrap();
        assert!(get_status(&id).is_err());
    }

    #[test]
    fn stop_unknown_session_errors() {
        assert!(stop_session("not-a-real-session-id").is_err());
    }

    #[test]
    fn toggle_mic_updates_status() {
        let id = start_session(test_config()).unwrap();
        toggle_mic(&id, false).unwrap();
        let status = get_status(&id).unwrap();
        assert!(!status.mic_enabled);
        stop_session(&id).unwrap();
    }

    #[test]
    fn toggle_speaker_updates_status() {
        let id = start_session(test_config()).unwrap();
        toggle_speaker(&id, false).unwrap();
        let status = get_status(&id).unwrap();
        assert!(!status.speaker_enabled);
        stop_session(&id).unwrap();
    }

    #[test]
    fn set_mode_applies_default_toggles() {
        let id = start_session(test_config()).unwrap();
        set_session_mode(&id, SessionMode::Webinar).unwrap();
        let status = get_status(&id).unwrap();
        assert!(!status.mic_enabled && status.speaker_enabled);
        stop_session(&id).unwrap();
    }

    #[test]
    fn record_segment_increments_count() {
        let id = start_session(test_config()).unwrap();
        record_segment(&id).unwrap();
        record_segment(&id).unwrap();
        let status = get_status(&id).unwrap();
        assert_eq!(status.segments_count, 2);
        stop_session(&id).unwrap();
    }

    #[test]
    fn toggle_on_unknown_session_errors() {
        assert!(toggle_mic("nonexistent", true).is_err());
    }

    #[test]
    fn no_split_before_interval_or_pressure() {
        assert_eq!(should_split(0, 0.1), None);
        assert_eq!(should_split(AUTO_SPLIT_INTERVAL_SECS - 1, 0.5), None);
    }

    #[test]
    fn time_boundary_triggers_split() {
        assert_eq!(
            should_split(AUTO_SPLIT_INTERVAL_SECS, 0.1),
            Some(AutoSplitReason::TimeBoundary)
        );
    }

    #[test]
    fn memory_pressure_triggers_split_even_before_interval() {
        assert_eq!(
            should_split(10, 0.85),
            Some(AutoSplitReason::MemoryPressure)
        );
    }

    #[test]
    fn memory_pressure_takes_priority_over_time_boundary() {
        // Both conditions true — memory pressure is the more urgent reason.
        assert_eq!(
            should_split(AUTO_SPLIT_INTERVAL_SECS, 0.9),
            Some(AutoSplitReason::MemoryPressure)
        );
    }

    #[test]
    fn check_auto_split_and_mark_split_roundtrip() {
        let id = start_session(test_config()).unwrap();
        // Freshly started session, real memory ratio on a test machine
        // should be well under the emergency threshold.
        let result = check_auto_split(&id).unwrap();
        assert_ne!(result, Some(AutoSplitReason::TimeBoundary));
        mark_split(&id).unwrap();
        stop_session(&id).unwrap();
    }

    #[test]
    fn check_auto_split_unknown_session_errors() {
        assert!(check_auto_split("nonexistent").is_err());
    }
}
