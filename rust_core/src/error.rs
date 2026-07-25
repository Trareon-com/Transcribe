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

    /// String, not `std::io::Error` — the latter has no FRB `SseEncode`
    /// impl, which broke bridge codegen. Construct via
    /// `TrascribeError::from(io_err)` or `.map_err(TrascribeError::from)`.
    #[error("io error: {0}")]
    Io(String),

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("session not found: {0}")]
    SessionNotFound(String),
}

impl From<std::io::Error> for TrascribeError {
    fn from(e: std::io::Error) -> Self {
        TrascribeError::Io(e.to_string())
    }
}

/// Internal-only convenience alias. FRB-exposed signatures (anything in a
/// module listed in the codegen `--rust-input`) must spell out
/// `Result<T, TrascribeError>` explicitly — the codegen doesn't resolve
/// this alias when scanning multiple modules.
pub type TrascribeResult<T> = Result<T, TrascribeError>;
