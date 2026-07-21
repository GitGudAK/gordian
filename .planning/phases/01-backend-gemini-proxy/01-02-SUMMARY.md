# Plan 01-02 Summary — DO meters, router, validation, privacy logging

**Status:** Complete · commit `bb759f0` · 2026-07-20

## Built
- `src/do/deviceMeter.ts` — DeviceMeterDO (SQLite class): sliding-window rate limit (RATE_LIMIT_CALLS=6 / RATE_LIMIT_WINDOW_MIN=10), per-UTC-day session cap (DEVICE_DAILY_SESSIONS=20), ISO-week counter `sessions:YYYY-Www` incremented only on allowed session-plan calls; `tier` field ("uuid") as the App Attest forward hook. Pure `isoWeekKey()` helper with year-boundary tests.
- `src/do/spendCap.ts` — SpendCapDO singleton: date-keyed `calls:YYYY-MM-DD` counter, hard stop at DAILY_CALL_CAP=1500.
- `src/validate.ts` — UUID device id; body ≤16 KB; scenario ≤ MAX_SCENARIO_CHARS=500; answers ≤20 × (question ≤200, choice ≤50, reflection ≤500).
- `src/log.ts` — single console site; SHA-256-hashed device (12 hex chars); allowlist {ts,op,device,provider,model,latency_ms,outcome}. Sentinel privacy test green; the word "scenario" does not appear in the file.
- `src/index.ts` — router with the unified envelope; codes bad_request(400)/rate_limited(429)/spend_cap(429)/upstream_error(502)/not_found(404); weekly_meter_exhausted defined in types.ts only (grep-verified absent from index.ts). X-Weekly-Sessions header on session-plan success. /v1/guides reserved 404.
- `test/{endpoints,meters}.test.ts` (21 tests) + `scripts/live-check.mjs` (env-gated; SKIPPED/exit 0 offline).

## Verification
36/36 tests green in workerd · tsc clean · `wrangler deploy --dry-run` OK (DO bindings + migrations valid) · live-check skip OK. Live wrangler-dev simulation additionally proved bad_request/not_found/upstream_error/rate_limited over real HTTP with the real Google error envelope (placeholder key) and confirmed zero dilemma text in server logs.

## Deviations
- Meter tests prefill DO state via `runInDurableObject` + use per-test device ids instead of overriding limit vars (0.18 dropped per-test isolated storage; prefill is order-independent). Spend-cap test restores the singleton counter afterward.

## Note for Phase 3.5 (design refinement, not a bug)
The weekly session counter increments on *allowed* session-plan calls, per plan — including ones whose upstream call then fails. When the freemium meter starts enforcing, consider counting after upstream success so an outage can't consume free sessions.
