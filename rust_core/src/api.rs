//! Public API surface exposed to Flutter via flutter_rust_bridge V2.
//!
//! FRB-compatible: no lifetimes in public signatures, every fallible
//! function returns `Result<T, TrascribeError>`. Streams (`vu_meter_stream`,
//! `transcript_stream`, live audio thread wiring) land once FRB codegen is
//! set up against the actual Flutter app.

use std::path::PathBuf;

use crate::audio::{AudioDeviceInfo, SessionConfig, SessionMode};
use crate::error::TrascribeResult;
use crate::export::{ExportFormat, ExportedFile, Segment};
use crate::model::ModelInfo;
use crate::session::SessionStatus;
use crate::settings::AppSettings;

pub fn engine_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn health_check() -> TrascribeResult<bool> {
    Ok(true)
}

// --- Audio devices -----------------------------------------------------

pub fn list_audio_devices() -> TrascribeResult<Vec<AudioDeviceInfo>> {
    crate::audio::list_input_devices()
}

pub fn get_loopback_device(name_hint: String) -> TrascribeResult<AudioDeviceInfo> {
    crate::audio::get_loopback_device(&name_hint)
}

// --- Session control -----------------------------------------------------

pub fn start_session(config: SessionConfig) -> TrascribeResult<String> {
    crate::session::start_session(config)
}

pub fn stop_session(session_id: String) -> TrascribeResult<()> {
    crate::session::stop_session(&session_id)
}

pub fn toggle_mic(session_id: String, enabled: bool) -> TrascribeResult<()> {
    crate::session::toggle_mic(&session_id, enabled)
}

pub fn toggle_speaker(session_id: String, enabled: bool) -> TrascribeResult<()> {
    crate::session::toggle_speaker(&session_id, enabled)
}

pub fn set_session_mode(session_id: String, mode: SessionMode) -> TrascribeResult<()> {
    crate::session::set_session_mode(&session_id, mode)
}

pub fn get_session_status(session_id: String) -> TrascribeResult<SessionStatus> {
    crate::session::get_status(&session_id)
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
) -> TrascribeResult<Vec<ExportedFile>> {
    crate::export::export_segments(&segments, &formats, &PathBuf::from(output_dir), &title)
}

// --- File transcription -----------------------------------------------------

pub fn decode_audio_file(path: String) -> TrascribeResult<crate::decode::AudioBuffer> {
    crate::decode::decode_audio_file(&PathBuf::from(path))
}

// --- Settings -----------------------------------------------------

pub fn load_settings() -> AppSettings {
    crate::settings::load_settings()
}

pub fn save_settings(settings: AppSettings) -> TrascribeResult<()> {
    crate::settings::save_settings(&settings)
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
