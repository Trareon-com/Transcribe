#!/usr/bin/env python3
"""
pyannote.audio v3.3 integration stub for Trareon Transcribe.

Usage:
    python3 scripts/pyannote_audio.py /path/to/audio.wav [--output path/to/output.rttm]

Requirements:
    pip install pyannote.audio pyannote.database pyannote.pipeline

Model setup:
    # Accept pyannote.audio terms at https://huggingface.co/pyannote/speaker-diarization-3.1
    # and obtain a access token from https://huggingface.co/settings/tokens
    huggingface-cli login

    # For pipeline 3.1 (faster, lighter):
    from pyannote.audio import Pipeline
    pipeline = Pipeline.from_pretrained("pyannote/speaker-diarization-3.1",
                                        use_auth_token="<YOUR_TOKEN>")

    # For pipeline 3.0 (more accurate):
    pipeline = Pipeline.from_pretrained("pyannote/speaker-diarization-3.0",
                                        use_auth_token="<YOUR_TOKEN>")
"""

import argparse
import json
import sys
from pathlib import Path

try:
    from pyannote.audio import Pipeline
    PYANNOTE_AVAILABLE = True
except ImportError:
    PYANNOTE_AVAILABLE = False
    print("WARNING: pyannote.audio not installed. Run: pip install pyannote.audio", file=sys.stderr)


DEFAULT_PIPELINE = "pyannote/speaker-diarization-3.1"
CACHE_DIR = Path.home() / ".cache" / "huggingface"


def load_pipeline(use_auth_token: str | None = None) -> "Pipeline":
    """Load and cache the pyannote diarization pipeline."""
    if not PYANNOTE_AVAILABLE:
        raise RuntimeError("pyannote.audio is not installed")
    return Pipeline.from_pretrained(
        DEFAULT_PIPELINE,
        use_auth_token=use_auth_token,
        cache_dir=str(CACHE_DIR),
    )


def diarize_audio(
    audio_path: str,
    pipeline: "Pipeline | None" = None,
    min_speakers: int | None = None,
    max_speakers: int | None = None,
) -> list[dict]:
    """
    Run pyannote.audio speaker diarization on an audio file.

    Args:
        audio_path: Path to 16kHz mono WAV file.
        pipeline: Pre-loaded pyannote Pipeline instance (optional).
        min_speakers: Minimum number of speakers to expect.
        max_speakers: Maximum number of speakers to expect.

    Returns:
        List of segment dicts: [{"start": float, "end": float,
                                  "speaker": str, "confidence": float}, ...]
    """
    if pipeline is None:
        pipeline = load_pipeline()

    # Run diarization
    diarization = pipeline(
        audio_path,
        min_speakers=min_speakers,
        max_speakers=max_speakers,
        return_duration=False,
    )

    segments = []
    for segment, track, label in diarization.itertracks(yield_label=True):
        segments.append({
            "start": round(segment.start, 3),
            "end": round(segment.end, 3),
            "speaker": label,
            "confidence": 1.0,  # pyannote 3.x does not expose per-segment confidence
        })

    return segments


def write_rttm(segments: list[dict], output_path: str) -> None:
    """Write segments to RTTM (Rich Transcription Time Marked) format."""
    lines = []
    for seg in segments:
        # RTTM format: SPEAKER <file> <channel> <start> <duration> <orthography> <speaker_type> <conf>
        start = seg["start"]
        duration = seg["end"] - seg["start"]
        lines.append(
            f"SPEAKER audio 1 {start:.3f} {duration:.3f} <NA> <NA> {seg['speaker']} {seg.get('confidence', '<NA>')}"
        )
    Path(output_path).write_text("\n".join(lines) + "\n")


def transcribe_with_diarization(
    audio_path: str,
    rttm_output: str = "",
) -> dict:
    """
    High-level wrapper: diarize audio and optionally write RTTM file.

    Args:
        audio_path: Path to audio file.
        rttm_output: Optional path for RTTM output. Pass "" to skip.

    Returns:
        {"segments": [...], "error": None} or {"segments": [], "error": "..."}
    """
    try:
        if not PYANNOTE_AVAILABLE:
            raise RuntimeError("pyannote.audio not installed")

        segments = diarize_audio(audio_path)

        if rttm_output:
            write_rttm(segments, rttm_output)

        return {"segments": segments, "error": None}
    except Exception as e:
        return {"segments": [], "error": str(e)}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="pyannote.audio speaker diarization for Trareon Transcribe"
    )
    parser.add_argument("audio", help="Path to audio file (16kHz mono WAV recommended)")
    parser.add_argument(
        "--output", "-o", default="", help="Output RTTM file path (optional)"
    )
    parser.add_argument(
        "--token",
        "-t",
        default=None,
        help="HuggingFace access token (or set HF_TOKEN env var)",
    )
    parser.add_argument(
        "--min-speakers", type=int, default=None, help="Minimum number of speakers"
    )
    parser.add_argument(
        "--max-speakers", type=int, default=None, help="Maximum number of speakers"
    )
    args = parser.parse_args()

    token = args.token or __import__("os").getenv("HF_TOKEN")
    pipeline = load_pipeline(use_auth_token=token) if token else None

    segments = diarize_audio(
        args.audio,
        pipeline=pipeline,
        min_speakers=args.min_speakers,
        max_speakers=args.max_speakers,
    )

    if args.output:
        write_rttm(segments, args.output)
        print(f"RTTM written to: {args.output}")

    result = {"segments": segments}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
