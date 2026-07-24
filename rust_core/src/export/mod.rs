//! Export module — Markdown / TXT / JSON / SRT / VTT / WAV.

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::error::{TrascribeError, TrascribeResult};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Segment {
    pub source: String,
    pub speaker: String,
    pub text: String,
    pub timestamp: f64,
    pub duration: f64,
    pub language: String,
    pub confidence: f32,
    pub is_partial: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ExportFormat {
    Markdown,
    Txt,
    Json,
    Srt,
    Vtt,
}

#[derive(Debug, Clone, Serialize)]
pub struct ExportedFile {
    pub filename: String,
    pub path: String,
    pub size_bytes: u64,
}

/// Sanitize a user/window-title-derived name into a safe path component:
/// no separators, no traversal, no control characters.
pub fn sanitize_filename(raw: &str) -> String {
    let cleaned: String = raw
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
            c if c.is_control() => '_',
            c => c,
        })
        .collect();
    let trimmed = cleaned.trim().trim_matches('.');
    if trimmed.is_empty() {
        "untitled".to_string()
    } else {
        trimmed.chars().take(120).collect()
    }
}

pub fn export_segments(
    segments: &[Segment],
    formats: &[ExportFormat],
    output_dir: &Path,
    title: &str,
) -> TrascribeResult<Vec<ExportedFile>> {
    let safe_title = sanitize_filename(title);
    let session_dir = output_dir.join(&safe_title);
    fs::create_dir_all(&session_dir).map_err(TrascribeError::Io)?;

    let mut results = Vec::new();
    for format in formats {
        let (filename, content) = match format {
            ExportFormat::Markdown => (format!("{safe_title}.md"), to_markdown(segments, title)),
            ExportFormat::Txt => (format!("{safe_title}.txt"), to_txt(segments)),
            ExportFormat::Json => (
                format!("{safe_title}.json"),
                serde_json::to_string_pretty(segments)
                    .map_err(|e| TrascribeError::Export(e.to_string()))?,
            ),
            ExportFormat::Srt => (format!("{safe_title}.srt"), to_srt(segments)),
            ExportFormat::Vtt => (format!("{safe_title}.vtt"), to_vtt(segments)),
        };

        let path: PathBuf = session_dir.join(&filename);
        let mut file = fs::File::create(&path).map_err(TrascribeError::Io)?;
        file.write_all(content.as_bytes())
            .map_err(TrascribeError::Io)?;

        let size_bytes = fs::metadata(&path).map_err(TrascribeError::Io)?.len();
        results.push(ExportedFile {
            filename,
            path: path.to_string_lossy().to_string(),
            size_bytes,
        });
    }

    Ok(results)
}

/// Write mono f32 PCM (16kHz) as a 16-bit WAV file.
pub fn write_wav(samples: &[f32], sample_rate: u32, path: &Path) -> TrascribeResult<()> {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer =
        hound::WavWriter::create(path, spec).map_err(|e| TrascribeError::Export(e.to_string()))?;
    for &s in samples {
        let clamped = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
        writer
            .write_sample(clamped)
            .map_err(|e| TrascribeError::Export(e.to_string()))?;
    }
    writer
        .finalize()
        .map_err(|e| TrascribeError::Export(e.to_string()))
}

fn to_markdown(segments: &[Segment], title: &str) -> String {
    let mut out = format!("# {title}\n\n");
    for seg in segments {
        out.push_str(&format!(
            "**[{}]** `{}` — {}\n\n",
            fmt_timestamp(seg.timestamp),
            seg.speaker,
            seg.text
        ));
    }
    out
}

fn to_txt(segments: &[Segment]) -> String {
    segments
        .iter()
        .map(|s| s.text.clone())
        .collect::<Vec<_>>()
        .join("\n")
}

