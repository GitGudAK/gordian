---
spike: 005
name: fm-reflection-quality
type: standard
validates: "Given a real dilemma, when the on-device Foundation Model generates the session plan and verdict via @Generable guided generation, then output quality, latency, and refusal-rate are acceptable vs the Gemini proxy"
verdict: PENDING
related: [002]
tags: [foundation-models, apple-intelligence, on-device, ai, ios26]
---

# Spike 005: Foundation Model Reflection Quality

## What This Validates
Given a real dilemma, when the on-device Foundation Model (Apple Intelligence,
~3B params) generates the session plan and verdict via `@Generable` guided
generation, then output quality / latency / refusal-rate is acceptable versus
the deployed Gemini proxy (spike 002 lineage).

## Research
- `FoundationModels` framework, iOS 26+: `LanguageModelSession`,
  `respond(to:generating:)` with `@Generable` + `@Guide` — schema-constrained
  by construction, no repair ladder needed (contrast: spike 002 found ~40%
  invalid JSON on Gemini without responseSchema).
- Requires Apple Intelligence-capable hardware (iPhone 15 Pro+/A17 Pro+) AND
  Apple Intelligence enabled; `SystemLanguageModel.default.availability`
  reports why when unavailable.
- Guardrails: Apple's model refuses sensitive content with a generation error.
  Gordian's own safety gate currently ALLOWS ordinary-but-spicy dilemmas
  (confrontations, risky money moves) — battery includes two edge dilemmas to
  measure guardrail overlap. If Apple refuses what Gordian permits, the
  all-Apple stack changes the product's envelope.
- Small context window (~4k tokens) — fresh session per dilemma, mirroring
  production statelessness.

## How to Run
TestFlight build from branch `spike/apple-native` (iOS 26 SDK via Xcode Cloud;
this Mac cannot compile these frameworks). On the phone: Settings → LABS →
005 · Foundation Model reflections → **Run full battery**. Then export the
forensic log and share it back for analysis.

## What to Expect
- Availability card says "Model AVAILABLE".
- Six dilemmas each produce: mode classification, options (BINARY only),
  8 tailored questions, and a verdict triple (decision/why/nextStep), with
  per-call latency in ms.
- The two `edge-*` dilemmas reveal whether Apple guardrails refuse content
  Gordian's gate allows.

## Observability
Forensic log: every plan/verdict/error event with ISO timestamps, latencies,
and full generated text. Exported as JSON via share sheet.

## Investigation Trail
- 2026-07-26: Harness built (LabsFMView). Battery of 6 dilemmas mirroring the
  proxy's premium calls. Awaiting first device run.

## Results
PENDING — awaits device run on TestFlight.
