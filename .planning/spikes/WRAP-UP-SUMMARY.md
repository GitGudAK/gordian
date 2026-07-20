# Spike Wrap-Up Summary

**Date:** 2026-07-20
**Spikes processed:** 4
**Feature areas:** Gemini structured output, Voice + RMS wave, SwiftUI session flow, iOS toolchain
**Skill output:** `./.claude/skills/spike-findings-gordian/`

## Processed Spikes

| # | Name | Type | Verdict | Feature Area |
|---|------|------|---------|--------------|
| 001 | ios-toolchain-readiness | standard | INVALIDATED (env gap) | iOS toolchain |
| 002 | gemini-swift-client | standard | VALIDATED | Gemini structured output |
| 003 | speech-rms-swift | standard | PARTIAL | Voice + RMS wave |
| 004 | swiftui-session-flow | standard | PARTIAL | SwiftUI session flow |

## Key Findings

- **Gemini reliability:** gemini-3.5-flash under plain JSON mode emitted truncated arrays (missing `]`) in ~40% of live runs despite `finishReason: STOP`; `responseSchema` constrained decoding fixed it (6/6 passes). The deployed Android app carries this bug (fix task spawned). Latency ~7s/call (thinking model).
- **Voice parity:** iOS has no `onRmsChanged`; a single AVAudioEngine tap feeding both SFSpeechRecognizer and hand-computed RMS is proven live (10 Hz, real hardware). Landmine: AVAudioNode does not retain its engine — `AVAudioEngine().inputNode` segfaults. On-device recognition supported.
- **UI portability:** the whole session flow fits SwiftUI 2.0-era APIs; Compose→SwiftUI mapping was mechanical. One 60s clock per rapid-fire session.
- **Environment:** no Xcode, Swift 5.4 CLT, 25 GiB free disk — iOS builds blocked until remediation; macOS-SDK prototyping is the workaround (SwiftUI/Speech ship in the old CLT SDK).
- **Downstream:** source-complete iOS port in `ios/` (uncompiled); v1 product direction captured in `.planning/notes/ios-product-direction.md` + `.planning/REQUIREMENTS.md`.

Open verification: `spike003 full` (speech+RMS with a human speaking), `SessionFlow` feel check, and first Xcode build of `ios/`.
