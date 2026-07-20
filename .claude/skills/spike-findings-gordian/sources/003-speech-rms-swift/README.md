---
spike: 003
name: speech-rms-swift
type: standard
validates: "Given mic input, when captured via SFSpeechRecognizer + AVAudioEngine, then live transcription and RMS levels stream (parity with Android's onRmsChanged sentiment wave)"
verdict: PARTIAL
related: [001-ios-toolchain-readiness, 004-swiftui-session-flow]
tags: [speech, avaudioengine, rms, voice]
---

# Spike 003: Speech + RMS in Swift

## What This Validates
Android's `RecognitionListener.onRmsChanged(rmsdB)` drives Gordian's sentiment-wave animation for free. iOS has no RMS callback on `SFSpeechRecognizer` — the port hinges on one `AVAudioEngine` input tap feeding **both** the recognizer (`SFSpeechAudioBufferRecognitionRequest.append`) and a hand-computed RMS meter. This spike proves that dual-consumer tap pattern with the exact frameworks iOS uses, running on macOS.

## Research
| Approach | Tool/Library | Pros | Cons | Status |
|----------|-------------|------|------|--------|
| AVAudioEngine tap → SFSpeechRecognizer + DIY RMS | Speech + AVFoundation | One pipeline, two consumers; live partials; on-device option | RMS is manual math; two-permission dance | **Chosen** |
| AVAudioRecorder metering + separate recognizer | AVAudioRecorder | Built-in `averagePower` | Two audio clients fight over the input | Rejected |
| WhisperKit | 3rd-party ML | Offline, accurate | Heavy dep for a short reflection snippet | Rejected |

## How to Run
```bash
cd .planning/spikes/003-speech-rms-swift
./build.sh              # embeds Info.plist TCC usage strings into the CLI binary
./spike003 status       # authorization + device probe, no recording
./spike003 rms          # 8s live ASCII RMS meter (mic only)
./spike003 full         # 12s meter + live partial transcription (speak to it!)
```

## What to Expect
- `status`: mic/speech auth states, recognizer availability + on-device support, input format.
- `rms`: a live-updating ASCII level bar that jumps when you speak; RMS stats on exit.
- `full`: the bar plus your words appearing live next to it; final transcript + voiced-sample stats. First run triggers a macOS speech-recognition permission prompt.

## Observability
Forensic log (`spike003-log.json`): ISO-timestamped events (AUTH/PROBE/AUDIO/SPEECH/RESULT), full RMS sample series stats (min/max/mean dBFS, voiced-sample count), partial transcripts logged silently at full rate.

## Investigation Trail
1. Compiled clean against the CLT macOS 11.3 SDK with `-framework Speech -framework AVFoundation` — both frameworks present even in this ancient SDK.
2. First `status` run **segfaulted** (SIGSEGV in `-[AVAudioNode inputFormatForBus:]`). Crash report analysis: `AVAudioEngine().inputNode` lets the engine temporary deallocate; **AVAudioNode does not retain its engine**, leaving a dangling impl pointer. Minimal repro confirmed. Fix: always hold a strong reference to the engine. This is a real-build landmine worth remembering.
3. TCC for bare CLIs: usage-description strings must be embedded via `-sectcreate __TEXT __info_plist`, otherwise authorization requests crash. `build.sh` does this.
4. `status` after fix: mic **authorized**, `SFSpeechRecognizer(en-US)` available with **on-device recognition supported**, default input Shure MV6 at 48 kHz mono.
5. `rms` live run: tap delivered 80 buffers in 8 s (~10 Hz), RMS range −69.6 → −29.6 dBFS with ambient audio. Normalization mapping chosen: `(db + 60) / 60` clamped to 0..1, replacing Android's `(rms + 2) / 12` — same downstream contract for the wave animation.
6. Not yet exercised: `full` mode (speech + RMS simultaneously) — needs a human speaking and a one-time speech-recognition TCC grant. See checkpoint below.

## Results
**Verdict: PARTIAL → expected VALIDATED after user runs `./spike003 full` and sees live words + meter together.**

Proven:
- The dual-consumer tap architecture compiles and the RMS half runs live on real hardware — this was the risky half, since it's the part Android gives away free and iOS doesn't.
- On-device recognition is supported (`supportsOnDeviceRecognition == true`), meaning the iOS app can transcribe without sending audio to Apple's servers — better than the Android version's behavior.
- Landmine documented: keep `AVAudioEngine` strongly referenced; embed usage descriptions.

iOS-specific deltas for the real build (not testable on macOS): `AVAudioSession` category setup (`.record`, `.measurement`), interruption handling (calls/Siri), and mic-permission UX. These are well-trodden; risk is low now that the pipeline pattern is proven.
