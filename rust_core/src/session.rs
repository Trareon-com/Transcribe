//! Session registry: tracks live capture sessions by UUID and their
//! mic/speaker toggle state. Actual audio thread wiring (cpal streams,
//! VAD/STT pipeline hookup) is a hardware-dependent integration step
//! exercised via manual smoke tests, not CI unit tests — this module owns
//! the pure state machine so it stays fully testable.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use serde::Serialize;
use uuid::Uuid;

use crate::audio::{SessionConfig, SessionMode};
use crate::error::{TrascribeError, TrascribeResult};

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
    segments_count: u32,
}

fn registry() -> &'static Mutex<HashMap<String, SessionState>> {
    static REGISTRY: OnceLock<Mutex<HashMap<String, SessionState>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn start_session(config: SessionConfig) -> TrascribeResult<String> {
    let id = Uuid::new_v4().to_string();
    let state = SessionState {
        config,
        started_at: std::time::Instant::now(),
        segments_count: 0,
    };
    registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?
        .insert(id.clone(), state);
    Ok(id)
}

pub fn stop_session(session_id: &str) -> TrascribeResult<()> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?;
    reg.remove(session_id)
        .map(|_| ())
        .ok_or_else(|| TrascribeError::SessionNotFound(session_id.to_string()))
}

pub fn toggle_mic(session_id: &str, enabled: bool) -> TrascribeResult<()> {
    with_session_mut(session_id, |s| s.config.mic_enabled = enabled)
}

pub fn toggle_speaker(session_id: &str, enabled: bool) -> TrascribeResult<()> {
    with_session_mut(session_id, |s| s.config.speaker_enabled = enabled)
}

pub fn set_session_mode(session_id: &str, mode: SessionMode) -> TrascribeResult<()> {
    with_session_mut(session_id, |s| {
        let (mic, spk) = mode.default_toggles();
        s.config.mode = mode;
        s.config.mic_enabled = mic;
        s.config.speaker_enabled = spk;
    })
}

pub fn record_segment(session_id: &str) -> TrascribeResult<()> {
    with_session_mut(session_id, |s| s.segments_count += 1)
}

pub fn get_status(session_id: &str) -> TrascribeResult<SessionStatus> {
    let reg = registry()
        .lock()
        .map_err(|_| TrascribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get(session_id)
        .ok_or_else(|| TrascribeError::SessionNotFound(session_id.to_string()))?;

    Ok(SessionStatus {
        session_id: session_id.to_string(),
        elapsed_seconds: state.started_at.elapsed().as_secs_f64(),
        mic_enabled: state.config.mic_enabled,
        speaker_enabled: state.config.speaker_enabled,
        segments_count: state.segments_count,
        model_loaded: true,
    })
}

fn with_session_mut(session_id: &str, f: impl FnOnce(&mut SessionState)) -> TrascribeResult<()> {
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
}
