# Project State

**Project:** Gordian iOS (conversion of the Android app in `app/` to a shipping iOS product)
**Updated:** 2026-07-20

## Position

- Milestone: v1 — iOS app on the App Store
- Current phase: 1 (Backend Gemini Proxy) — planning
- iOS port: source-complete in `ios/`, uncompiled (no Xcode on this machine yet)

## Decisions (locked)

- Native SwiftUI rewrite; visual parity with Android; native iOS interaction patterns.
- Backend proxy holds the Gemini key; no BYO-key in consumer UX (BYO remains temporarily until Phase 3).
- Anonymous users; App Attest/DeviceCheck rate limiting; decision history local-only.
- Every Gemini structured call: `responseSchema` + parts concatenation + repair/fallback ladder (spike 002).
- Ship bar: straight to App Store; quality gate is the session flow feel + review compliance.

## Key references

- Requirements: `.planning/REQUIREMENTS.md` (REQ-001…008)
- Product direction: `.planning/notes/ios-product-direction.md`
- Spike findings skill: `.claude/skills/spike-findings-gordian/`
- Open research: `.planning/research/questions.md` (proxy abuse protection)

## History

- 2026-07-20 — Spikes 001–004 run and wrapped; iOS port written; repo created (GitGudAK/gordian); Android Gemini bug-fix task spawned (separate session).
