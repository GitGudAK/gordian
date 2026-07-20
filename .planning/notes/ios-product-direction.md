---
title: iOS product direction decisions
date: 2026-07-20
context: /gsd-explore session following iOS conversion spikes 001-004
---

# iOS Product Direction

Goal: convert Gordian to a high-quality, iOS-centric app that strangers use — same visual identity (near-black/gold, 60-second session structure), native iOS feel.

## Decisions

**1. AI access: backend proxy (not bring-your-own-key).**
The Android app only becomes smart when the user pastes their own Gemini API key; without it, users silently get canned fallback questions. A mass-market audience won't create AI Studio accounts. Decision: run a small server holding one Gemini key; the app calls it with zero user setup. Consequences: the Calibrate tab's key-entry UX disappears from the consumer app; we own the Gemini bill, latency UX, and abuse protection.

**2. Identity: anonymous, decision history local-only.**
No accounts, no sign-in. Rate limiting via device attestation (DeviceCheck / App Attest). Decision history (users' private dilemmas — unusually sensitive data) stays on-device, as in the Android app. This is a marketing-grade privacy story: "your dilemmas never leave your phone; only question generation touches the server."

**3. "iOS-centric" = native polish, no headline features.**
SF Symbols, native tab bar/navigation, spring animations, Dynamic Type, dark-mode correctness. Explicitly deferred: widgets, Siri App Intents, Live Activity/Dynamic Island, rich haptics (see seed: re-engagement-layer).

**4. Ship bar: straight to App Store (no TestFlight beta gate).**
Quality gate = the session flow feels flawless + App Store review readiness (mic/speech privacy strings, AI-generated-content policy compliance). Iterate from public reviews.

## Implications flagged from spike findings

- Gemini 3.5 Flash is a thinking model: ~7s per generation call. With a proxy at scale, latency UX (loading states) and per-device rate caps are launch requirements, not polish.
- All spike-002 hardening carries into the proxy: `responseSchema` on every structured call, concatenate response `parts`, repair + fallback ladder.

Related: [[re-engagement-layer]], spikes MANIFEST requirements section.
