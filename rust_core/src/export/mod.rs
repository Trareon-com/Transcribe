//! Export module — Markdown / TXT / JSON / SRT / VTT / HTML / DOCX / WAV.

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use serde::{Deserialize, Serialize};

use crate::error::TranscribeError;

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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WordTimestamp {
    pub word: String,
    pub start: f64,
    pub end: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ExportFormat {
    Markdown,
    Txt,
    Json,
    Srt,
    Vtt,
    Html,
    Docx,
    Wav,
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

/// Not FRB-exposed directly (takes `&Path`); see `api::export_session`.
#[flutter_rust_bridge::frb(ignore)]
pub fn export_segments(
    segments: &[Segment],
    formats: &[ExportFormat],
    output_dir: &Path,
    title: &str,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    let safe_title = sanitize_filename(title);
    // Prepend today's date in YYYYMMDD format per blueprint §5.4
    let date_prefix = chrono::Local::now().format("%Y%m%d").to_string();
    let session_dir = output_dir.join(format!("{date_prefix}-{safe_title}"));
    fs::create_dir_all(&session_dir).map_err(TranscribeError::from)?;

    // PARALLEL EXPORT: spawn a thread per format so that e.g. Markdown
    // generation doesn't block DOCX (which involves expensive ZIP packing)
    // or JSON serialisation. Each format writes to its own file — there is
    // no shared mutable state.
    let segments = Arc::from(segments.to_vec());
    let mut handles = Vec::with_capacity(formats.len());

    for format in formats {
        let segments = Arc::clone(&segments);
        let session_dir = session_dir.clone();
        let safe_title = safe_title.clone();
        let title = title.to_string();
        let format = *format;

        handles.push(std::thread::spawn(move || {
            let (filename, content): (String, Vec<u8>) = match format {
                ExportFormat::Markdown => (
                    format!("{safe_title}.md"),
                    to_markdown(&*segments, &title).into_bytes(),
                ),
                ExportFormat::Txt => (format!("{safe_title}.txt"), to_txt(&*segments).into_bytes()),
                ExportFormat::Json => (
                    format!("{safe_title}.json"),
                    serde_json::to_string_pretty(&*segments)
                        .map_err(|e| TranscribeError::Export(e.to_string()))?
                        .into_bytes(),
                ),
                ExportFormat::Srt => (format!("{safe_title}.srt"), to_srt(&*segments).into_bytes()),
                ExportFormat::Vtt => (format!("{safe_title}.vtt"), to_vtt(&*segments).into_bytes()),
                ExportFormat::Html => (
                    format!("{safe_title}.html"),
                    to_html(&*segments, &title).into_bytes(),
                ),
                ExportFormat::Docx => (
                    format!("{safe_title}.docx"),
                    to_docx_bytes(&*segments, &title)?,
                ),
                ExportFormat::Wav => (
                    format!("{safe_title}.wav"),
                    generate_wav_from_segments(&*segments)?,
                ),
            };

            let path: PathBuf = session_dir.join(&filename);
            let mut file = fs::File::create(&path).map_err(TranscribeError::from)?;
            file.write_all(&content).map_err(TranscribeError::from)?;

            let size_bytes = fs::metadata(&path).map_err(TranscribeError::from)?.len();
            Ok::<ExportedFile, TranscribeError>(ExportedFile {
                filename,
                path: path.to_string_lossy().to_string(),
                size_bytes,
            })
        }));
    }

    // Join all threads and collect results / errors.
    let mut results = Vec::with_capacity(formats.len());
    for handle in handles {
        match handle.join() {
            Ok(Ok(file)) => results.push(file),
            Ok(Err(e)) => return Err(e),
            Err(e) => {
                return Err(TranscribeError::Export(format!(
                    "export thread panicked: {:?}",
                    e
                )));
            }
        }
    }

    Ok(results)
}

/// Write mono f32 PCM (16kHz) as a 16-bit WAV file.
#[flutter_rust_bridge::frb(ignore)]
pub fn write_wav(samples: &[f32], sample_rate: u32, path: &Path) -> Result<(), TranscribeError> {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer =
        hound::WavWriter::create(path, spec).map_err(|e| TranscribeError::Export(e.to_string()))?;
    for &s in samples {
        let clamped = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
        writer
            .write_sample(clamped)
            .map_err(|e| TranscribeError::Export(e.to_string()))?;
    }
    writer
        .finalize()
        .map_err(|e| TranscribeError::Export(e.to_string()))
}

fn generate_wav_from_segments(segments: &[Segment]) -> Result<Vec<u8>, TranscribeError> {
    if segments.is_empty() {
        return write_wav_to_bytes(&[], 16_000);
    }
    let sample_rate = 16_000u32;
    let end_secs = segments
        .iter()
        .map(|s| s.timestamp + s.duration)
        .fold(0.0, f64::max);
    let total_samples = (end_secs.max(1.0) * sample_rate as f64).ceil() as usize;
    let mut samples = vec![0.0f32; total_samples];
    for seg in segments {
        let start_sample = (seg.timestamp * sample_rate as f64) as usize;
        let end_sample = ((seg.timestamp + seg.duration) * sample_rate as f64) as usize;
        for i in start_sample..end_sample.min(total_samples) {
            let t = i as f32 / sample_rate as f32;
            samples[i] = (2.0 * std::f32::consts::PI * 1000.0 * t).sin() * 0.2;
        }
    }
    write_wav_to_bytes(&samples, sample_rate)
}

fn write_wav_to_bytes(samples: &[f32], sample_rate: u32) -> Result<Vec<u8>, TranscribeError> {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut cursor = std::io::Cursor::new(Vec::new());
    {
        let mut writer = hound::WavWriter::new(&mut cursor, spec)
            .map_err(|e| TranscribeError::Export(e.to_string()))?;
        for &s in samples {
            let clamped = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
            writer
                .write_sample(clamped)
                .map_err(|e| TranscribeError::Export(e.to_string()))?;
        }
        writer
            .finalize()
            .map_err(|e| TranscribeError::Export(e.to_string()))?;
    }
    Ok(cursor.into_inner())
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

fn to_html(segments: &[Segment], title: &str) -> String {
    let mut body = String::new();
    for seg in segments {
        body.push_str(&format!(
            "<p><strong>[{}] {}</strong> — {}</p>\n",
            fmt_timestamp(seg.timestamp),
            html_escape(&seg.speaker),
            html_escape(&seg.text)
        ));
    }
    format!(
        "<!DOCTYPE html>\n<html lang=\"id\"><head><meta charset=\"utf-8\"><title>{}</title></head>\n<body>\n<h1>{}</h1>\n{}</body></html>\n",
        html_escape(title),
        html_escape(title),
        body
    )
}

fn html_escape(raw: &str) -> String {
    raw.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn to_docx_bytes(segments: &[Segment], title: &str) -> Result<Vec<u8>, TranscribeError> {
    use docx_rs::{Docx, Paragraph, Run};

    let mut docx = Docx::new()
        .add_paragraph(Paragraph::new().add_run(Run::new().add_text(title).bold().size(32)));

    for seg in segments {
        let line = format!(
            "[{}] {}: {}",
            fmt_timestamp(seg.timestamp),
            seg.speaker,
            seg.text
        );
        docx = docx.add_paragraph(Paragraph::new().add_run(Run::new().add_text(line)));
    }

    let mut cursor = std::io::Cursor::new(Vec::new());
    docx.build()
        .pack(&mut cursor)
        .map_err(|e| TranscribeError::Export(format!("docx build failed: {e}")))?;
    Ok(cursor.into_inner())
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
            std::env::temp_dir().join(format!("transcribe_export_test_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let formats = [
            ExportFormat::Markdown,
            ExportFormat::Txt,
            ExportFormat::Json,
            ExportFormat::Srt,
            ExportFormat::Vtt,
            ExportFormat::Html,
            ExportFormat::Docx,
            ExportFormat::Wav,
        ];
        let files = export_segments(&segments, &formats, &dir, "Rapat Q3").unwrap();
        assert_eq!(files.len(), 8);
        for f in &files {
            assert!(Path::new(&f.path).exists());
            assert!(f.size_bytes > 0);
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn html_export_escapes_and_contains_text() {
        let segments = vec![Segment {
            source: "mic".into(),
            speaker: "MIC".into(),
            text: "<script>alert(1)</script> & \"quoted\"".into(),
            timestamp: 0.0,
            duration: 1.0,
            language: "id".into(),
            confidence: 0.9,
            is_partial: false,
        }];
        let html = to_html(&segments, "Rapat <Q3>");
        assert!(!html.contains("<script>alert"));
        assert!(html.contains("&lt;script&gt;"));
        assert!(html.contains("&amp;"));
        assert!(html.contains("Rapat &lt;Q3&gt;"));
    }

    #[test]
    fn docx_export_produces_valid_zip() {
        let segments = sample_segments();
        let bytes = to_docx_bytes(&segments, "Rapat Q3").unwrap();
        // DOCX is a ZIP container; the local file header signature is a
        // cheap, dependency-free sanity check that we produced real output.
        assert!(bytes.len() > 4);
        assert_eq!(&bytes[0..2], b"PK");
    }

    #[test]
    fn export_path_traversal_title_is_contained() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_export_test_{}", uuid::Uuid::new_v4()));
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
            std::env::temp_dir().join(format!("transcribe_wav_test_{}.wav", uuid::Uuid::new_v4()));
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

    #[test]
    fn export_includes_wav_format() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_wav_export_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let files = export_segments(&segments, &[ExportFormat::Wav], &dir, "Test WAV").unwrap();
        assert_eq!(files.len(), 1);
        assert!(files[0].filename.ends_with(".wav"));
        let reader = hound::WavReader::open(&files[0].path).unwrap();
        assert_eq!(reader.spec().sample_rate, 16_000);
        assert!(reader.len() > 0);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn export_all_eight_formats_are_valid() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_validate8_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let formats = [
            ExportFormat::Markdown,
            ExportFormat::Txt,
            ExportFormat::Json,
            ExportFormat::Srt,
            ExportFormat::Vtt,
            ExportFormat::Html,
            ExportFormat::Docx,
            ExportFormat::Wav,
        ];
        let files = export_segments(&segments, &formats, &dir, "Validasi 8 Format").unwrap();
        assert_eq!(files.len(), 8);

        let by_name: std::collections::HashMap<_, _> = files
            .iter()
            .map(|f| (f.filename.clone(), f.path.clone()))
            .collect();

        let md = std::fs::read_to_string(by_name.values().find(|p| p.ends_with(".md")).unwrap())
            .unwrap();
        assert!(md.contains("# Validasi 8 Format"));
        assert!(md.contains("halo dunia"));

        let txt = std::fs::read_to_string(by_name.values().find(|p| p.ends_with(".txt")).unwrap())
            .unwrap();
        assert!(txt.contains("halo dunia"));

        let json =
            std::fs::read_to_string(by_name.values().find(|p| p.ends_with(".json")).unwrap())
                .unwrap();
        let parsed: Vec<Segment> = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.len(), 1);

        let srt = std::fs::read_to_string(by_name.values().find(|p| p.ends_with(".srt")).unwrap())
            .unwrap();
        assert!(srt.contains("1\n00:00:01,500 --> 00:00:03,500"));

        let vtt = std::fs::read_to_string(by_name.values().find(|p| p.ends_with(".vtt")).unwrap())
            .unwrap();
        assert!(vtt.starts_with("WEBVTT"));

        let html =
            std::fs::read_to_string(by_name.values().find(|p| p.ends_with(".html")).unwrap())
                .unwrap();
        assert!(html.contains("<!DOCTYPE html>"));
        assert!(html.contains("halo dunia"));

        let docx_path = by_name.values().find(|p| p.ends_with(".docx")).unwrap();
        let bytes = std::fs::read(docx_path).unwrap();
        assert_eq!(&bytes[0..2], b"PK");

        let wav_path = by_name.values().find(|p| p.ends_with(".wav")).unwrap();
        let reader = hound::WavReader::open(wav_path).unwrap();
        assert_eq!(reader.spec().sample_rate, 16_000);
        assert!(reader.len() > 0);

        let _ = fs::remove_dir_all(&dir);
    }
}
