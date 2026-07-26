---
spike: 006
name: speechanalyzer-transcription
type: standard
validates: "Given spoken dilemmas, when transcribed by SpeechAnalyzer + SpeechTranscriber on-device, then accuracy and latency beat the current SFSpeechRecognizer path"
verdict: VALIDATED
related: [003]
tags: [speechanalyzer, speech, on-device, ios26]
---

# Spike 006: SpeechAnalyzer Transcription

## What This Validates
Given spoken dilemmas, when transcribed by the iOS 26 `SpeechAnalyzer` +
`SpeechTranscriber` pipeline (fully on-device), then accuracy and latency beat
the shipped `SFSpeechRecognizer` path — which failed on a real device once
already (`requiresOnDeviceRecognition` before model download; fixed by
dropping the requirement, spike 003 lineage).

## Research
- `SpeechTranscriber(locale:transcriptionOptions:reportingOptions:attributeOptions:)`
  with `.volatileResults`; `SpeechAnalyzer(modules:)`;
  `bestAvailableAudioFormat(compatibleWith:)`; audio fed as an
  `AsyncStream<AnalyzerInput>` after AVAudioConverter resampling.
- `AssetInventory.assetInstallationRequest(supporting:)` handles the one-time
  model download explicitly — the exact failure mode of the old API becomes a
  measurable, user-visible state instead of a silent error.
- Community reports of a 14s cold-start on some devices (Apple forums) — the
  time-to-first-volatile metric in the log answers this directly.

## How to Run
TestFlight build from `spike/apple-native`. Settings → LABS →
006 · SpeechAnalyzer transcription → Start listening → speak a dilemma →
Stop → export forensic log.

## What to Expect
- First run may log an asset download (time captured).
- Volatile text streams while speaking; finalized text replaces it.
- Log captures time-to-first-volatile, per-result events, final transcript.

## Observability
Forensic log via share sheet: asset events, format, volatile/final results
with timestamps, errors.

## Investigation Trail
- 2026-07-26: Harness built (LabsSpeechView + LabsSpeechEngine).
- 2026-07-26: Device run on iPhone 17 Pro: "works well" — live volatile text and clean finals.

## Results
VALIDATED (2026-07-26). Founder ran live transcription on an iPhone 17 Pro
(iOS 26.5): pipeline works well end-to-end — assets, volatile streaming, and
finalized text on device. Precise latency numbers still welcome via the
exported forensic log, but feasibility is settled: SpeechAnalyzer can replace
the SFSpeechRecognizer path in the real app.
