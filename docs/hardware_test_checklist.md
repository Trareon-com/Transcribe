# Trareon Transcribe — Live Audio Hardware Test Checklist

Run this on a real macOS, Windows, and Linux machine before V1 release.

## macOS

- [ ] Start app → start session with **Mikrofon HIDUP** → speak → segments appear.
- [ ] Verify `~/Documents/TrareonTranscribe/YYYYMMDD-*` contains exported files.
- [ ] Start session with **Pengeras Suara HIDUP** → play audio in browser/Zoom → speaker segments appear.
- [ ] Install BlackHole 2ch → enable Multi-Output Device → dual capture mic+speaker works.
- [ ] Toggle mic/speaker during recording → UI reflects state, no crash.
- [ ] Upload `.mp3` file on Library screen → transcription completes.
- [ ] Export all 8 formats → files open correctly (MD, TXT, JSON, SRT, VTT, HTML, DOCX, WAV).
- [ ] Close laptop lid / sleep → resume, watchdog reconnects (check recovery banner).

## Windows

- [ ] Start app → start session with **Mikrofon HIDUP** → speak → segments appear.
- [ ] Start session with **Pengeras Suara HIDUP** → WASAPI loopback captures system audio.
- [ ] Dual capture mic+speaker works.
- [ ] Toggle mic/speaker during recording → UI reflects state, no crash.
- [ ] Upload `.mp3` file → transcription completes.
- [ ] Export all 8 formats → files valid.
- [ ] Sleep/wake → watchdog reconnects.

## Linux

- [ ] Build AppImage with `bash scripts/package_linux.sh`.
- [ ] Launch AppImage → main screen renders.
- [ ] Mic capture works.
- [ ] Speaker loopback works (PulseAudio / PipeWire).
- [ ] Export all 8 formats works.

## Sign-off

| Platform | Tester | Date | Result |
|----------|--------|------|--------|
| macOS    |        |      |        |
| Windows  |        |      |        |
| Linux    |        |      |        |
