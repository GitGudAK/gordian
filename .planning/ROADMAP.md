# Gordian iOS — Roadmap

**Created:** 2026-07-20 (lean derivation from REQUIREMENTS.md, ios-product-direction note, and spike findings — no new-project interview)
**Milestone:** v1 — iOS app on the App Store

## Phases

### Phase 1: Backend Gemini Proxy
**Status:** Complete (2026-07-21) — live at `https://gordian-proxy.gordian-app.workers.dev`
**Goal:** A small deployed service that holds the single Gemini API key and serves the app's two structured-output operations (session-plan generation and verdict synthesis — the clarifying-questions step was removed from the app) to anonymous devices — so users get AI with zero setup and the key never ships in the app. Launch lane: opaque device ID + strict limits; App Attest hardening deferred.
**Requirements:** REQ-001, REQ-002, REQ-005, REQ-006 (server side)
**Depends on:** —
**Notes:** Fully buildable/testable on this machine (no Xcode needed). Open research question in `.planning/research/questions.md` (abuse protection). Spike-002 hardening (responseSchema, parts concat, repair ladder) moves server-side. Also serves `guides.json` (remote guide content) — prerequisite for new-guide notifications (see seeds/habit-loops.md).

### Phase 2: iOS First Build & Simulator Bring-Up
**Status:** Pending
**Goal:** The `ios/` port compiles in Xcode, runs on the Simulator, and every screen of the Android app works end-to-end (with BYO key for now).
**Requirements:** REQ-004, REQ-008
**Depends on:** Xcode installed (spike 001 remediation)
**Notes:** Expect first-build fixups — the port was written without a compiler. Close spike 003/004 verification here.

### Phase 3: Proxy Integration & BYO-Key Removal
**Status:** Complete (2026-07-21) — app calls the live proxy via anonymous device ID (App Attest deferred to post-launch per locked decision); GeminiClient + all key plumbing deleted; offline fallback ladder intact
**Goal:** The iOS app calls the Phase 1 proxy with App Attest, the Calibrate key-entry UX is removed, and sessions degrade gracefully (loading states sized for ~7s, fallback ladder intact).
**Requirements:** REQ-001, REQ-002, REQ-003, REQ-006
**Depends on:** Phase 1, Phase 2

### Phase 3.5: Monetization — Free Week + Purchase (re-decided + BUILT 2026-07-21)
**Status:** App side COMPLETE; App Store Connect setup pending (operator)
**Goal:** Free 7-day trial from first launch, then subscription ($3.99/mo, $19.99/yr) or lifetime unlock ($49.99). Coupon lanes: subscription Offer Codes (3-months-free) + Promo Codes for lifetime. AI-always for everyone with access; no meters. See `.planning/notes/monetization-setup.md` for the ASC runbook.
**Requirements:** user directives 2026-07-21
**Depends on:** Phase 3

### Phase 4: Native Polish Pass
**Status:** Pending
**Goal:** The session flow feels flawless: spring animations, Dynamic Type, dark-mode correctness, SF Symbol consistency, touch-target sizing — the "native polish only" bar from the product direction.
**Requirements:** REQ-004
**Depends on:** Phase 2

### Phase 5: App Store Readiness
**Status:** Pending
**Goal:** Submission-ready build: app icon, privacy nutrition labels consistent with local-only history, mic/speech usage strings verified, AI-content policy compliance, screenshots, TestFlight-to-release pipeline.
**Requirements:** REQ-003, REQ-007
**Depends on:** Phase 3, Phase 4

## v2 (deferred)

- **Voice session mode** — conversational spoken sessions with a calming voice (seed: `.planning/seeds/voice-session-mode.md`, spike plan pre-scoped). Deferred 2026-07-20.
- **Re-engagement layer** — haptics/sound, widgets, Siri intents, Live Activity (seed: `.planning/seeds/re-engagement-layer.md`).
- **Habit loops** — decision follow-ups ("did you act on it?"), Daily Knot, decisiveness streaks, weekly recap, new-guide notifications (seed: `.planning/seeds/habit-loops.md`). New-guide notifications depend on Phase 1's remote guides endpoint.
