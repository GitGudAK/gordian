# Project State

**Project:** Gordian iOS (conversion of the Android app in `app/` to a shipping iOS product)
**Updated:** 2026-07-20

## Position

- Milestone: v1 — iOS app on the App Store
- Current phase: 1 COMPLETE (2026-07-21) — proxy LIVE at `https://gordian-proxy.gordian-app.workers.dev` with fresh key; both operations smoke-tested against real Gemini; error contract verified on production. Phase 3 COMPLETE same day: app → proxy wired (ProxyClient.swift, X-Device-ID), GeminiClient + key plumbing deleted, live-verified in Simulator (AI questions + AI verdict through the proxy with zero keys in the app). Next: Phase 3.5 (monetization) or Phase 4 (polish).
- iOS port: BUILDS AND RUNS — Xcode 16.4 installed 2026-07-20 (Intel Mac → xcodes+aria2 route; App Store Xcode is Apple-Silicon-only). First build: zero errors. Running on iPhone 16 Pro simulator (iOS 18.6). Phase 2 (first build & bring-up) effectively underway.

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

## Open items (2026-07-21)

- AI-ALWAYS DECISION (user, 2026-07-21): no pre-canned questions ever; proxy retries a fallback model; app shows retry UI instead of the bank. CONSEQUENCE for Phase 3.5: the "unlimited offline sessions" free-tier leg no longer exists — freemium design needs a revisit (what does a free user get after the weekly AI meter is exhausted?).
- Safety lockout shipped: client keyword screen + server SENSITIVE gate → 5-minute lockout with 988 resources. Consider expanding the keyword list and localizing crisis resources before launch.

## Older open items (2026-07-20)

- Notification permission on simulator stuck denied — flip in sim Settings app (keeps logs) or reinstall app (wipes logs) to live-test follow-ups/Daily Knot/Weekly Recap.
- "Not-a-decision" input handling designed, not built: classification gains NOT_A_DECISION (+reframe suggestion) and SENSITIVE (crisis resources, never gamified) modes; offline heuristic; bounce UI on preparing screen.
- Design tickets #12 (clean knot asset re-export, radius unification) and #13 (VoiceOver pass, symbol weights) partially open; #1–#11 closed.
- Phase 1 proxy built (see Position). Bake-off tooling ready (`cd proxy && npm run bake-off`) — needs ANTHROPIC_API_KEY (+ GEMINI_API_KEY) in env. guides route reserved (404).
- Rotate the spike-era Gemini API key NOW — verified still active 2026-07-20. It has been removed from the simulator's UserDefaults; create the fresh key when doing the proxy secret step.
- Spike verifications still open: 003 speech+RMS `full` run, 004 session feel check (now moot-ish — real app runs).

## History

- 2026-07-20 — Spikes 001–004 run and wrapped; iOS port written; repo created (GitGudAK/gordian); Android Gemini bug-fix task spawned (separate session). Same day: Xcode 16.4 installed (Intel route), first build succeeded, app running in Simulator; design review shipped 11/13 tickets; verdict/copy simplification; decision follow-up loop + Daily Knot + Weekly Recap built; knot glyph replaced bolt.
