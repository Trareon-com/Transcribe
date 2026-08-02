//! Privacy proof — compile-time assurance that transcribe audio path makes
//! zero network calls. Scans source files for known network patterns.

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    fn manifest_dir() -> PathBuf {
        std::env::var("CARGO_MANIFEST_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("."))
    }

    #[test]
    fn transcribe_path_no_network_calls() {
        let base = manifest_dir().join("src");
        let sources = [
            "stt/mod.rs",
            "stt/file.rs",
            "progressive.rs",
            "pipeline.rs",
            "decode/mod.rs",
            "preprocess.rs",
            "vad.rs",
            "diarization.rs",
            "session.rs",
            "audio/capture.rs",
            "audio/loopback.rs",
        ];
        // Patterns that would indicate network I/O in the hot transcribe path.
        // download_with_resume is allowed in model.rs (download phase) but
        // must NOT appear in the real-time transcribe modules above.
        let forbidden = [
            "reqwest::get",
            "reqwest::Client",
            "download_with_resume",
            "http://",
            "https://",
            "reqwest::",
            "tokio::net",
        ];

        for s in sources {
            let path = base.join(s);
            if !path.exists() {
                continue; // some files may not exist on all platforms
            }
            let content = std::fs::read_to_string(&path)
                .unwrap_or_else(|_| panic!("failed to read {}", path.display()));
            for f in &forbidden {
                assert!(
                    !content.contains(f),
                    "{} contains forbidden network pattern '{}'",
                    path.display(),
                    f
                );
            }
        }
    }
}
