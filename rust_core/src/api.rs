//! Public API surface exposed to Flutter via flutter_rust_bridge V2.
//!
//! FRB-compatible: no lifetimes in public signatures, every fallible
//! function returns `Result<T, TranscribeError>`. Streams (`vu_meter_stream`,
//! `transcript_stream`, live audio thread wiring) land once FRB codegen is
//! set up against the actual Flutter app.

use std::path::PathBuf;

use crate::audio::{AudioDeviceInfo, SessionConfig, SessionMode};
use crate::error::TranscribeError;
use crate::export::{ExportFormat, ExportedFile, Segment};
use crate::model::ModelInfo;
use crate::session::{SessionEvent, SessionRecoverySnapshot, SessionStatus};
use crate::settings::AppSettings;

/// Installs a `tracing` subscriber writing to stderr. Without this,
/// every `tracing::error!`/`warn!` call in the engine (session/pipeline
/// failures, capture errors, etc.) is silently dropped — there is no
/// default subscriber. Call once, right after `RustLib.init()`, before
/// anything else. Safe to call more than once (subsequent calls are a
/// harmless no-op via `try_init`).
pub fn init_logging() {
    let _ = tracing_subscriber::fmt::try_init();
}

pub fn engine_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn health_check() -> Result<bool, TranscribeError> {
    Ok(true)
}

// --- Audio devices -----------------------------------------------------

pub fn list_audio_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::list_input_devices()
}

pub fn get_loopback_device(name_hint: String) -> Result<AudioDeviceInfo, TranscribeError> {
    crate::audio::get_loopback_device(&name_hint)
}

// --- Session control -----------------------------------------------------

pub fn start_session(config: SessionConfig) -> Result<String, TranscribeError> {
    crate::session::start_session(config)
}

pub fn stop_session(session_id: String) -> Result<(), TranscribeError> {
    crate::session::stop_session(&session_id)
}

pub fn toggle_mic(session_id: String, enabled: bool) -> Result<(), TranscribeError> {
    crate::session::toggle_mic(&session_id, enabled)
}

pub fn toggle_speaker(session_id: String, enabled: bool) -> Result<(), TranscribeError> {
    crate::session::toggle_speaker(&session_id, enabled)
}

pub fn set_session_mode(session_id: String, mode: SessionMode) -> Result<(), TranscribeError> {
    crate::session::set_session_mode(&session_id, mode)
}

pub fn get_session_status(session_id: String) -> Result<SessionStatus, TranscribeError> {
    crate::session::get_status(&session_id)
}

pub fn poll_session_events(session_id: String) -> Result<Vec<SessionEvent>, TranscribeError> {
    crate::session::poll_events(&session_id)
}

pub fn list_recoverable_sessions() -> Result<Vec<SessionRecoverySnapshot>, TranscribeError> {
    crate::session::list_recoverable_sessions()
}

pub fn recover_session(snapshot: SessionRecoverySnapshot) -> Result<String, TranscribeError> {
    crate::session::recover_session(snapshot)
}

// --- Model management -----------------------------------------------------

pub fn list_available_models(models_dir: String) -> Vec<ModelInfo> {
    crate::model::list_available_models(&PathBuf::from(models_dir))
}

pub fn is_model_downloaded(models_dir: String, model_id: String) -> bool {
    crate::model::is_model_downloaded(&PathBuf::from(models_dir), &model_id)
}

pub async fn download_model(models_dir: String, model_id: String) -> Result<(), TranscribeError> {
    let models_path = PathBuf::from(models_dir);
    let info = crate::model::resolve_model_info(&models_path, &model_id)?;
    let dest_path = crate::model::resolve_model_path(&models_path, &model_id)?;

    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }

    crate::model::download_with_resume(&info.url, &dest_path, |progress| {
        crate::model::set_download_progress(progress.bytes_downloaded, progress.total_bytes);
    })
    .await?;

    if !info.sha256.is_empty() {
        crate::model::verify_checksum(&dest_path, &info.sha256)?;
    }

    Ok(())
}

/// Poll the current download progress. Returns `None` if no download is
/// in progress or progress tracking has been reset.
pub fn get_download_progress() -> Option<(u64, u64)> {
    crate::model::read_download_progress().map(|p| (p.bytes_downloaded, p.total_bytes))
}

// --- Export -----------------------------------------------------

pub fn export_session(
    segments: Vec<Segment>,
    formats: Vec<ExportFormat>,
    output_dir: String,
    title: String,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    crate::export::export_segments(&segments, &formats, &PathBuf::from(output_dir), &title)
}

// --- File transcription -----------------------------------------------------

pub fn decode_audio_file(path: String) -> Result<crate::decode::AudioBuffer, TranscribeError> {
    crate::decode::decode_audio_file(&PathBuf::from(path))
}

// --- File transcription (batch) -----------------------------------------------------

pub fn transcribe_files_batch(
    model_path: String,
    files: Vec<String>,
    language: Option<String>,
) -> Result<Vec<crate::stt::file::TranscribeFileResult>, TranscribeError> {
    let engine = crate::stt::WhisperEngine::load(&PathBuf::from(&model_path))?;
    let file_paths: Vec<PathBuf> = files.iter().map(PathBuf::from).collect();
    let mut results = Vec::new();

    crate::stt::file::transcribe_files_batch(
        &engine,
        &file_paths,
        language.as_deref(),
        |progress| {
            if let Some(result) = progress.result {
                results.push(result);
            }
        },
    );

    Ok(results)
}

// --- Settings -----------------------------------------------------

pub fn load_settings() -> AppSettings {
    crate::settings::load_settings()
}

pub fn save_settings(settings: AppSettings) -> Result<(), TranscribeError> {
    crate::settings::save_settings(&settings)
}

// --- Singleton instance lock -----------------------------------------------------

pub fn is_another_instance_running() -> Result<bool, TranscribeError> {
    crate::singleton::is_another_instance_running()
}

pub fn acquire_instance_lock() -> Result<(), TranscribeError> {
    crate::singleton::acquire_lock()
}

pub fn release_instance_lock() -> Result<(), TranscribeError> {
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

    #[tokio::test]
    async fn download_unknown_model_errors() {
        let dir = std::env::temp_dir().to_string_lossy().to_string();
        let res = download_model(dir, "invalid-model-id".into()).await;
        assert!(res.is_err());
    }

    #[test]
    fn settings_roundtrip_through_api() {
        let s = load_settings();
        assert!(!s.default_model.is_empty());
    }
}
