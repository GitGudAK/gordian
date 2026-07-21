# Phase 1 Execution Report — Backend Gemini Proxy

**Date:** 2026-07-20 (autonomous session; directive: "Build and test Phase 1, no questions")
**Result: BUILT AND FULLY OFFLINE-VERIFIED.** Everything that can run without the operator's Cloudflare login and a fresh Gemini key is done, tested, simulated, and committed. Going live is a ~5-minute operator runbook (below).

## What was built (`proxy/`, Cloudflare Workers, zero runtime deps)

| Piece | Detail |
|---|---|
| Endpoints | POST `/v1/session-plan`, POST `/v1/verdict`; GET `/v1/guides` reserved 404 |
| Prompts | Server-side, ported character-for-character from SessionViewModel.swift |
| Providers | Gemini (responseSchema + parts-concat + repair ladder from spike 002) and Anthropic (json_schema constrained decoding) — swappable per operation via `MODEL_SESSION_PLAN` / `MODEL_VERDICT` vars |
| Abuse/cost | DeviceMeterDO (6 calls/10 min sliding window, 20 sessions/day/device) + SpendCapDO (1500 calls/day global hard stop) — Durable Objects, SQLite class |
| Freemium hook | ISO-week session counter per device, readable via `X-Weekly-Sessions`; `weekly_meter_exhausted` code reserved, never returned this phase |
| Error contract | `bad_request` 400 · `rate_limited` 429 · `spend_cap` 429 · `upstream_error` 502 · `not_found` 404 — unified `{error:{code,message}}` envelope |
| Privacy | Single log call site; SHA-256-hashed device ids; allowlisted fields; dilemma text provably absent (sentinel test + live log inspection) |
| Tooling | `npm test` (36 tests) · `npm run dev` · `npm run test:live` (env-gated smoke) · `npm run bake-off` (20 dilemmas × 5 model/op combos, needs keys) |

Commits: `deb451c` plans · `2d1e4c3` scaffold/adapters · `bb759f0` DOs/router · `7ea8e88` bake-off · (this report + summaries follow).

## Test evidence

- **Offline suite:** 36/36 green inside workerd (`vitest` + pool-workers): spike-fixture replay incl. the ~40% truncation failure mode repaired, multi-part concat, fence strip, error-envelope mapping, all five error codes, meter behavior incl. ISO-week year-boundary math, privacy sentinels.
- **`tsc --noEmit`** clean; **`wrangler deploy --dry-run`** validates config, vars, DO bindings + migrations without an account.
- **Live-local simulation (wrangler dev, real HTTP, real DOs, real Google endpoint):** bad_request (no/malformed device id, oversized scenario), not_found (guides), upstream_error with the genuine Google error envelope (placeholder key → "API key not valid" → 502), rate limiter live (6 through, 7th/8th 429, other device unaffected), logs hash-only with zero dilemma text.
- **iOS Simulator flows (screenshots in session):** yes/no session, binary session ("Spanish"/"German" buttons), full AI verdict render, **no-key fallback** ("Berlin or Austin" parsed offline into labeled buttons + bank questions — REQ-006 never-dead-ends), Logs tab stats/history intact.

## Notable findings

1. **The spike-era Gemini key is still ACTIVE** (it produced a live AI verdict from the simulator during testing). It was still sitting in the simulator's UserDefaults from earlier work; I removed it there. **Rotate/delete it in aistudio.google.com when creating the fresh key.**
2. `@cloudflare/vitest-pool-workers` 0.18 (vitest 4) changed APIs (plugin-style config, `fetchMock` and `SELF` gone) — handled with the package's own migration patterns; documented in 01-01-SUMMARY.
3. For Phase 3.5: consider counting weekly sessions after upstream success (currently counted when allowed, per plan), so an outage can't consume free sessions.
4. The vitest [SUS] package flag was self-verified as a false positive (official repo/maintainers via npm registry) under the no-blocking directive.

## Operator runbook to go live (~5 min, in your terminal, from `proxy/`)

1. `npx wrangler login`
2. New key at aistudio.google.com (delete the old one there too)
3. `npx wrangler secret put GEMINI_API_KEY`
4. `npx wrangler deploy`
5. `GORDIAN_LIVE=1 BASE_URL=<printed workers.dev URL> node scripts/live-check.mjs`

Deferred decisions recorded (not built): custom domain before Phase 3; App Attest hardening post-launch (tier hook in place); ANTHROPIC_API_KEY + bake-off whenever wanted.
