# Phase 1: Backend Gemini Proxy - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning
**Source:** Express derivation from `.planning/notes/ios-product-direction.md`, `.planning/REQUIREMENTS.md`, and `.planning/research/questions.md` (user decisions from the 2026-07-20 explore session)

<domain>
## Phase Boundary

A deployed HTTP service that fronts the Gemini API for the Gordian iOS app. It owns the single Gemini API key, exposes the app's three generation operations (clarifying questions, 12 bypass questions, Gordian Verdict), authenticates callers via Apple device attestation (no user accounts), rate-limits per device, and caps total spend. Out of scope: any iOS client changes (Phase 3), user accounts, storing user dilemmas server-side.

</domain>

<decisions>
## Implementation Decisions

### Access model (locked)
- No user accounts; anonymous devices authenticate with App Attest/DeviceCheck (REQ-002).
- User dilemma text passes through to Gemini but is NEVER persisted server-side (REQ-003 privacy story: logs must not contain dilemma content).

### Gemini contract (locked, from spike 002)
- Every structured call sets `responseSchema` (ARRAY-of-STRING for question lists; OBJECT {sentiment, analysis, probe} for verdict) and `responseMimeType: application/json` (REQ-005).
- All response `parts` concatenated; bracket-repair before failure; structured error to the client so it can fall back locally (REQ-005/006).
- Model `gemini-3.5-flash` (thinking model, ~7s/call); model name configurable server-side without an app release.

### Cost & abuse (locked intent, details Claude's discretion)
- Per-device rate limits sized to the product (a session ≈ 3 calls); hard daily global spend cap; input length caps on dilemma text.
- When a cap is hit, return a distinct error code the app maps to its local-fallback ladder.

### Business hooks (locked, from b2c-strategy 2026-07-20)
- Proxy counts AI sessions per device — Phase 3.5's freemium meter (3 AI sessions/week free) reads this count. Design the counter now even if the meter enforces later.
- Model must be swappable server-side per operation (bake-off: Gemini flash vs Claude Haiku 4.5; hybrid Haiku-questions/Sonnet-verdict is on the table). Endpoints are operation-shaped, not model-shaped.
- Future: serves `guides.json` (remote guide content for new-guide notifications). Reserve the route; content can come later.

### Claude's Discretion
- Hosting platform, language/framework, storage for rate-limit counters, exact limit numbers, App Attest verification implementation details, deployment pipeline. Bias: smallest respectable option; ~7s upstream calls must fit platform timeout limits.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Gemini behavior (proven)
- `.claude/skills/spike-findings-gordian/references/gemini-structured-output.md` — the wire contract, schema JSON, truncation trap, latency facts
- `ios/Gordian/GeminiClient.swift` — client-side port of the same contract (the proxy re-homes this logic server-side)
- `.planning/spikes/002-gemini-swift-client/` — spike evidence and fixtures

### Product constraints
- `.planning/REQUIREMENTS.md` — REQ-001/002/003/005/006
- `.planning/notes/ios-product-direction.md` — why proxy, why anonymous
- `.planning/notes/b2c-strategy.md` — session metering, model bake-off, freemium hooks
- `.planning/research/questions.md` — open abuse-protection questions this phase must answer

</canonical_refs>

<specifics>
## Specific Ideas

- Three endpoints mirroring the app's operations rather than a raw Gemini passthrough — the prompts live server-side so prompt iteration doesn't require app releases.
- Fixtures from spike 002 (`fixtures/*.json`) become proxy test fixtures.
- The Gemini API key used during spiking is considered compromised (pasted in chat) — the proxy launches with a fresh key.

</specifics>

<deferred>
## Deferred Ideas

- Streaming responses to shave perceived latency (evaluate after v1).
- Freemium/quota tiers (product direction chose flat free access for v1).
- iOS client integration — Phase 3.

</deferred>

---

*Phase: 01-backend-gemini-proxy*
*Context gathered: 2026-07-20 via express derivation from exploration artifacts*
