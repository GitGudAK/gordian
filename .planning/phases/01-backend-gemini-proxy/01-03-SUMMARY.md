# Plan 01-03 Summary — Bake-off tooling, deploy, live smoke

**Status:** COMPLETE · 2026-07-21 — **PHASE 1 DEPLOYED AND LIVE-VERIFIED**

## Deployment record (2026-07-21)
- **URL:** `https://gordian-proxy.gordian-app.workers.dev` (subdomain `gordian-app`)
- Model vars deployed: MODEL_SESSION_PLAN / MODEL_VERDICT = `gemini:gemini-3.5-flash` (no 404 fallback needed)
- GEMINI_API_KEY set write-only by the operator via `wrangler secret put` (fresh key)
- **Live smoke (real Gemini):** session-plan 7.8s — BINARY, Spanish/German, 12 questions, X-Weekly-Sessions=1 · verdict 5.9s — "Learn Spanish." / RESOLVED · live-check.mjs exit 0
- **Error contract on production:** missing device id → 400 bad_request · /v1/guides → 404 not_found · unknown route → 404 not_found · oversized scenario → 400 bad_request
- Gotcha fixed en route: wrangler 4 requires `wrangler deploy` BEFORE `secret put` (Worker must exist)

## Task 1 — done
`proxy/scripts/bake-off.mts` (+ `npm run bake-off`): 20 inline dilemmas (10 BINARY / 10 YES_NO incl. all four app demo scenarios), canned rapid-fire answers, model matrix session-plan {gemini-3.5-flash, claude-haiku-4-5} × verdict {gemini-3.5-flash, claude-haiku-4-5, claude-sonnet-5}, `--limit`/`--models` flags, markdown table to stdout + `scripts/bake-off-results/` (gitignored). Imports the production adapters directly under Node type-stripping. Keyless run prints skip notice and exits 0 (verified).

## Tasks 2–3 — operator runbook (~5 minutes, from `proxy/`)
1. `npx wrangler login` (free Cloudflare account if none). ✅ done 2026-07-21.
2. `npx wrangler deploy` → creates the Worker and prints the workers.dev URL. **Deploy MUST precede secret put** — wrangler 4 errors "Worker not found" otherwise. First deploy prompts you to register a workers.dev subdomain (pick e.g. `gordian`).
3. Create a **fresh** Gemini key at aistudio.google.com — and **delete/rotate the spike-era key there: it is still active** (verified 2026-07-20: the old key stored in the simulator still returned live verdicts).
4. `npx wrangler secret put GEMINI_API_KEY` (paste at hidden prompt; triggers a new deployment with the secret attached).
5. Smoke: `GORDIAN_LIVE=1 BASE_URL=<url> node scripts/live-check.mjs` (expect exit 0; ~7s/call is normal). If the model name 404s, flip both model vars in wrangler.jsonc to `gemini:gemini-flash-latest` and redeploy.
6. Optional (local dev): `proxy/.dev.vars` with `GEMINI_API_KEY="<key>"` (gitignored; a placeholder currently sits there from the offline simulation).
7. Later, for the bake-off: `npx wrangler secret put ANTHROPIC_API_KEY` + export it locally, then `npm run bake-off`.

## Deferral notes (decisions for the user, deliberately not built)
- **Custom domain** before Phase 3 bakes the URL into the app binary — some networks filter workers.dev.
- **App Attest/DeviceCheck hardening** — post-launch phase; DeviceMeterDO already stores the `tier` hook.
- **ANTHROPIC_API_KEY / bake-off** — ready whenever wanted; not launch-blocking.
