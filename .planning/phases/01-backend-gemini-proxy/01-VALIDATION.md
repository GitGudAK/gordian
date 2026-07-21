---
phase: 1
slug: backend-gemini-proxy
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-20
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | vitest + @cloudflare/vitest-pool-workers (devDependencies only; Wave 0/scaffold task installs) |
| **Config file** | `proxy/vitest.config.ts` (created by scaffold task) |
| **Quick run command** | `cd proxy && npx vitest run` |
| **Full suite command** | `cd proxy && npx tsc --noEmit && npx vitest run && npx wrangler deploy --dry-run` |
| **Estimated runtime** | ~20 seconds (no network; live checks are env-gated and excluded) |

---

## Sampling Rate

- **After every task commit:** Run `cd proxy && npx vitest run`
- **After every plan wave:** Run the full suite command
- **Before `/gsd:verify-work`:** Full suite must be green; deployed-URL curl smoke (01-02 Task 3) must have returned the asserted status/fields
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| scaffold + adapters | 01-01 | 1 | REQ-001, REQ-005 | key-leak | No key material in repo; `.dev.vars` gitignored | unit (fixture replay incl. truncated-array repair) | `cd proxy && npx vitest run gemini.test.ts` | after task | pending |
| DOs + router | 01-01/B | 2 | REQ-002, REQ-006 | abuse/cost | rate_limited / spend_cap / bad_request codes enforced; no dilemma text in logs (sentinel test) | unit + integration (workers pool) | `cd proxy && npx vitest run endpoints.test.ts meters.test.ts` | after task | pending |
| bake-off script | 01-02 | 3 | REQ-001 | — | Skips cleanly without keys | script self-check | `cd proxy && npx tsx scripts/bakeoff.ts --dry` | after task | pending |
| secrets checkpoint | 01-02 | 3 | REQ-001 | key-handling | Operator-only `wrangler secret put`; Claude never sees value | human-action | n/a (checkpoint) | n/a | pending |
| deploy + smoke | 01-02 | 3 | REQ-001, REQ-006 | — | Both endpoints return schema-valid JSON on workers.dev; error codes live-proven | curl assertions | per-plan Task 3 acceptance criteria | after task | pending |

Notes: privacy sentinel = a request containing a marker string must never appear in captured logs. Week-rollover behavior of the ISO-week counter covered in meters.test.ts.