fn to_srt(segments: &[Segment]) -> String {
    let mut out = String::new();
    for (i, seg) in segments.iter().enumerate() {
        out.push_str(&format!(
            "{}\n{} --> {}\n{}: {}\n\n",
            i + 1,
            fmt_srt_time(seg.timestamp),
            fmt_srt_time(seg.timestamp + seg.duration),
            seg.speaker,
            seg.text
        ));
    }
    out
}

fn to_vtt(segments: &[Segment]) -> String {
    let mut out = String::from("WEBVTT\n\n");
    for seg in segments {
        out.push_str(&format!(
            "{} --> {}\n{}: {}\n\n",
            fmt_vtt_time(seg.timestamp),
            fmt_vtt_time(seg.timestamp + seg.duration),
            seg.speaker,
            seg.text
        ));
    }
    out
}

fn fmt_timestamp(secs: f64) -> String {
    let m = (secs / 60.0) as u64;
    let s = (secs % 60.0) as u64;
    format!("{m:02}:{s:02}")
}

fn fmt_srt_time(secs: f64) -> String {
    let ms = ((secs.fract()) * 1000.0).round() as u64;
    let total = secs as u64;
    format!(
        "{:02}:{:02}:{:02},{:03}",
        total / 3600,
        (total % 3600) / 60,
        total % 60,
        ms
    )
}

fn fmt_vtt_time(secs: f64) -> String {
    let ms = ((secs.fract()) * 1000.0).round() as u64;
    let total = secs as u64;
    format!(
        "{:02}:{:02}:{:02}.{:03}",
        total / 3600,
        (total % 3600) / 60,
        total % 60,
        ms
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_segments() -> Vec<Segment> {
        vec![Segment {
            source: "mic".into(),
            speaker: "MIC".into(),
            text: "halo dunia".into(),
            timestamp: 1.5,
            duration: 2.0,
            language: "id".into(),
            confidence: 0.9,
            is_partial: false,
        }]
    }

    #[test]
    fn sanitize_removes_path_separators() {
        let sanitized = sanitize_filename("../../etc/passwd");
        assert!(!sanitized.contains('/'));
        assert!(!sanitized.contains('\\'));
        assert_eq!(sanitize_filename("rapat: q3\\review"), "rapat_ q3_review");
    }

    #[test]
    fn sanitize_empty_falls_back() {
        assert_eq!(sanitize_filename("...."), "untitled");
        assert_eq!(sanitize_filename(""), "untitled");
    }

    #[test]
    fn export_all_formats_writes_files() {
        let dir =
            std::env::temp_dir().join(format!("trascribe_export_test_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let formats = [
            ExportFormat::Markdown,
            ExportFormat::Txt,
            ExportFormat::Json,
            ExportFormat::Srt,
            ExportFormat::Vtt,
        ];
        let files = export_segments(&segments, &formats, &dir, "Rapat Q3").unwrap();
        assert_eq!(files.len(), 5);
        for f in &files {
            assert!(Path::new(&f.path).exists());
            assert!(f.size_bytes > 0);
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn export_path_traversal_title_is_contained() {
        let dir =
            std::env::temp_dir().join(format!("trascribe_export_test_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let files = export_segments(&segments, &[ExportFormat::Txt], &dir, "../../evil").unwrap();
        for f in &files {
            assert!(Path::new(&f.path).starts_with(&dir));
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn wav_roundtrip_readable() {
        let path =
            std::env::temp_dir().join(format!("trascribe_wav_test_{}.wav", uuid::Uuid::new_v4()));
        let samples = vec![0.0f32, 0.5, -0.5, 1.0, -1.0];
        write_wav(&samples, 16_000, &path).unwrap();
        let reader = hound::WavReader::open(&path).unwrap();
        assert_eq!(reader.spec().sample_rate, 16_000);
        assert_eq!(reader.len(), samples.len() as u32);
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn srt_time_format() {
        assert_eq!(fmt_srt_time(3661.5), "01:01:01,500");
    }

    #[test]
    fn vtt_time_format() {
        assert_eq!(fmt_vtt_time(65.25), "00:01:05.250");
    }
}
