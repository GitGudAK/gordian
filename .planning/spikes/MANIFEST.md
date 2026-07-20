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
