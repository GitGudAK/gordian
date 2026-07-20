# Gordian iOS — Roadmap

**Created:** 2026-07-20 (lean derivation from REQUIREMENTS.md, ios-product-direction note, and spike findings — no new-project interview)
**Milestone:** v1 — iOS app on the App Store

## Phases

### Phase 1: Backend Gemini Proxy
**Status:** Pending
**Goal:** A small deployed service that holds the single Gemini API key and serves the app's three structured-output calls (clarifying questions, bypass questions, verdict) to anonymous, attested devices — so users get AI with zero setup and the key never ships in the app.
**Requirements:** REQ-001, REQ-002, REQ-005, REQ-006 (server side)
**Depends on:** —
**Notes:** Fully buildable/testable on this machine (no Xcode needed). Open research question in `.planning/research/questions.md` (abuse protection). Spike-002 hardening (responseSchema, parts concat, repair ladder) moves server-side.

### Phase 2: iOS First Build & Simulator Bring-Up
**Status:** Pending
**Goal:** The `ios/` port compiles in Xcode, runs on the Simulator, and every screen of the Android app works end-to-end (with BYO key for now).
**Requirements:** REQ-004, REQ-008
**Depends on:** Xcode installed (spike 001 remediation)
**Notes:** Expect first-build fixups — the port was written without a compiler. Close spike 003/004 verification here.

### Phase 3: Proxy Integration & BYO-Key Removal
**Status:** Pending
**Goal:** The iOS app calls the Phase 1 proxy with App Attest, the Calibrate key-entry UX is removed, and sessions degrade gracefully (loading states sized for ~7s, fallback ladder intact).
**Requirements:** REQ-001, REQ-002, REQ-003, REQ-006
**Depends on:** Phase 1, Phase 2

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
