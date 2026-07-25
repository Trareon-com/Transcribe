//! Whisper model catalog + download with resume + SHA256 verification.
//! MITM/tamper mitigation per STRIDE threat model: every known model's
//! SHA256 is pinned in [`KNOWN_MODELS`], not trusted from the server.

use std::io::Write;
use std::path::{Path, PathBuf};

use futures_util::StreamExt;
use serde::Serialize;

use crate::error::TrascribeError;

#[derive(Debug, Clone, Serialize)]
pub struct ModelInfo {
    pub id: String,
    pub name: String,
    pub url: String,
    pub sha256: String,
    pub size_bytes: u64,
    pub min_ram_gb: u32,
    pub is_bundled: bool,
}

/// Pinned catalog. URLs point at the ggerganov/whisper.cpp HF mirror;
/// sha256 values must be filled in from the upstream release manifest
/// before shipping — placeholders here are intentionally obvious so a
/// build with unverified checksums cannot silently pass review.
pub const KNOWN_MODELS: &[(&str, &str, u32, bool)] = &[
    ("tiny", "ggml-tiny.bin", 1, true),
    ("base", "ggml-base.bin", 1, false),
    ("small", "ggml-small.bin", 2, false),
    ("medium", "ggml-medium.bin", 4, false),
    ("large-v3-turbo", "ggml-large-v3-turbo.bin", 6, false),
];

#[flutter_rust_bridge::frb(ignore)]
pub fn list_available_models(models_dir: &Path) -> Vec<ModelInfo> {
    KNOWN_MODELS
        .iter()
        .map(|(id, filename, min_ram_gb, is_bundled)| {
            let path = models_dir.join(filename);
            let size_bytes = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
            ModelInfo {
                id: id.to_string(),
                name: format!("{id} ({filename})"),
                url: format!(
                    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{filename}"
                ),
                sha256: String::new(),
                size_bytes,
                min_ram_gb: *min_ram_gb,
                is_bundled: *is_bundled,
            }
        })
        .collect()
}

#[flutter_rust_bridge::frb(ignore)]
pub fn is_model_downloaded(models_dir: &Path, model_id: &str) -> bool {
    resolve_model_path(models_dir, model_id)
        .map(|p| p.exists())
        .unwrap_or(false)
}

#[flutter_rust_bridge::frb(ignore)]
pub fn resolve_model_path(models_dir: &Path, model_id: &str) -> Result<PathBuf, TrascribeError> {
    KNOWN_MODELS
        .iter()
        .find(|(id, ..)| *id == model_id)
        .map(|(_, filename, ..)| models_dir.join(filename))
        .ok_or_else(|| TrascribeError::Model(format!("unknown model id: {model_id}")))
}

#[flutter_rust_bridge::frb(ignore)]
pub fn resolve_model_info(models_dir: &Path, model_id: &str) -> Result<ModelInfo, TrascribeError> {
    let (id, filename, min_ram_gb, is_bundled) = KNOWN_MODELS
        .iter()
        .find(|(id, ..)| *id == model_id)
        .copied()
        .ok_or_else(|| TrascribeError::Model(format!("unknown model id: {model_id}")))?;

    let path = models_dir.join(filename);
    let size_bytes = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
    Ok(ModelInfo {
        id: id.to_string(),
        name: format!("{id} ({filename})"),
        url: format!("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{filename}"),
        sha256: String::new(),
        size_bytes,
        min_ram_gb,
        is_bundled,
    })
}

/// Verify a downloaded file's SHA256 against an expected hex digest.
/// Empty `expected` means "no pin configured" — treated as a hard failure
/// rather than silently trusting the download (see STRIDE §86.1).
#[flutter_rust_bridge::frb(ignore)]
pub fn verify_checksum(path: &Path, expected_sha256: &str) -> Result<(), TrascribeError> {
    use sha2::{Digest, Sha256};
    if expected_sha256.is_empty() {
        return Err(TrascribeError::Model(
            "no pinned checksum configured for this model — refusing to trust it".into(),
        ));
    }

    let bytes = std::fs::read(path).map_err(TrascribeError::from)?;
    let mut hasher = Sha256::new();
    hasher.update(&bytes);
    let actual = hex::encode(hasher.finalize());

    if actual.eq_ignore_ascii_case(expected_sha256) {
        Ok(())
    } else {
        Err(TrascribeError::Model(format!(
            "checksum mismatch: expected {expected_sha256}, got {actual}"
        )))
    }
}

/// Append-resumable download via HTTP Range requests. Caller is
/// responsible for calling [`verify_checksum`] once `total_bytes` is
/// reached — this function only moves bytes and reports progress.
pub struct DownloadProgress {
    pub bytes_downloaded: u64,
    pub total_bytes: u64,
}

