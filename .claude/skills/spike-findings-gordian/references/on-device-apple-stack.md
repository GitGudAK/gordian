# On-Device Apple Stack (Foundation Models + SpeechAnalyzer)

## Requirements

- HYBRID architecture: FM engine on Apple Intelligence devices (iPhone 15 Pro+,
  iOS 26+, model available), Cloudflare proxy for everything else. One seam:
  both engines return `ProxySessionPlan` / `ProxyVerdict`.
- PRIVACY IS THE HEADLINE (founder decision 2026-07-26): on the on-device path
  NOTHING leaves the phone — no proxy call, no strike ping, no metering.
  Refusals are fully local there; server strike ladder is proxy-path only.
- Gordian's own gate MUST run on-device (Apple guardrails de-escalate harmful
  dilemmas instead of refusing — proven with the vandalism test). Gate policy
  is Gordian's, Apple's guardrails are only a backstop.
- Liquid Glass is OUT. The Art-Deco dark/gold card language stands. Do not
  re-propose glassEffect surfaces.
- No third-party code in the binary (already true; on-device path also removes
  the third-party *service*).

## How to Build It

**Engine seam** (proven in `sources/005-fm-reflection-quality/FMEngine.swift`,
running in real sessions):

1. `LanguageModelSession { "instructions…" }` per call — stateless, mirrors the
   proxy; sidesteps the ~4k context window.
2. Guided generation for EVERYTHING: `session.respond(to:generating: T.self)`
   where T is `@Generable`. No JSON parsing, no repair ladder — schema-valid by
   construction.
3. **Enums for classification fields.** `@Generable enum FMMode { case binary,
   yesNo, sensitive, tooBig, notADecision }`. Raw String mode fields
   misclassified 5/6 in the battery; the enum made it structurally impossible.
   Same for risk (`none/selfHarm/harmOthers/illegal`) and sentiment.
4. Gate-in-the-plan: the plan generation's instructions put safety first;
   `sensitive` + risk category maps to the proxy's SENSITIVE payload so the
   production RefusalView renders unchanged.
5. Verdict grounding: instructions must say "you are a mirror: every claim
   must come from the answers below; if the answers do not say it, you do not
   know it" and the decision @Guide must force ONE imperative sentence, never
   a question. Both fabrication modes were observed before these instructions.
6. Availability: `SystemLanguageModel.default.availability == .available`
   gates the engine; `.unavailable(reason)` values seen live:
   `appleIntelligenceNotEnabled`, `modelNotReady`, `deviceNotEligible`.
7. Latency on iPhone 17 Pro: plans 1.2–3.8s, verdicts 1.0–1.6s. No spinner
   redesign needed; the proxy loading state is more than sufficient.

**SpeechAnalyzer** (proven in `sources/006-speechanalyzer-transcription/`):
`SpeechTranscriber(locale:…reportingOptions: [.volatileResults]…)` →
`SpeechAnalyzer(modules:)` → `bestAvailableAudioFormat(compatibleWith:)` →
AVAudioEngine tap → AVAudioConverter → `AsyncStream<AnalyzerInput>` →
iterate `transcriber.results` (volatile vs `isFinal`). Handle the one-time
asset download explicitly via
`AssetInventory.assetInstallationRequest(supporting:)` — making the download a
visible state is exactly what the old SFSpeechRecognizer path lacked.

**SDK gating on this toolchain:** all iOS 26 code behind
`#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`. Local Xcode
16.4 excludes it (build stays green); Xcode Cloud (iOS 26 SDK) compiles it.

## What to Avoid

- Free-text String fields for anything classification-like (battery: 1/6).
- Trusting Apple guardrails as the safety policy — they ran a vandalism
  session and de-escalated rather than refusing.
- `.glassEffect` on Gordian surfaces — rejected by the founder on device.
- Believing the FM path needs the repair ladder: it does not; that is a
  Gemini-only artifact.

## Constraints

- Hardware floor: iPhone 15 Pro / A17 Pro; Apple Intelligence must be enabled
  by the user (Settings), model download ~minutes on first enable.
- ~3B model: keep prompts short and single-purpose; one session per generation.
- Small context (~4k tokens): never accumulate conversation.
- Xcode Cloud only for compilation (Intel Mac ceiling 16.4); "Branch Changes"
  does not build commits that predate the branch condition — push a trigger.

## Origin

Synthesized from spikes: 005, 006, 007
Source files: sources/005-fm-reflection-quality/, sources/006-speechanalyzer-transcription/
