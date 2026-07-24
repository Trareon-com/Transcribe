use thiserror::Error;

/// Single error type for the entire public API surface.
/// No `unwrap`/`expect`/`panic!` in library code — every fallible
/// operation must resolve to one of these variants.
#[derive(Debug, Error)]
pub enum TrascribeError {
    #[error("audio device error: {0}")]
    AudioDevice(String),

    #[error("audio decode error: {0}")]
    AudioDecode(String),

    #[error("model error: {0}")]
    Model(String),

    #[error("transcription error: {0}")]
    Transcription(String),

    #[error("export error: {0}")]
    Export(String),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("session not found: {0}")]
    SessionNotFound(String),
}

pub type TrascribeResult<T> = Result<T, TrascribeError>;
