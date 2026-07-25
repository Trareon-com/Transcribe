//! Public API surface exposed to Flutter via flutter_rust_bridge V2.
//!
//! FRB-compatible: no lifetimes in public signatures, every fallible
//! function returns `Result<T, TrascribeError>`. Streams (`vu_meter_stream`,
//! `transcript_stream`, live audio thread wiring) land once FRB codegen is
//! set up against the actual Flutter app.

use std::path::PathBuf;

use crate::audio::{AudioDeviceInfo, SessionConfig, SessionMode};
use crate::error::TrascribeError;
use crate::export::{ExportFormat, ExportedFile, Segment};
use crate::model::ModelInfo;
use crate::session::{SessionEvent, SessionRecoverySnapshot, SessionStatus};
use crate::settings::AppSettings;

pub fn engine_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn health_check() -> Result<bool, TrascribeError> {
    Ok(true)
}

// --- Audio devices -----------------------------------------------------

pub fn list_audio_devices() -> Result<Vec<AudioDeviceInfo>, TrascribeError> {
    crate::audio::list_input_devices()
}

pub fn get_loopback_device(name_hint: String) -> Result<AudioDeviceInfo, TrascribeError> {
    crate::audio::get_loopback_device(&name_hint)
}

// --- Session control -----------------------------------------------------

pub fn start_session(config: SessionConfig) -> Result<String, TrascribeError> {
    crate::session::start_session(config)
}

pub fn stop_session(session_id: String) -> Result<(), TrascribeError> {
    crate::session::stop_session(&session_id)
}

pub fn toggle_mic(session_id: String, enabled: bool) -> Result<(), TrascribeError> {
    crate::session::toggle_mic(&session_id, enabled)
}

pub fn toggle_speaker(session_id: String, enabled: bool) -> Result<(), TrascribeError> {
    crate::session::toggle_speaker(&session_id, enabled)
}

pub fn set_session_mode(session_id: String, mode: SessionMode) -> Result<(), TrascribeError> {
    crate::session::set_session_mode(&session_id, mode)
}

pub fn get_session_status(session_id: String) -> Result<SessionStatus, TrascribeError> {
    crate::session::get_status(&session_id)
}

pub fn poll_session_events(session_id: String) -> Result<Vec<SessionEvent>, TrascribeError> {
    crate::session::poll_events(&session_id)
}

pub fn list_recoverable_sessions() -> Result<Vec<SessionRecoverySnapshot>, TrascribeError> {
    crate::session::list_recoverable_sessions()
}

pub fn recover_session(snapshot: SessionRecoverySnapshot) -> Result<String, TrascribeError> {
    crate::session::recover_session(snapshot)
}

// --- Model management -----------------------------------------------------

pub fn list_available_models(models_dir: String) -> Vec<ModelInfo> {
    crate::model::list_available_models(&PathBuf::from(models_dir))
}

pub fn is_model_downloaded(models_dir: String, model_id: String) -> bool {
    crate::model::is_model_downloaded(&PathBuf::from(models_dir), &model_id)
}

// --- Export -----------------------------------------------------

pub fn export_session(
    segments: Vec<Segment>,
    formats: Vec<ExportFormat>,
    output_dir: String,
    title: String,
) -> Result<Vec<ExportedFile>, TrascribeError> {
    crate::export::export_segments(&segments, &formats, &PathBuf::from(output_dir), &title)
}

// --- File transcription -----------------------------------------------------

pub fn decode_audio_file(path: String) -> Result<crate::decode::AudioBuffer, TrascribeError> {
    crate::decode::decode_audio_file(&PathBuf::from(path))
}

// --- Settings -----------------------------------------------------

pub fn load_settings() -> AppSettings {
    crate::settings::load_settings()
}

pub fn save_settings(settings: AppSettings) -> Result<(), TrascribeError> {
    crate::settings::save_settings(&settings)
}

// --- Singleton instance lock -----------------------------------------------------

pub fn is_another_instance_running() -> Result<bool, TrascribeError> {
    crate::singleton::is_another_instance_running()
}

pub fn acquire_instance_lock() -> Result<(), TrascribeError> {
    crate::singleton::acquire_lock()
}

pub fn release_instance_lock() -> Result<(), TrascribeError> {
    crate::singleton::release_lock()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_not_empty() {
        assert!(!engine_version().is_empty());
    }

    #[test]
    fn health_check_ok() {
        assert!(health_check().unwrap());
    }

    #[test]
    fn session_lifecycle_through_api() {
        let config = SessionConfig::for_mode(SessionMode::Offline, "tiny".into());
        let id = start_session(config).unwrap();
        assert!(get_session_status(id.clone()).is_ok());
        toggle_mic(id.clone(), false).unwrap();
        assert!(!get_session_status(id.clone()).unwrap().mic_enabled);
        stop_session(id).unwrap();
    }

    #[test]
    fn list_models_includes_tiny() {
        let dir = std::env::temp_dir().to_string_lossy().to_string();
        let models = list_available_models(dir);
        assert!(models.iter().any(|m| m.id == "tiny"));
    }

    #[test]
    fn settings_roundtrip_through_api() {
        let s = load_settings();
        assert!(!s.default_model.is_empty());
    }
}
