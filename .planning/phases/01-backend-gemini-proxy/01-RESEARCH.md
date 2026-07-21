# Phase 1: Backend Gemini Proxy - Research

**Researched:** 2026-07-20
**Domain:** Serverless LLM proxy (Cloudflare Workers), anonymous device rate limiting, Gemini/Anthropic structured output
**Confidence:** HIGH (platform facts and API contracts verified against official docs today; attestation flow MEDIUM)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Access model (locked)**
- No user accounts; anonymous devices authenticate with App Attest/DeviceCheck (REQ-002).
- User dilemma text passes through to Gemini but is NEVER persisted server-side (REQ-003 privacy story: logs must not contain dilemma content).

**Gemini contract (locked, from spike 002)**
- Every structured call sets `responseSchema` (ARRAY-of-STRING for question lists; OBJECT {sentiment, analysis, probe} for verdict) and `responseMimeType: application/json` (REQ-005).
- All response `parts` concatenated; bracket-repair before failure; structured error to the client so it can fall back locally (REQ-005/006).
- Model `gemini-3.5-flash` (thinking model, ~7s/call); model name configurable server-side without an app release.

**Cost & abuse (locked intent, details Claude's discretion)**
- Per-device rate limits sized to the product (a session ≈ 3 calls); hard daily global spend cap; input length caps on dilemma text.
- When a cap is hit, return a distinct error code the app maps to its local-fallback ladder.

**Business hooks (locked, from b2c-strategy 2026-07-20)**
- Proxy counts AI sessions per device — Phase 3.5's freemium meter (3 AI sessions/week free) reads this count. Design the counter now even if the meter enforces later.
- Model must be swappable server-side per operation (bake-off: Gemini flash vs Claude Haiku 4.5; hybrid Haiku-questions/Sonnet-verdict is on the table). Endpoints are operation-shaped, not model-shaped.
- Future: serves `guides.json` (remote guide content for new-guide notifications). Reserve the route; content can come later.

### Claude's Discretion
- Hosting platform, language/framework, storage for rate-limit counters, exact limit numbers, App Attest verification implementation details, deployment pipeline. Bias: smallest respectable option; ~7s upstream calls must fit platform timeout limits.

### Deferred Ideas (OUT OF SCOPE)
- Streaming responses to shave perceived latency (evaluate after v1).
- Freemium/quota tiers (product direction chose flat free access for v1).
- iOS client integration — Phase 3.
</user_constraints>

> **Scope correction from orchestrator (2026-07-20):** CONTEXT.md says "three generation operations," but the clarifying-questions operation was removed from the app. Only TWO operations are live: **generate-session-plan** (classification `{mode, optionA, optionB, questions[≈12]}`) and **generate-verdict** (`{decision, sentiment, analysis, probe}`). A session ≈ **2 upstream calls**, not 3. Plans should build two operation endpoints (+ reserved `guides.json` route); do NOT build a clarifying-questions endpoint.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-001 | AI features work with zero user setup; first-party proxy holds the Gemini key | Hosting recommendation (Cloudflare Workers free plan), secrets via `wrangler secret put`, operation-shaped endpoints with prompts server-side |
| REQ-002 | No accounts; anonymous device attestation for rate limiting | Phased attestation design (launch: opaque device UUID + Durable Object limits + global cap; harden: App Attest), verified App Attest server flow |
| REQ-005 | Every structured call sets `responseSchema` + concatenates all `parts`; repair + fallback ladder | Spike-proven generateContent wire contract re-homed server-side; Gemini adapter section carries the exact schema and repair ladder; Anthropic adapter gets guaranteed-valid JSON via `output_config.format` |
| REQ-006 | ~7s loading states; sessions never dead-end on API failure | Workers has no wall-clock limit (await time is CPU-free — verified); distinct machine-readable error codes (`RATE_LIMITED`, `SPEND_CAP`, `UPSTREAM_ERROR`, `BAD_INPUT`) map to the app's local-fallback ladder |
</phase_requirements>

## Summary

The proxy should be a **single Cloudflare Worker (TypeScript, zero runtime dependencies)** on the **Workers Free plan**, with **Durable Objects (SQLite backend — available on the free plan)** for per-device counters and the global daily spend cap. The killer platform fact, verified today against Cloudflare's docs: **time spent awaiting `fetch()` does not count against the 10 ms CPU limit, and HTTP-triggered Workers have no duration limit** — the ~7s Gemini thinking-model call is completely comfortable. Fly.io is eliminated (no free tier for new accounts); Deno Deploy and Cloud Run work but bring weaker consistent-counter primitives or container ops overhead. `wrangler dev` runs fine on the Intel Mac (the `@cloudflare/workerd-darwin-64` binary is current, and installed Node v25 satisfies wrangler's `>=22` requirement).

The Gemini wire contract moves server-side unchanged from spike 002: `POST v1beta/models/{model}:generateContent` with `generationConfig.responseSchema` (uppercase OpenAPI-style types), parts concatenation, and the bracket-repair ladder — raw `fetch`, no SDK. The bake-off requirement is satisfied by a tiny provider-adapter interface: the Anthropic adapter uses the Messages API's now-GA structured outputs (`output_config.format` with `type: "json_schema"`), which **guarantees schema-valid JSON via constrained decoding** — verified today; the repair ladder is Gemini-only. Operation→{provider, model} mapping lives in Worker vars so models swap per-operation with a redeploy, never an app release. Verified model IDs: `claude-haiku-4-5` ($1/$5 per MTok) and `claude-sonnet-5` ($3/$15; intro $2/$10 through Aug 2026).

