# ASR Model Evaluation Results

## Test Setup
- **Audio source**: `<path/to/test_audio.wav>`
- **Reference transcript**: `<paste reference text here>`
- **Date**: `<YYYY-MM-DD>`

## Results Table

| Model | WER (CommonVoice ID) | WER (In-the-wild) | Latency (16kHz, 30s) | macOS Offline |
|-------|----------------------:|-------------------:|---------------------:|:-------------:|
| whisper-large-v3-turbo | — | — | — | ✅ |
| whisper-medium | — | — | — | ✅ |
| whisper-small-turbo | — | — | — | ✅ |

## WER Calculation

```bash
# Install jiwer if needed
pip install jiwer

# Calculate WER
python3 -c "
from jiwer import wer, cer
ref = open('reference.txt').read().strip()
hyp = open('hypothesis.txt').read().strip()
print(f'WER: {wer(ref, hyp):.2%}')
print(f'CER: {cer(ref, hyp):.2%}')
"
```

## Latency Benchmarks (seconds)

| Model | 30s audio | 60s audio | 5min audio |
|-------|----------:|----------:|-----------:|
| large-v3-turbo | — | — | — |
| medium | — | — | — |
| small-turbo | — | — | — |

## macOS Offline Capability

| Model | Metal (Apple Silicon) | CPU | CoreML |
|-------|----------------------|-----|--------|
| large-v3-turbo | ✅ | ✅ (slow) | ✅ (fastest) |
| medium | ✅ | ✅ (slow) | ✅ (fastest) |
| small-turbo | ✅ | ✅ | ✅ |

## Notes

- CommonVoice ID WER measured on held-out dev set
- In-the-wild WER measured on real Indonesian call recordings
- CoreML backend requires `whisper.cpp` compiled with `-DWHISPER_COREML=ON`
- Latency measured on MacBook Pro M3 Max, 16GB RAM
