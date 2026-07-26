---
spike: 007
name: liquid-glass-identity
type: standard
validates: "Given Gordian's Art-Deco dark/gold identity, when key surfaces adopt Liquid Glass, then the brand survives the material"
verdict: INVALIDATED
related: [004]
tags: [liquid-glass, swiftui, design, ios26]
---

# Spike 007: Liquid Glass Identity

## What This Validates
Given Gordian's Art-Deco dark/gold identity, when the four signature surfaces
(hero, dilemma card, CTA capsule, verdict card) adopt Liquid Glass
(`.glassEffect`), then the brand survives the material. Human-judgment spike —
screenshots are the evidence, taste is the verdict.

## Research
- `.glassEffect(_:in:)` with `.regular`, `.tint(_:)`, `.interactive()` on iOS
  26. Gold tint at low opacity approximates the current card language while
  picking up Glass refraction.
- Risk: Liquid Glass is designed for content-rich backdrops; Gordian's near
  black background gives Glass little to refract — it may read as merely
  "slightly lighter cards," in which case the deco identity wins and Glass is
  cosmetic.

## How to Run
TestFlight build from `spike/apple-native`. Settings → LABS →
007 · Liquid Glass identity. Flip the toggle per surface set; screenshot both
states and judge.

## What to Expect
Four Gordian surfaces rendered twice: shipped styling vs glass counterpart.

## Investigation Trail
- 2026-07-26: Harness built (LabsGlassView with GlassOrCard flip modifier).
- 2026-07-26: Founder ran the toggle on an iPhone 17 Pro (iOS 26.5) and rejected the glass telling outright. Harness deleted.

## Results
INVALIDATED (2026-07-26, founder judgment on device). Liquid Glass does not
carry Gordian's Art-Deco dark/gold identity — the near-black backdrop gives
Glass nothing to refract and the surfaces lose their considered card language.
Harness removed from Labs; the shipped styling stands. Matches the risk noted
in Research.
