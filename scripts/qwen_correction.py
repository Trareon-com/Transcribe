#!/usr/bin/env python3
"""Qwen2.5-7B correction + summarization for Traeon Transcribe.

Reads a JSON request from argv[1]:
    {"transcript": "...", "speakers": ["A","B"], "language": "id"}

Writes JSON to stdout:
    {"corrected_text": "...", "summary": "...", "per_speaker_summary": [...]}

Backend selection:
- macOS Apple Silicon: MLX-LM (faster, ~55 tok/s).
- Other platforms: llama.cpp via subprocess.
- Fallback: pass-through (returns input transcript unchanged).

This script is intentionally offline — no network calls.
"""
from __future__ import annotations

import json
import sys


def pass_through(req: dict) -> dict:
    """No-op: return the transcript verbatim."""
    speakers = req.get("speakers") or []
    return {
        "corrected_text": req.get("transcript", ""),
        "summary": "",
        "per_speaker_summary": [
            {"speaker": s, "summary": ""} for s in speakers
        ],
    }


def run_mlx(prompt: str) -> str:
    """Run Qwen2.5-7B via MLX-LM (macOS Apple Silicon)."""
    try:
        from mlx_lm import load, generate  # type: ignore
    except ImportError:
        return ""
    # Model path is configurable via env; default to a 4-bit quant.
    import os
    model_path = os.environ.get(
        "TRAEON_QWEN_MODEL",
        "mlx-community/Qwen2.5-7B-Instruct-4bit",
    )
    model, tokenizer = load(model_path)
    response = generate(
        model,
        tokenizer,
        prompt=prompt,
        max_tokens=512,
        temp=0.2,
    )
    return response


def run_llama_cpp(prompt: str) -> str:
    """Run Qwen2.5-7B via llama.cpp subprocess."""
    import os
    import subprocess
    binary = os.environ.get("TRAEON_LLAMA_CPP", "llama-cli")
    model = os.environ.get(
        "TRAEON_QWEN_MODEL_GGUF",
        os.path.expanduser("~/Models/qwen2.5-7b-instruct-q4_k_m.gguf"),
    )
    try:
        result = subprocess.run(
            [binary, "-m", model, "-p", prompt, "-n", "512", "--temp", "0.2"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def parse_qwen_output(text: str) -> tuple[str, list[str]]:
    """Parse Qwen's structured response into (corrected, summary_bullets)."""
    if not text:
        return "", []
    corrected = ""
    bullets: list[str] = []
    section = None
    for line in text.splitlines():
        s = line.strip()
        if s.upper().startswith("KOREKSI:"):
            section = "koreksi"
            corrected = s.split(":", 1)[1].strip()
            continue
        if s.upper().startswith("RINGKASAN"):
            section = "ringkasan"
            continue
        if section == "koreksi" and corrected == "" and s:
            corrected = s
        elif section == "ringkasan" and s.startswith("-"):
            bullets.append(s[1:].strip())
    return corrected, bullets


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: qwen_correction.py <request.json>", file=sys.stderr)
        return 2
    try:
        req = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        print(f"invalid json: {e}", file=sys.stderr)
        return 2

    # Build the Indonesian prompt (mirrors Rust build_correction_prompt).
    prompt = (
        "Anda adalah asisten transkripsi berbahasa Indonesia.\n"
        "Tugas: Koreksi kesalahan pengucapan dari hasil ASR, lalu buat ringkasan.\n"
        "Aturan:\n"
        "- Pertahankan nama orang, istilah teknis, dan angka.\n"
        "- Jangan menambahkan informasi yang tidak ada di transkrip.\n"
        "- Tulis ringkasan dalam 3 poin singkat.\n\n"
        f"Transkrip:\n{req.get('transcript', '')}\n\n"
        "Format jawaban:\nKOREKSI: <teks terkoreksi>\nRINGKASAN:\n- <poin 1>\n- <poin 2>\n- <poin 3>"
    )

    # Backend selection.
    import platform
    import os
    backend = os.environ.get("TRAEON_LLM_BACKEND")
    if backend is None:
        if platform.system() == "Darwin" and platform.machine().startswith("arm"):
            backend = "mlx"
        else:
            backend = "llama.cpp"

    if backend == "mlx":
        raw = run_mlx(prompt)
    elif backend == "llama.cpp":
        raw = run_llama_cpp(prompt)
    else:
        raw = ""

    if not raw:
        # Pass-through fallback so the pipeline never breaks.
        out = pass_through(req)
        print(json.dumps(out))
        return 0

    corrected, bullets = parse_qwen_output(raw)
    speakers = req.get("speakers") or []
    summary_text = "\n".join(f"- {b}" for b in bullets)
    out = {
        "corrected_text": corrected or req.get("transcript", ""),
        "summary": summary_text,
        "per_speaker_summary": [
            {"speaker": s, "summary": ""} for s in speakers
        ],
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())