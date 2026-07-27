# Spike Manifest

## Idea
Convert the Gordian Android app (Kotlin/Jetpack Compose, ~9 source files) to a native iOS app. Gordian is a 60-second decision-paralysis-bypass tool: describe a dilemma → Gemini generates clarifying + 12 rapid-fire bypass questions → 60s pressure session with voice input and an RMS-driven sentiment wave → Gemini synthesizes a structured "Gordian Verdict" → logged to a local database. The spikes validate the risky seams of a native SwiftUI rewrite before committing to the port.

## Requirements
Design decisions locked in by the user during spiking. Non-negotiable for the real build.

- Conversion approach: **native SwiftUI rewrite** (not KMP, not cross-platform) — app is small enough that sharing schemes cost more than they save.
- Gemini API key is supplied at runtime via environment/user settings — never hardcoded, never committed.
- Keep parity with Android behavior: structured JSON output from Gemini (`responseMimeType: application/json`), graceful local fallbacks when no key/API failure, decision history persisted locally.
- Gemini calls MUST set `responseSchema` (constrained decoding) and concatenate all response `parts` — proven necessary by spike 002 (~40% invalid JSON otherwise on gemini-3.5-flash).
- Generation UX must show a loading state: thinking-model calls run ~7s.
- Rotate the Gemini API key used during spiking before any release (it appeared in a chat transcript).

- On-device gate is a HARD REQUIREMENT for any Foundation Models integration (2026-07-26): Apple guardrails allowed a vandalism dilemma through (de-escalated instead of refusing). Gordian's refusal policy is replicated as on-device classification (built into FMEngine).
- PRIVACY IS THE HEADLINE (founder decision 2026-07-26): on the on-device path, NOTHING leaves the phone — no proxy, no Google, not even strike pings. Refusal handling is fully local there (tradeoff accepted: reinstall resets the ladder on that path). The server strike ladder applies to the proxy path only. Marketing claim unlocked: dilemmas never leave the device on supported iPhones.
- Liquid Glass is OUT (2026-07-26, founder decision): Gordian keeps its Art-Deco dark/gold card language. Do not re-propose Glass surfaces.
- All-Apple exploration (2026-07-26): spikes 005-007 live on branch `spike/apple-native`, gated behind `#if canImport(FoundationModels)` + TestFlight receipt so main and App Store builds never see Labs. iOS 26 code compiles ONLY on Xcode Cloud (Intel Mac ceiling: Xcode 16.4).
- "No 3rd-party code in binary" already holds for the shipped app (zero SPM/CocoaPods deps); the exploration targets removing the *server* dependency (Gemini proxy) via on-device Foundation Models.

## Environment Constraints (discovered 2026-07-20)
- Host: macOS 15.7.7, **no Xcode installed** — Command Line Tools only (Swift 5.4, no iOS SDK, no Simulator).
- Spikes 001/004 are gated on the user installing Xcode from the App Store (~15 GB, requires Apple ID).
- gordian is **not a git repository** — spike commits skipped.

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001 | ios-toolchain-readiness | standard | Given this Mac (macOS 15.7, CLT-only), when we attempt an iOS SwiftUI build, then the toolchain compiles and a Simulator boots | VALIDATED (remediated 2026-07-20: Xcode 16.4 via xcodes/aria2; iOS 18.6 runtime; first build succeeded) | [toolchain, xcode, environment] |
| 002 | gemini-swift-client | standard | Given a Gemini API key, when generateContent is called from Swift/URLSession with responseMimeType application/json, then 12 bypass questions decode via Codable | VALIDATED (responseSchema required — plain JSON mode ~40% invalid on this thinking model) | [gemini, urlsession, codable, ai] |
| 003 | speech-rms-swift | standard | Given mic input, when captured via SFSpeechRecognizer + AVAudioEngine, then live transcription and RMS levels stream | PARTIAL (RMS half proven live; speech half awaits user mic run) | [speech, avaudioengine, rms, voice] |
| 004 | swiftui-session-flow | standard | Given the 60s countdown + rapid-fire flow, when built in SwiftUI, then the pressure-session feel matches the Android version | PARTIAL (runs as macOS SwiftUI app; Simulator validation gated on 001) | [swiftui, timer, ux] |
| 005 | fm-reflection-quality | standard | Given a real dilemma, when the on-device Foundation Model generates plan + verdict via @Generable, then quality/latency/refusal-rate is acceptable vs the Gemini proxy | VALIDATED (after enum/grounding hardening: founder-confirmed grounded verdicts + contextual questions in REAL sessions on-device; hybrid architecture required — FM on capable devices, proxy elsewhere, gate on-device, strikes server-side) | [foundation-models, apple-intelligence, ios26] |
| 006 | speechanalyzer-transcription | standard | Given spoken dilemmas, when transcribed by SpeechAnalyzer/SpeechTranscriber on-device, then accuracy + latency beat SFSpeechRecognizer | VALIDATED (2026-07-26 on iPhone 17 Pro — pipeline works well live) | [speechanalyzer, speech, ios26] |
| 007 | liquid-glass-identity | standard | Given the Art-Deco dark/gold identity, when key surfaces adopt glassEffect, then the brand survives the material | INVALIDATED (founder rejected the glass telling; deco identity stands) | [liquid-glass, swiftui, ios26] |
| 008 | adapter-pipeline-feasibility | standard | Given Apple's adapter toolkit on a rented GPU, when a toy adapter is trained and shipped via TestFlight, then SystemLanguageModel(adapter:) loads and generates on-device | PENDING (gated on operator: RunPod/Lambda account; Intel Mac cannot run the toolkit) | [lora, adapter, foundation-models] |
| 009 | distillation-dataset | standard | Given the labeled corpus + two teachers (Gemini, Claude) + judge pass, when sessions are batch-generated, then a toolkit-ready training set encodes the house style | PENDING (corpus 218 seeds + Teacher A script ready; needs fresh operator Gemini key) | [lora, distillation, dataset] |
| 010 | adapter-quality-delta | standard | Given the trained adapter, when A/B'd against the base model on a fixed battery, then question sharpness and verdict grounding measurably improve | PENDING (blocked on 008+009) | [lora, adapter, eval] |