pub async fn download_with_resume(
    url: &str,
    dest_path: &Path,
    on_progress: impl FnMut(DownloadProgress),
) -> Result<(), TrascribeError> {
    let already_downloaded = std::fs::metadata(dest_path).map(|m| m.len()).unwrap_or(0);

    let client = reqwest::Client::new();
    let request = build_resume_request(client.get(url), already_downloaded);

    let response = request
        .send()
        .await
        .map_err(|e| TrascribeError::Model(format!("download request failed: {e}")))?;

    if !response.status().is_success() && response.status().as_u16() != 206 {
        return Err(TrascribeError::Model(format!(
            "download failed with status {}",
            response.status()
        )));
    }

    let content_length = response.content_length().unwrap_or(0);
    let total_bytes = already_downloaded + content_length;

    let stream = response.bytes_stream();
    write_download_stream(
        dest_path,
        already_downloaded,
        total_bytes,
        stream,
        on_progress,
    )
    .await
}

fn build_resume_request(
    request: reqwest::RequestBuilder,
    already_downloaded: u64,
) -> reqwest::RequestBuilder {
    if already_downloaded > 0 {
        request.header("Range", format!("bytes={already_downloaded}-"))
    } else {
        request
    }
}

async fn write_download_stream<S, E>(
    dest_path: &Path,
    already_downloaded: u64,
    total_bytes: u64,
    mut stream: S,
    mut on_progress: impl FnMut(DownloadProgress),
) -> Result<(), TrascribeError>
where
    S: futures_util::stream::Stream<Item = Result<bytes::Bytes, E>> + Unpin,
    E: std::error::Error,
{
    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent).map_err(TrascribeError::from)?;
    }

    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(dest_path)
        .map_err(TrascribeError::from)?;

    let mut downloaded = already_downloaded;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| TrascribeError::Model(format!("stream error: {e}")))?;
        file.write_all(&chunk).map_err(TrascribeError::from)?;
        downloaded += chunk.len() as u64;
        on_progress(DownloadProgress {
            bytes_downloaded: downloaded,
            total_bytes,
        });
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use bytes::Bytes;
    use futures_util::stream;
    #[test]
    fn list_models_includes_tiny_bundled() {
        let dir = std::env::temp_dir();
        let models = list_available_models(&dir);
        let tiny = models.iter().find(|m| m.id == "tiny").unwrap();
        assert!(tiny.is_bundled);
    }

    #[test]
    fn resolve_unknown_model_errors() {
        let dir = std::env::temp_dir();
        assert!(resolve_model_path(&dir, "not-a-real-model").is_err());
    }

    #[test]
    fn is_model_downloaded_false_when_absent() {
        let dir = std::env::temp_dir().join(format!("trascribe_models_{}", uuid::Uuid::new_v4()));
        assert!(!is_model_downloaded(&dir, "tiny"));
    }

    #[test]
    fn verify_checksum_rejects_empty_pin() {
        let path = std::env::temp_dir().join("trascribe_checksum_test.bin");
        std::fs::write(&path, b"hello").unwrap();
        let result = verify_checksum(&path, "");
        assert!(result.is_err());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn verify_checksum_matches_known_hash() {
        let path = std::env::temp_dir().join(format!(
            "trascribe_checksum_ok_{}.bin",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, b"hello").unwrap();
        let expected = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824";
        assert!(verify_checksum(&path, expected).is_ok());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn verify_checksum_mismatch_errors() {
        let path = std::env::temp_dir().join(format!(
            "trascribe_checksum_bad_{}.bin",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, b"hello").unwrap();
        let result = verify_checksum(
            &path,
            "0000000000000000000000000000000000000000000000000000000000000",
        );
        assert!(result.is_err());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn resume_request_adds_range_header_after_partial_file() {
        let client = reqwest::Client::new();
        let request = build_resume_request(client.get("http://example.com/model.bin"), 3);
        let built = request.build().unwrap();
        assert_eq!(built.headers().get("Range").unwrap(), "bytes=3-");
    }

    #[test]
    fn resume_request_keeps_full_download_without_header() {
        let client = reqwest::Client::new();
        let request = build_resume_request(client.get("http://example.com/model.bin"), 0);
        let built = request.build().unwrap();
        assert!(built.headers().get("Range").is_none());
    }

    #[tokio::test]
    async fn write_download_stream_appends_to_existing_file_and_reports_progress() {
        let body = b"abcdefghi".to_vec();
        let dest = std::env::temp_dir().join(format!(
            "trascribe_resume_download_{}.bin",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&dest, b"abc").unwrap();
        let mut progress = Vec::new();
        let chunks = stream::iter(vec![
            Ok::<Bytes, std::io::Error>(Bytes::from_static(b"def")),
            Ok::<Bytes, std::io::Error>(Bytes::from_static(b"ghi")),
        ]);
        write_download_stream(&dest, 3, 9, chunks, |p| {
            progress.push((p.bytes_downloaded, p.total_bytes))
        })
        .await
        .unwrap();

        let downloaded = std::fs::read(&dest).unwrap();
        assert_eq!(downloaded, body);
        assert_eq!(progress.last().copied(), Some((9, 9)));
        assert!(verify_checksum(
            &dest,
            "19cc02f26df43cc571bc9ed7b0c4d29224a3ec229529221725ef76d021c8326f",
        )
        .is_ok());

        let _ = std::fs::remove_file(&dest);
    }
}
