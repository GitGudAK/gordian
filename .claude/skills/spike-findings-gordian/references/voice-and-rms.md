# Voice Input + RMS Sentiment Wave (iOS)

## Requirements

- Use on-device speech recognition where supported (REQ-008; `supportsOnDeviceRecognition == true` verified).
- The RMS sentiment wave is driven from the SAME audio tap that feeds the recognizer (REQ-008).
- Mic + speech-recognition usage descriptions required for App Store (REQ-007).

## How to Build It

**Production implementation: [ios/Gordian/SpeechRecognizer.swift](../../../ios/Gordian/SpeechRecognizer.swift).** The pattern (proven live in spike 003):

1. One `AVAudioEngine` with one input tap serves two consumers:
```swift
input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, request] buffer, _ in
    let db = rmsDb(from: buffer)          // consumer 1: sentiment wave
    request.append(buffer)                 // consumer 2: SFSpeechRecognizer
    ...
}
```
2. RMS math (Android gives this free via `onRmsChanged`; iOS does not):
```swift
// dBFS from PCM, then normalize -60..0 dB → 0..1 for the wave animation
let rms = sqrt(sum / Float(n))
let db = 20 * log10(max(rms, 1e-8))
let normalized = min(max((db + 60) / 60, 0), 1)   // replaces Android's (rms+2)/12
```
3. Request `requiresOnDeviceRecognition = true` when supported (privacy win over Android, which uses Google's service).
4. AVAudioSession: `.record` category, `.measurement` mode; deactivate with `.notifyOthersOnDeactivation` on teardown.
5. Permission order: mic (`AVAudioApplication.requestRecordPermission`) then speech (`SFSpeechRecognizer.requestAuthorization`); degrade to typing-only on denial — never dead-end.

Verified live: tap delivers ~10 buffers/sec; ambient dynamic range −69.6 → −29.6 dBFS on real hardware.

## What to Avoid

- **`AVAudioEngine().inputNode` as a temporary.** AVAudioNode does NOT retain its engine; the deallocated engine leaves a dangling impl pointer → SIGSEGV in `inputFormat(forBus:)`. Always hold a strong engine reference. (Found via crash-report forensics in spike 003.)
- **Touching MainActor state inside the tap closure** — the tap runs on the audio thread; capture the recognition request locally.
- **`AVAudioRecorder` metering + a separate recognizer** — two audio clients fight over the input. Rejected in research.
- For bare CLI test tools only: TCC usage strings must be linker-embedded (`-sectcreate __TEXT __info_plist`) or authorization calls crash.

## Constraints

- Speech+RMS combined (`full` mode) not yet human-verified — the RMS half is proven live; run `sources/003-speech-rms-swift` `./build.sh && ./spike003 full` to close it.
- iOS-only concerns not testable on macOS: audio-session interruptions (calls/Siri), background transitions.
- Partial results drive the live transcription display; final result submits as a "REFLECT" answer.

## Origin

Synthesized from spike: 003 (PARTIAL — RMS proven, speech run pending). Source: sources/003-speech-rms-swift/. Production port: ios/Gordian/SpeechRecognizer.swift.
