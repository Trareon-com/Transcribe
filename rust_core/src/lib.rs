pub mod api;
pub mod error;

pub mod audio;
pub mod decode;
pub mod dedupe;
pub mod export;
pub mod stt;
pub mod vad;

#[cfg(test)]
mod tests {
    use super::api;

    #[test]
    fn health_check_ok() {
        assert!(api::health_check().unwrap());
    }
}