For attestation, the phased approach is defensible and architecturally coherent: **launch with an app-generated opaque device UUID + strict per-device limits + a hard global daily call cap** (worst-case abuse is bounded in dollars by the global cap), then **harden with App Attest post-launch**. Crucially, App Attest can never be the only path — `DCAppAttestService.isSupported` is false on some devices and all simulators, so a non-attested fallback lane with stricter limits must exist anyway; the launch design IS that lane. The verified App Attest server flow (challenge → attestation validation against Apple's App Attestation Root CA → per-request assertions with a monotonic counter) is documented below so the hardening phase is pre-scoped.

**Primary recommendation:** One Cloudflare Worker + two Durable Object classes (per-device meter, global spend cap), two operation endpoints, raw-fetch provider adapters (Gemini now, Anthropic wired for bake-off), secrets via `wrangler secret put`, tests via vitest + `@cloudflare/vitest-pool-workers` replaying spike-002 fixtures.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Gemini/Anthropic API keys | API/Backend (Worker secrets) | — | Keys extractable from any client binary; REQ-001 locked |
| Prompts + responseSchema + repair ladder | API/Backend | iOS client keeps local fallback only | Prompt iteration without app releases (locked); REQ-005 enforcement centralized |
| Session-plan / verdict operations | API/Backend | — | Operation-shaped endpoints (locked); model choice hidden from client |
| Device identity generation | iOS client (Phase 3) | — | App generates/stores opaque UUID (Keychain); proxy only consumes it |
| Rate limiting + session counting | API/Backend (Durable Objects) | — | Must be tamper-proof; freemium meter reads it later |
| Global daily spend cap | API/Backend (singleton Durable Object) | — | Single source of truth; hard stop protects the operator's bill |
| Attestation verification | API/Backend | iOS client produces attestations (Phase 3+) | Server validates against Apple root CA; client can't self-attest |
| Fallback questions/verdict on failure | iOS client (exists today) | — | REQ-006: proxy returns distinct error codes; app degrades locally |
| Dilemma text persistence | NOWHERE | — | REQ-003: pass-through only; logs must never contain it |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Cloudflare Workers runtime (workerd) | current | Hosting; fetch handler | Free plan fits: 100k req/day, awaiting upstream fetch is CPU-free, no duration limit `[VERIFIED: developers.cloudflare.com/workers/platform/limits, 2026-07-20]` |
| `wrangler` | 4.112.0 (published 2026-07-17) | Dev server, deploy, secrets | Official CLI; requires Node ≥22 (machine has v25.7.0) `[VERIFIED: npm registry + official docs + slopcheck OK]` |
| Durable Objects (SQLite backend) | platform feature | Per-device counters, global spend cap | Free plan: 100k requests/day, SQLite-backed only; strongly consistent atomic counters `[VERIFIED: developers.cloudflare.com/durable-objects/platform/pricing, 2026-07-20]` |
| TypeScript + raw `fetch` | TS ~5.x | Provider calls, routing | Zero runtime deps; matches spike-hardened contract; locked bias in CONTEXT |

### Supporting (dev-time only)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `vitest` | 4.1.10 | Test runner | Unit + Worker-integration tests `[VERIFIED: npm registry; slopcheck [SUS] — see audit]` |
| `@cloudflare/vitest-pool-workers` | 0.18.6 | Runs vitest inside workerd; DO testing, `fetchMock` for upstream stubs | All proxy tests `[VERIFIED: npm registry + slopcheck OK]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw fetch handler + tiny router | `hono` 4.12.31 | Nicer routing/middleware, but 2 endpoints don't justify a runtime dep (slopcheck OK if planner prefers it) |
| Raw fetch to Gemini | `@google/genai` 2.12.0 | Official SDK works on Workers but adds a dependency and hides the spike-proven wire contract; rejected `[VERIFIED: npm registry]` |
| Raw fetch to Anthropic | `@anthropic-ai/sdk` 0.112.4 | Same reasoning; Messages API is one POST `[VERIFIED: npm registry]` |
| Durable Objects | Workers KV | KV is eventually consistent (~60s propagation) and free plan allows only **1,000 writes/day** — disqualifying for counters `[VERIFIED: developers.cloudflare.com/workers/platform/pricing, 2026-07-20]` |
| Durable Objects | Upstash Redis | External account + network hop; unnecessary now that DOs are on the free plan |
| Cloudflare Workers | Deno Deploy | Free: 1M req/month, 50ms CPU avg; viable, but counters would ride on Deno KV and local-dev/testing story here is Workers-proven `[VERIFIED: docs.deno.com via search, 2026-07-20]` |
| Cloudflare Workers | Google Cloud Run | Free: 2M req/month, 180k vCPU-s; but container builds, cold starts, gcloud ops, and no built-in consistent KV — heavier than needed `[VERIFIED: cloud.google.com/run/pricing via search, 2026-07-20]` |
| Cloudflare Workers | Fly.io | **Eliminated** — free tier discontinued for new accounts; pay-as-you-go ~$2+/mo minimum practical `[VERIFIED: fly.io/docs + community, 2026-07-20]` |

**Installation (dev deps only; runtime has zero deps):**
```bash
npm create cloudflare@latest proxy -- --type hello-world --ts   # or: npm i -D wrangler typescript
npm i -D vitest @cloudflare/vitest-pool-workers
```

**Version verification performed 2026-07-20:** `npm view wrangler version` → 4.112.0; `@cloudflare/workerd-darwin-64` → 1.20260721.1 (Intel Mac binary actively published); `vitest` → 4.1.10; `@cloudflare/vitest-pool-workers` → 0.18.6; `hono` → 4.12.31; `@google/genai` → 2.12.0; `@anthropic-ai/sdk` → 0.112.4.

## Package Legitimacy Audit

slopcheck 0.6.1 run 2026-07-20 with `--ecosystem npm`:

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| wrangler | npm | since 2020 (v4 line current) | very high | github.com/cloudflare/workers-sdk | [OK] | Approved (dev dep) |
| @cloudflare/vitest-pool-workers | npm | 2024+ | high | github.com/cloudflare/workers-sdk | [OK] | Approved (dev dep) |
| vitest | npm | since 2021-12-03 | very high | github.com/vitest-dev/vitest | [SUS] "close to 'vite'" | Flagged — assessed false positive (official Vite-family test framework, same org ecosystem, 4-year history, repo verified via `npm view`); planner may add a `checkpoint:human-verify` before install per protocol |
| hono | npm | mature | high | github.com/honojs/hono | [OK] | Approved but NOT recommended (unnecessary dep) |
| @google/genai | npm | official Google | high | googleapis org | [OK] | Approved but NOT used (raw fetch preferred) |
| @anthropic-ai/sdk | npm | official Anthropic | high | anthropics org | [OK] | Approved but NOT used (raw fetch preferred) |

**Packages removed due to slopcheck [SLOP] verdict:** none (an earlier run flagged 4 SLOP but that was slopcheck auto-detecting the wrong ecosystem — PyPI; the npm-forced run above is authoritative)
**Packages flagged as suspicious [SUS]:** `vitest` (typosquat-proximity heuristic; provenance independently verified — repo `vitest-dev/vitest`, created 2021-12-03, `npm view` confirmed)
**postinstall check:** `npm view wrangler scripts.postinstall` → none.

## Architecture Patterns

### System Architecture Diagram

```
iOS app (Phase 3)                        Cloudflare Worker (this phase)
┌──────────────┐   POST /v1/session-plan  ┌─────────────────────────────┐
│ SessionVM    │ ───────────────────────► │ Router / input validation    │
│ (fallback    │   POST /v1/verdict       │  (length caps, JSON shape)   │
│  ladder kept)│ ◄─── unified JSON ─────  └──────┬───────────────┬──────┘
└──────────────┘      or {error:{code}}          │               │
        ▲                                        ▼               ▼
        │                             ┌─────────────────┐ ┌──────────────┐
   distinct error codes               │ DeviceMeterDO   │ │ SpendCapDO   │
   → local fallback                   │ (per device ID) │ │ (singleton,  │
                                      │ rate limits +   │ │ date-keyed   │
                                      │ weekly session  │ │ global call  │
                                      │ counter         │ │ counter)     │
                                      └─────────────────┘ └──────────────┘
                                                 │ allowed?
                                                 ▼
                                      ┌─────────────────────────────┐
                                      │ Provider adapter (per-op    │
                                      │ config: provider + model)   │
                                      ├──────────────┬──────────────┤
                                      │ GeminiAdapter│AnthropicAdapt│
                                      │ responseSchema│output_config │
                                      │ parts concat │ (guaranteed  │
                                      │ repair ladder│  valid JSON) │
                                      └──────┬───────┴──────┬───────┘
                                        ~7s  ▼              ▼
                              generativelanguage      api.anthropic.com
                              .googleapis.com          /v1/messages
                              v1beta …:generateContent
```

Reserved route: `GET /v1/guides` → serves static `guides.json` (stub returning `{guides: []}` now; content later).

### Recommended Project Structure
```
proxy/
├── wrangler.jsonc            # bindings: DOs, vars (OP_CONFIG), routes
├── src/
│   ├── index.ts              # fetch handler + router + error envelope
│   ├── operations.ts         # prompts + response schemas for the 2 ops (moved from SessionViewModel.swift)
│   ├── providers/
│   │   ├── types.ts          # Provider interface + OperationConfig
│   │   ├── gemini.ts         # generateContent + parts concat + repair ladder
│   │   └── anthropic.ts      # messages + output_config json_schema
│   ├── do/
│   │   ├── deviceMeter.ts    # per-device DO: rate limit + weekly session counter
│   │   └── spendCap.ts       # singleton DO: date-keyed global call counter
│   └── validate.ts           # input caps, device-ID shape check
├── test/
│   ├── fixtures/             # copied from .planning/spikes/002-gemini-swift-client/fixtures/
│   │   ├── response-questions.json
│   │   ├── response-verdict.json
│   │   └── response-error.json
│   ├── gemini.test.ts        # repair ladder, parts concat, error envelope
│   ├── endpoints.test.ts     # routing, caps, error codes (fetchMock upstream)
│   └── meters.test.ts        # DO counter semantics, week rollover, cap trip
├── scripts/
│   └── live-check.mjs        # opt-in live Gemini integration check (env-gated)
├── .dev.vars                 # local secrets — gitignored
└── package.json
```

### Pattern 1: Operation-shaped endpoint with unified error envelope
**What:** `POST /v1/session-plan {deviceId, scenario}` → `{mode, optionA, optionB, questions[]}`; `POST /v1/verdict {deviceId, scenario, answers[]}` → `{decision, sentiment, analysis, probe}`. All failures return `{error: {code, message}}` with machine-readable codes.
**When to use:** Every response. The app's degradation ladder (REQ-006) keys off `code`.
**Codes:** `RATE_LIMITED` (per-device), `SPEND_CAP` (global daily), `BAD_INPUT` (length/shape), `UPSTREAM_ERROR` (provider failed after repair ladder), `UNSUPPORTED_CLIENT` (future attestation tier). Distinct cap codes are a locked decision.

### Pattern 2: Provider adapter (see dedicated section below)

### Pattern 3: Durable Object per device, addressed by name
**What:** `env.DEVICE_METER.idFromName(deviceId)` → one strongly consistent object per device holding a short-window rate limit and a week-keyed session counter.
**Example:**
```typescript
// Source: developers.cloudflare.com/durable-objects (pattern), verified free-plan availability 2026-07-20
export class DeviceMeterDO extends DurableObject {
  async checkAndCount(op: "session-plan" | "verdict"): Promise<MeterResult> {
    const now = Date.now();
    // sliding-window rate limit (e.g. max 6 upstream calls / 10 min)
    // week-keyed session counter: "sessions:2026-W30" — increment ONLY on session-plan
    // returns { allowed, weeklySessions } — Phase 3.5 freemium meter reads weeklySessions
  }
}
```
**Session semantics:** a "session" increments on `session-plan` calls only; `verdict` is rate-limited but does not start a new session. Week key = ISO week (`YYYY-Www`) so the Phase 3.5 "3 AI sessions/week" meter reads the same counter without migration.

### Pattern 4: Date-keyed global cap (no alarms needed)
**What:** Singleton `SpendCapDO` (`idFromName("global")`) increments a counter under key `calls:YYYY-MM-DD`. When the day changes, the new key starts at zero — no alarm/reset job, no timezone bugs (use UTC).
**Why count calls, not dollars:** per-call cost is sub-cent and roughly constant; a call-count cap (recommend launch value: **1,500 upstream calls/day ≈ 750 sessions/day, comfortably under $5/day** `[ASSUMED: cost estimate from b2c note "session <$0.01"]`) avoids a dependency on token-price math. Expose the cap as a Worker var so it's tunable per deploy.

### Anti-Patterns to Avoid
- **KV as a rate-limit store:** eventually consistent + 1,000 writes/day free — both disqualifying. `[VERIFIED]`
- **Cloudflare's Rate Limiting binding as the meter:** it is per-colo, "intentionally... not... an accurate accounting system," and supports only 10s/60s windows. Acceptable as an optional extra burst shield in front of the DO, never as the session counter. `[VERIFIED: developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit, 2026-07-20]`
- **API key in the query string** (`?key=...` as the spike/client code does): moves into request logs and URL handling. Server-side, send Gemini the `x-goog-api-key` header instead — same auth, keeps the key out of URLs. `[CITED: ai.google.dev API docs convention]`
- **Logging request bodies:** any `console.log` of scenario/answers violates REQ-003. Log only: op, hashed device ID, provider, latency, outcome code, token counts.
- **A clarifying-questions endpoint:** removed from the app; do not build (orchestrator scope correction).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Schema-valid JSON from Gemini | Prompt-only "return JSON" + custom parsing | `generationConfig.responseSchema` + spike repair ladder | ~40% truncated JSON without schema on this thinking model (spike 002, live-verified) |
| Schema-valid JSON from Claude | Repair ladders for Anthropic | `output_config.format` `json_schema` — constrained decoding guarantees validity | Verified GA 2026-07-20; no beta header needed |
| Consistent per-device counters | KV read-modify-write, external Redis | Durable Object per device | Atomic, strongly consistent, free plan |
| Attestation crypto (hardening phase) | Custom X.509/CBOR/ECDSA parsing | WebCrypto for signature verify + an audited X.509/CBOR lib (selected in hardening phase) | Certificate-chain validation is a classic hand-roll disaster domain |
| Daily counter resets | Cron/alarm reset jobs | Date-keyed counter keys | New day = new key; zero reset machinery |
| Local dev server | Custom Node harness | `wrangler dev` (embedded miniflare/workerd) | Exact production runtime incl. DOs, on Intel Mac |

**Key insight:** the only genuinely fiddly logic the proxy must own is the Gemini repair ladder — and that is already written and battle-tested in `ios/Gordian/GeminiClient.swift` (`cleanJSONText` + bracket repair). Port it line-for-line to TypeScript; do not redesign it.

## Hosting Recommendation

**Use Cloudflare Workers, Free plan.**

| | Cloudflare Workers (free) | Deno Deploy (free) | Google Cloud Run (free) | Fly.io |
|---|---|---|---|---|
| Requests | 100,000/day | 1M/month (~33k/day) | 2M/month | — no free tier (new accounts) |
| CPU limit | 10 ms/req — **await time excluded** | 50 ms/req (avg-enforced) | 180k vCPU-s/month | — |
| ~7s upstream call | **No duration limit; explicitly fine** | Fine (CPU-based) | Fine (but billed while waiting w/ instance-based billing; request-based OK) | — |
| Consistent counter store | **Durable Objects (SQLite) on free plan, 100k req/day** | Deno KV (1 GiB, atomic ops) | None built-in (need Firestore/Redis) | — |
| Cold starts | ~0 (isolates) | Low | Container cold starts (seconds) | — |
| Secrets | `wrangler secret put`, encrypted, write-only | Dashboard/env | Secret Manager | — |
| Domains | free `*.workers.dev`; custom domain needs a CF zone | free subdomain + 50 custom | run.app URL / domain mapping | — |
| Intel Mac local dev | **`wrangler dev` — `workerd-darwin-64` binary current (v1.20260721.1)** | `deno` CLI (works) | Docker required | — |
| All facts | `[VERIFIED 2026-07-20]` | `[VERIFIED 2026-07-20]` | `[VERIFIED 2026-07-20]` | `[VERIFIED 2026-07-20]` |

**Rationale:** Workers is the only option combining (a) confirmed comfort with 7s upstream awaits on the free tier, (b) a free strongly consistent counter primitive (DOs), (c) near-zero cold starts for a latency-sensitive consumer flow, and (d) a proven Intel-Mac local dev story. 100k req/day ceiling is ~50,000 sessions/day — orders of magnitude above launch needs; the paid plan ($5/mo) is the escape hatch, not a migration.

**Domain note:** launch on `gordian-proxy.<account>.workers.dev` is acceptable for v1, but the URL gets baked into the shipped binary in Phase 3. A custom domain (requires a domain on a Cloudflare zone, ~$10/yr) is cheap insurance against `workers.dev` blocking by some network filters. Recommend acquiring before Phase 3 ships — flagged in Open Questions.

**Account prerequisite:** a Cloudflare account (free) is required; creation + first `wrangler login` is an operator step (see Secrets & Local-Dev Workflow).

## Rate-Limit / Counter Storage Design

Two Durable Object classes (both SQLite-backed, free plan):

1. **`DeviceMeterDO`** — one per device (`idFromName(deviceId)`):
   - Sliding-window rate limit. Recommended launch numbers (Claude's discretion, tunable via vars): max **6 upstream calls / 10 minutes** and **20 sessions/day** per device — generous for real use (a session = 2 calls), hostile to scripted abuse.
   - **Weekly AI-session counter** keyed `sessions:YYYY-Www` (ISO week, UTC): incremented on successful `session-plan` calls only. This is the exact counter Phase 3.5's freemium meter (3/week) will read — design it now, enforce nothing yet (flat free access is locked for v1).
   - Input to future attestation tiers: store `tier: "uuid" | "attested"` per device; limits can differ by tier later without schema change.
2. **`SpendCapDO`** — singleton (`idFromName("global")`): date-keyed upstream-call counter, hard stop at `DAILY_CALL_CAP` (recommend 1,500; var-configurable). On trip: return `{error: {code: "SPEND_CAP"}}` — the app falls back locally and the session still completes (REQ-006).
   - Scale note: a singleton DO serializes all requests; fine for ≤100k/day launch scale, shard by hour-bucket if ever needed.

**Request flow:** validate input → `DeviceMeterDO.checkAndCount()` → `SpendCapDO.increment()` → provider call. Two DO subrequests + one upstream fetch = 3 of the 50-subrequest budget. DO free tier (100k req/day) is consumed at 2 DO hits per API call → ceiling ~50k API calls/day, still far above need.

**Input caps (BAD_INPUT):** scenario ≤ 2,000 chars; answers array ≤ 20 items, each reflection ≤ 500 chars; total body ≤ 16 KB. `[ASSUMED: sized from the app's actual payloads — SessionViewModel sends ≤12 Q&A lines]`

## Attestation Phased Approach

**Validated recommendation: launch with opaque device UUID + strict limits; harden with App Attest post-launch.** This is defensible because:

1. **The blast radius is bounded in dollars, not hope.** Even a fully scripted attacker who mints unlimited UUIDs cannot exceed the global daily call cap (~$5/day worst case). Per-device limits stop casual abuse; the global cap stops determined abuse.
2. **A non-attested lane must exist forever anyway.** `DCAppAttestService.isSupported` is false on simulators and some devices — Apple's own guidance requires a fallback path. The launch design IS the permanent fallback lane; App Attest later upgrades trusted devices to (potentially) looser limits. `[CITED: developer.apple.com/documentation/devicecheck — establishing-your-app-s-integrity]`
3. **The API key is never at risk** — the attack surface is quota theft only, and stolen quota degrades gracefully into the app's local fallback.

**Launch (this phase):** app sends `X-Device-Id: <UUID>` (Phase 3 generates and Keychain-persists it; this phase just validates UUID shape and meters on it). Honeypot posture: log (metadata only) devices that hit limits repeatedly; the 2-bit DeviceCheck flag or a DO denylist can absorb them later.

**Harden (post-launch phase), the verified App Attest server flow** `[MEDIUM confidence: Apple doc page did not render for direct citation; flow cross-verified across multiple independent implementation guides — a-sit-plus.github.io/warden-supreme, fractal-dev.com, blog.restlesslabs.com, 2026-07-20]`:

1. **Challenge:** server issues a one-time random challenge (new endpoint, short TTL, stored in a DO).
2. **Attestation (once per device):** app calls `attestKey`; server validates the CBOR attestation object:
   - Verify certificate chain to the **Apple App Attestation Root CA** — PEM at `https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem` `[VERIFIED: HTTP 200, 2026-07-20]`; pin to this root only.
   - Reconstruct nonce = `SHA256(authenticatorData || SHA256(challenge))`; match against the leaf-cert extension.
   - `SHA256(publicKey)` must equal the client-supplied key ID; App ID hash (`teamID.bundleID`) must match RP ID in authenticator data; counter = 0 initially; `aaguid` = `appattest` (prod) vs `appattest-develop`.
   - Store the public key + counter against the device in its `DeviceMeterDO`.
3. **Assertions (per request or per session):** app signs `SHA256(clientData)`; server verifies signature with stored public key (WebCrypto ECDSA P-256 — native, cheap) and enforces a **strictly increasing counter**.
4. **Workers feasibility:** signature verification is WebCrypto-native; CBOR + X.509 parsing needs a library (candidates exist on npm — selection deferred to the hardening phase and MUST pass the package legitimacy gate then; `[ASSUMED]` that a suitable audited lib exists — several implementations are documented). CPU cost is dominated by native crypto, not JS — the 10 ms budget should hold; measure during hardening.

**DeviceCheck middle option:** validating a device token via `api.devicecheck.apple.com` (JWT auth: ES256-signed with a `.p8` key, key ID + team ID) proves "real Apple hardware" with far less crypto than App Attest, plus 2 bits of per-device server-set state for flagging abusers. Requires Apple Developer account keys. Reasonable intermediate hardening step if App Attest is deprioritized. `[ASSUMED: endpoint/auth shape from training + secondary sources; verify against Apple docs in hardening phase]`

**Design-now hook:** requests carry `X-Device-Id` (+ future `X-Attest-Assertion`); the router resolves an attestation tier and passes it to `DeviceMeterDO`. That's the entire forward-compatibility surface this phase needs.

## Provider Adapter Design

Endpoints are operation-shaped (locked). Internally, one interface, two adapters:

```typescript
// providers/types.ts
interface StructuredRequest {
  system: string;
  user: string;
  schema: OperationSchema;   // canonical JSON-Schema-ish description, translated per provider
  temperature: number;
  maxTokens: number;
}
interface Provider {
  generateStructured(req: StructuredRequest, env: Env): Promise<string>; // returns JSON text
}
// Worker var (JSON), swap models per-operation with a redeploy — no app release:
// OP_CONFIG = {"session-plan": {"provider":"gemini","model":"gemini-3.5-flash"},
//              "verdict":      {"provider":"gemini","model":"gemini-3.5-flash"}}
// Bake-off flip: {"provider":"anthropic","model":"claude-haiku-4-5"} etc.
```

**Gemini adapter** (spike-proven contract, live-verified 2026-07-20 — HIGH confidence):
```
POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
Header: x-goog-api-key: {GEMINI_API_KEY}          // header, not ?key= query param
Body: {
  "systemInstruction": {"parts": [{"text": system}]},
  "contents": [{"parts": [{"text": user}]}],
  "generationConfig": {
    "temperature": 0.8,
    "responseMimeType": "application/json",
    "responseSchema": {                            // uppercase OpenAPI-style types
      "type": "OBJECT",
      "properties": {
        "mode": {"type": "STRING"}, "optionA": {"type": "STRING"},
        "optionB": {"type": "STRING"},
        "questions": {"type": "ARRAY", "items": {"type": "STRING"}}
      },
      "required": ["mode","optionA","optionB","questions"]
    }
  }
}
→ concatenate ALL candidates[0].content.parts[].text (never parts[0] alone)
→ repair ladder: strip ``` fences → trim trailing comma → append missing "]"/"}" → parse
→ on failure: {error:{code:"UPSTREAM_ERROR"}}; non-2xx decodes as {"error":{code,message,status}}
```
Verdict schema: `OBJECT {decision, sentiment, analysis, probe}` all STRING, all required — exactly the payloads in `SessionViewModel.swift`. The two system prompts move verbatim from `SessionViewModel.swift` (`generateBypassQuestionsAndStart` and `evaluateFullSessionAndLog`) into `operations.ts`.

**Anthropic adapter** `[VERIFIED: platform.claude.com/docs structured-outputs + models overview, 2026-07-20]`:
```
POST https://api.anthropic.com/v1/messages
Headers: x-api-key: {ANTHROPIC_API_KEY}, anthropic-version: 2023-06-01
Body: {
  "model": "claude-haiku-4-5",                    // verified ID; $1/$5 per MTok
  "max_tokens": 1024,                             // REQUIRED by Messages API
  "system": system,
  "messages": [{"role": "user", "content": user}],
  "output_config": {
    "format": {
      "type": "json_schema",
      "schema": {                                  // standard lowercase JSON Schema
        "type": "object",
        "properties": { "mode": {"type":"string"}, ... },
        "required": [...], "additionalProperties": false
      }
    }
  }
}
→ result JSON text in response.content[0].text — GUARANTEED schema-valid (constrained
  decoding, GA, no beta header). No repair ladder needed on this path.
```
Bake-off models, verified: `claude-haiku-4-5` (fastest, $1/$5); hybrid option verdict model `claude-sonnet-5` ($3/$15; intro $2/$10 through 2026-08-31). Hybrid = per-operation OP_CONFIG entries — the design supports it with zero extra code.

**Schema authoring:** two operations × two providers = 4 small hand-written schema constants in `operations.ts`. Do not build a schema translator; keep both dialects side by side (uppercase Gemini OpenAPI-subset, lowercase JSON Schema for Anthropic) and unit-test both against the fixtures.

**Latency note:** `gemini-3.5-flash` thinking runs ~7s/call (spike-measured). Workers' lack of a duration limit makes this a non-issue; iOS client timeout is already 60s. If bake-off latency matters, `thinkingConfig`/reduced thinking budgets are a Gemini knob to explore during the bake-off, not this phase `[ASSUMED: knob exists for flash-class models; verify at bake-off time]`.

## Secrets & Local-Dev Workflow

`[VERIFIED: developers.cloudflare.com/workers/configuration/secrets, 2026-07-20]`

**Operator sets production secrets from their own terminal — never through chat or code** (the spike-era key is compromised and MUST be replaced by a freshly issued key; locked decision):
```bash
npx wrangler login                       # one-time browser OAuth to the CF account
npx wrangler secret put GEMINI_API_KEY   # paste fresh key at the hidden prompt
npx wrangler secret put ANTHROPIC_API_KEY  # when bake-off starts (optional at launch)
```
Secrets are write-only after set (not visible in dashboard/wrangler) and each `secret put` deploys a new version.

**Local dev (Intel Mac — verified viable):** `.dev.vars` in the project root (dotenv syntax), gitignored (`.dev.vars*` in `.gitignore` is mandatory — a leaked dev key is how the last one died):
```
GEMINI_API_KEY="<operator's own local/test key>"
```
`npx wrangler dev` runs the real workerd runtime locally, including Durable Objects. Node ≥22 required (installed: v25.7.0 ✓); `@cloudflare/workerd-darwin-64` Intel binary current as of 2026-07-21 build ✓.

**Deploy pipeline (smallest respectable):** `npx wrangler deploy` from the operator's terminal. CI is unnecessary for a single-file service at this stage; add GitHub Actions with a `CLOUDFLARE_API_TOKEN` repo secret only if desired later.

## Testing Strategy

**Framework:** vitest + `@cloudflare/vitest-pool-workers` — tests execute inside workerd (same runtime as production), with `SELF.fetch()` for endpoint tests, direct DO access for meter tests, and `fetchMock` to stub Gemini/Anthropic upstreams.

**Fixtures:** copy `.planning/spikes/002-gemini-swift-client/fixtures/{response-questions,response-verdict,response-error}.json` (verified present) into `proxy/test/fixtures/` — these are real captured Gemini responses, including the error envelope. Add one synthetic truncated-JSON fixture (missing `]`) to pin the repair ladder, since that ~40% failure mode is the entire reason the ladder exists.

**Test layers:**
1. **Unit (offline, every commit):** repair ladder cases; parts concatenation (multi-part fixture); schema constants match expected payload shapes; error-code mapping; input caps; device-ID validation.
2. **Worker integration (offline):** `SELF.fetch("/v1/session-plan")` with `fetchMock` returning fixtures → assert unified response; DO meter: N calls trip `RATE_LIMITED`; global counter trips `SPEND_CAP`; week-key rollover.
3. **Live smoke (opt-in, operator-run):** `GEMINI_API_KEY=... node scripts/live-check.mjs` (or `npm run test:live`) hits `wrangler dev` against real Gemini with both operations and asserts parseable payloads. Env-gated: skips loudly when the key is absent. This revalidates the model name (`gemini-3.5-flash`, verified live 2026-07-20; fallback `gemini-flash-latest` on 404).
4. **Privacy check:** a test asserting the log-line builder never includes `scenario`/`answers` fields (REQ-003 enforcement as a unit test).

## Common Pitfalls

### Pitfall 1: Treating KV or the Rate Limiting binding as an accurate counter
**What goes wrong:** limits silently under-enforce (eventual consistency, per-colo counters); KV free tier exhausts at 1,000 writes/day.
**How to avoid:** Durable Objects for anything counted; Rate Limiting binding only as an optional extra burst shield.
**Warning signs:** rate-limit tests pass locally but abuse gets through multi-colo traffic.

### Pitfall 2: The Gemini truncation trap re-emerges server-side
**What goes wrong:** the thinking model drops the closing bracket with `finishReason: STOP` (~40% observed without schema); looks like a proxy bug.
**How to avoid:** `responseSchema` on every call (non-negotiable, CLAUDE.md ground rule) AND port the full repair ladder; never read `parts[0]` alone.
**Warning signs:** intermittent `UPSTREAM_ERROR` with valid-looking upstream 200s.

### Pitfall 3: Dilemma text leaks into logs (REQ-003 violation, marketing claim broken)
**What goes wrong:** a debug `console.log(body)` ends up in Workers Logs; "your dilemmas never leave your phone" becomes false.
**How to avoid:** single structured log helper with an allowlist of fields; the privacy unit test above; never enable full request logging in the dashboard.

### Pitfall 4: Gemini docs drift mid-build
**What goes wrong:** ai.google.dev now foregrounds a new Interactions API (`v1beta/interactions`, `response_format`, lowercase types). Following current docs would diverge from the spike-proven contract.
**How to avoid:** the locked contract is `models/{model}:generateContent` + `generationConfig.responseSchema` (uppercase types) — live-verified working today. Do not migrate mid-phase; note Interactions API as a future consideration. `[VERIFIED: docs page shift observed 2026-07-20]`

### Pitfall 5: Anthropic Messages API rejects requests without `max_tokens`
**What goes wrong:** the Gemini adapter has no required max; a naive Anthropic port 400s.
**How to avoid:** `max_tokens` explicit in the adapter (1024 covers both payloads).

### Pitfall 6: Global spend DO reset bugs
**What goes wrong:** alarm-based daily resets fail once and the cap stays tripped (or never trips).
**How to avoid:** date-keyed counters (UTC); no reset machinery to break.

### Pitfall 7: Baking `workers.dev` URL into the shipped app, then wanting a domain
**What goes wrong:** URL changes require an app release — exactly what the proxy exists to avoid.
**How to avoid:** decide the domain before Phase 3 hardcodes it (Open Questions).

### Pitfall 8: Building the third endpoint
**What goes wrong:** CONTEXT.md still says "three operations"; the clarifying-questions op is removed from the app.
**How to avoid:** two endpoints only (`session-plan`, `verdict`) + reserved `guides` route.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js ≥22 | wrangler | ✓ | v25.7.0 | — |
| npm | dev deps | ✓ | 11.10.1 | — |
| wrangler (Intel Mac) | dev/deploy | ✓ (installable; `workerd-darwin-64` 1.20260721.1 published) | 4.112.0 | — |
| Cloudflare account | deploy, DOs, secrets | ✗ unverified (operator step) | — | free signup + `wrangler login`; no fallback needed |
| Fresh Gemini API key | live calls | ✗ operator must issue (spike key compromised) | — | none — blocking for deploy; offline tests unaffected |
| Anthropic API key | bake-off only | ✗ optional this phase | — | defer; adapter ships fetch-tested against mocks |
| Apple Developer .p8 key | DeviceCheck/App Attest hardening | not needed this phase | — | phased design defers it |

**Missing dependencies with no fallback:** fresh Gemini key + Cloudflare account — both are 5-minute operator actions; plan should include a `checkpoint:human-action` for them before the deploy task.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | vitest 4.1.10 + @cloudflare/vitest-pool-workers 0.18.6 |
| Config file | none — Wave 0 (`proxy/vitest.config.ts` with workers pool) |
| Quick run command | `npx vitest run test/gemini.test.ts` |
| Full suite command | `npx vitest run` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-001 | Endpoints serve both ops with server-held key; no key in responses | integration | `npx vitest run test/endpoints.test.ts` | ❌ Wave 0 |
| REQ-002 | Per-device metering; missing/malformed device ID rejected | integration | `npx vitest run test/meters.test.ts` | ❌ Wave 0 |
| REQ-005 | responseSchema on every Gemini call; parts concat; repair ladder | unit | `npx vitest run test/gemini.test.ts` | ❌ Wave 0 |
| REQ-006 | Distinct error codes for caps/upstream failure (app fallback contract) | integration | `npx vitest run test/endpoints.test.ts -t "error codes"` | ❌ Wave 0 |
| REQ-003 (guard) | Log builder never emits dilemma content | unit | `npx vitest run test/endpoints.test.ts -t "privacy"` | ❌ Wave 0 |
| — | Live Gemini smoke (manual-only: needs operator key, costs money) | manual/opt-in | `npm run test:live` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `npx vitest run` (offline suite, seconds)
- **Per wave merge:** full suite + `wrangler dev` boot check
- **Phase gate:** full suite green + operator-run live smoke against deployed Worker

### Wave 0 Gaps
- [ ] `proxy/` scaffold: `package.json`, `wrangler.jsonc`, `vitest.config.ts` (workers pool), `.gitignore` with `.dev.vars*`
- [ ] `proxy/test/fixtures/` — copy 3 spike-002 fixtures + 1 synthetic truncated fixture
- [ ] Framework install: `npm i -D wrangler vitest @cloudflare/vitest-pool-workers typescript`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | partial | Device identity (opaque UUID now; App Attest assertion tier later) — no user auth by design |
| V3 Session Management | no | Stateless per-request; no server sessions |
| V4 Access Control | yes | Per-device DO limits + global cap; tier-aware limits reserved |
| V5 Input Validation | yes | Length caps, JSON shape validation, UUID format check — hand-rolled checks are fine at this size (no dep needed for 2 endpoints) |
| V6 Cryptography | yes (hardening) | WebCrypto only for App Attest verification; never hand-roll chain validation |
| V7 Logging | yes | Allowlisted structured logs; NO dilemma content (REQ-003); hashed device IDs |
| V10 Secrets | yes | Worker secrets (write-only), `.dev.vars` gitignored, fresh key replaces compromised spike key |

### Known Threat Patterns for anonymous LLM proxies

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Quota theft (endpoint scraped from binary, replayed) | Spoofing/DoS | Per-device limits + global daily call cap (dollar-bounded blast radius); App Attest later |
| Device-ID minting (UUID rotation) | Spoofing | Global cap is the backstop; attestation tier upgrade path designed in |
| Prompt injection via dilemma text | Tampering | responseSchema/constrained decoding bounds output shape; prompts are server-side constants; output is parsed, never executed |
| API key standing damage (abusive content to Gemini) | Repudiation | Input length caps; operator can add content filtering later; Gemini-side safety settings remain default |
| Log-based privacy leak | Information disclosure | Allowlist logging + privacy unit test |
| Spend runaway | DoS ($) | Date-keyed SpendCapDO hard stop, distinct `SPEND_CAP` error code |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 1,500 calls/day global cap ≈ well under $5/day (from "session <$0.01") | Rate-limit design | Cap too loose/tight — tunable var, low risk |
| A2 | DeviceCheck server API endpoint/JWT auth shape (`api.devicecheck.apple.com`, ES256 .p8) | Attestation | Hardening-phase rework only; not built this phase |
| A3 | Suitable audited npm lib exists for App Attest CBOR/X.509 on Workers | Attestation | Hardening phase may need more custom WebCrypto work |
| A4 | Gemini `thinkingConfig` latency knob applies to `gemini-3.5-flash` | Provider adapter | Bake-off note only; no phase impact |
| A5 | Input cap numbers (2,000-char scenario etc.) fit all real app payloads | Rate-limit design | 413-style rejections; verify against app payloads in Phase 3 |
| A6 | Cloud Run/Deno free-tier details from search summaries (not chosen platform) | Hosting table | None — rejected alternatives |

## Open Questions (RESOLVED)

1. **Custom domain before Phase 3?** — RESOLVED: deferred to user; workers.dev for this phase, decision recorded in 01-02 deploy notes.
   - What we know: `workers.dev` is free and works; the URL gets baked into shipped binaries; some networks filter `workers.dev`.
   - Recommendation: operator buys a domain onto a Cloudflare zone before Phase 3 hardcodes the URL. Not blocking for this phase.
2. **Exact limit numbers** — RESOLVED: shipped as tunable Worker vars (defaults per recommendation), adopted by plans. (6 calls/10 min, 20 sessions/day, 1,500 global/day) are recommendations under Claude's discretion — expose all as Worker vars so tuning never needs a code change; planner should treat the numbers as defaults, not constants.
3. **Anthropic key at launch or at bake-off?** — RESOLVED: key deferred; adapter ships mock-tested; bake-off task skips cleanly without it. Adapter ships mock-tested either way; the secret can be set whenever the bake-off starts. Recommendation: defer the key, ship the adapter.

## Sources

### Primary (HIGH confidence, all accessed 2026-07-20)
- developers.cloudflare.com/workers/platform/limits — CPU vs wall-clock, 100k req/day, 50 subrequests, await excluded from CPU
- developers.cloudflare.com/workers/platform/pricing — KV free limits (1k writes/day), D1, DO on free plan
- developers.cloudflare.com/durable-objects/platform/pricing — DO free plan: SQLite-only, 100k req/day
- developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit — permissive per-colo semantics, 10s/60s only
- developers.cloudflare.com/workers/configuration/secrets — `wrangler secret put`, `.dev.vars`, write-only secrets
- platform.claude.com/docs/en/build-with-claude/structured-outputs — `output_config.format` json_schema, GA, guaranteed validity
- platform.claude.com/docs/en/about-claude/models/overview — `claude-haiku-4-5`, `claude-sonnet-5` IDs + pricing
- npm registry (`npm view`, 2026-07-20) — wrangler 4.112.0, workerd-darwin-64 1.20260721.1, vitest 4.1.10, vitest-pool-workers 0.18.6, @google/genai 2.12.0, @anthropic-ai/sdk 0.112.4
- https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem — HTTP 200 verified
- Spike 002 (this repo, run 2026-07-20) — Gemini generateContent contract, `gemini-3.5-flash` validity, ~7s latency, 40% truncation without schema; fixtures verified present
- slopcheck 0.6.1 npm audit (2026-07-20)

### Secondary (MEDIUM confidence)
- App Attest server validation flow — cross-verified: a-sit-plus.github.io/warden-supreme/technical/ios, fractal-dev.com (iOS backend security part 3), blog.restlesslabs.com/john/ios-app-attest, adjoe.io engineering blog (Apple's own doc page failed to render; flow matches Apple's documented steps across all sources)
- docs.deno.com pricing (via search summary) — 1M req/mo, 50ms CPU free tier
- cloud.google.com/run/pricing (via search summary) — 2M req/mo, 180k vCPU-s free tier
- fly.io docs + community threads — free tier discontinued for new accounts
- ai.google.dev/gemini-api/docs/structured-output — page now foregrounds Interactions API; generateContent toggle noted (drift documented in Pitfall 4)

### Tertiary (LOW confidence)
- DeviceCheck server API auth details (training knowledge + secondary blogs) — flagged A2

## Metadata

**Confidence breakdown:**
- Hosting/platform limits: HIGH — official Cloudflare docs, fetched today
- Gemini contract: HIGH — live-verified by spike 002 today; docs drift noted
- Anthropic contract: HIGH — official docs fetched today (GA structured outputs, model IDs, pricing)
- Storage/counter design: HIGH — DO free-plan facts verified; design is standard practice
- App Attest flow: MEDIUM — multi-source cross-verified, Apple page unrendered; not built this phase
- Limit numbers / cost math: LOW-MEDIUM — explicitly tunable recommendations

**Research date:** 2026-07-20
**Valid until:** ~2026-08-20 (Cloudflare limits and Anthropic pricing are stable; recheck Sonnet 5 intro pricing after 2026-08-31)
