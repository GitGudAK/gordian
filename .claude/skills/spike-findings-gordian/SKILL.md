---
name: spike-findings-gordian
description: Implementation blueprint from spike experiments. Requirements, proven patterns, and verified knowledge for building Gordian's iOS app. Auto-loaded during implementation work.
---

<context>
## Project: gordian

Convert the Gordian Android app (Kotlin/Jetpack Compose) to a native iOS app. Gordian is a 60-second decision-paralysis-bypass tool: describe a dilemma → Gemini generates clarifying + 12 rapid-fire bypass questions → 60s pressure session with voice input and an RMS-driven sentiment wave → Gemini synthesizes a structured "Gordian Verdict" → logged to a local database. A source-complete SwiftUI port now lives in `ios/` (never compiled — no Xcode on this machine yet).

Spike sessions wrapped: 2026-07-26 (005-007), 2026-07-20
</context>

<requirements>
## Requirements

Non-negotiable decisions from spiking and the product exploration (full list: `.planning/REQUIREMENTS.md`):

- Conversion approach: **native SwiftUI rewrite** — not KMP, not cross-platform.
- Gemini calls MUST set `responseSchema` and concatenate all response `parts` (~40% invalid JSON otherwise on gemini-3.5-flash).
- Generation UX must show a loading state — thinking-model calls run ~7s.
- Keep the degradation ladder: schema → JSON repair → local fallback questions; sessions never dead-end.
- API keys via env/user settings only; rotate the spike-era key before release.
- v1 product direction: backend Gemini proxy (no BYO key in consumer UX), anonymous + local-only history, native polish only, straight to App Store (see `.planning/notes/ios-product-direction.md`).
- HYBRID engine: on-device Foundation Models on capable iPhones (nothing leaves the phone — no proxy, no strike pings), Cloudflare proxy elsewhere; both behind ProxyClient's types.
- Gordian's gate runs on-device on the FM path (Apple guardrails are a backstop, not the policy). Server strike ladder is proxy-path only.
- Liquid Glass rejected; Art-Deco dark/gold identity is permanent.
</requirements>

<findings_index>
## Feature Areas

| Area | Reference | Key Finding |
|------|-----------|-------------|
| Gemini structured output | references/gemini-structured-output.md | `responseSchema` is mandatory: plain JSON mode drops the closing `]` ~40% of the time on this thinking model |
| Voice + RMS wave | references/voice-and-rms.md | One AVAudioEngine tap feeds recognizer AND hand-computed RMS; engine must be strongly retained (segfault otherwise) |
| On-Device Apple Stack | references/on-device-apple-stack.md | Hybrid FM engine validated: private, 1-4s, enum-constrained; own gate mandatory; Glass rejected |
| SwiftUI session flow | references/swiftui-session-flow.md | Full Compose→SwiftUI mapping table; one 60s clock per session, never per question |
| iOS toolchain | references/ios-toolchain.md | This Mac can't build iOS yet — Xcode + ~30 GB disk remediation checklist |

## Source Files

Original spike source files are preserved in `sources/` for complete reference. The productionized versions live in `ios/Gordian/` — prefer those as the starting point for build work.
</findings_index>

<metadata>
## Processed Spikes

- 001-ios-toolchain-readiness
- 002-gemini-swift-client
- 003-speech-rms-swift
- 004-swiftui-session-flow
- 005-fm-reflection-quality
- 006-speechanalyzer-transcription
- 007-liquid-glass-identity
</metadata>
