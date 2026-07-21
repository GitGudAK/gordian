# Plan 01-01 Summary — Scaffold, prompts, provider adapters

**Status:** Complete · commit `2d1e4c3` · 2026-07-20

## File inventory
`proxy/`: package.json, package-lock.json, wrangler.jsonc, tsconfig.json, vitest.config.ts, .gitignore, src/operations.ts, src/env.d.ts, src/providers/{types,gemini,anthropic}.ts, test/gemini.test.ts, test/helpers/fetch-mock.ts, test/fixtures/{response-questions,response-verdict,response-error,response-truncated}.json

## Key facts
- Zero runtime dependencies; devDeps: wrangler 4.112.0, vitest 4.1.10, @cloudflare/vitest-pool-workers 0.18.6, typescript 5.9.
- Prompts ported character-for-character from SessionViewModel.swift; sentinel greps pass ("rapid gut-instinct bypass", "None (User was silent during rapid-fire)").
- Gemini adapter: x-goog-api-key header (no ?key=), responseSchema mandatory, all-parts concat, bracket-repair ladder — fixture-replayed 15 tests incl. synthetic truncated-object fixture.
- Anthropic adapter: output_config.format json_schema + max_tokens 1024, mock-verified.
- src relative imports use explicit `.ts` extensions so Node ≥22 type-stripping can import the production adapters (bake-off requirement).

## Deviations (mechanical, forced by dep reality)
1. **Package-gate self-verified:** slopcheck's [SUS] flag on vitest confirmed a false positive via `npm view` (repo vitest-dev/vitest, published 2021-12, maintainers incl. antfu/yyx990803). Approved under the user's standing "don't block on me" directive of 2026-07-20; recorded here in lieu of the interactive checkpoint.
2. **pool-workers 0.18 API:** `defineWorkersConfig`/`@cloudflare/vitest-pool-workers/config` no longer exist → vitest.config uses the `cloudflareTest()` Vite plugin (the package's own v3→v4 codemod target shape).
3. **fetchMock removed in 0.18** → test/helpers/fetch-mock.ts stubs globalThis.fetch (worker runs in the same isolate as tests; direct-dispatch pattern below).
4. Tests dispatch the handler directly (`worker.fetch(req, env, ctx)`) instead of deprecated `SELF` so the fetch stub reaches the adapters; a dummy `GEMINI_API_KEY: "test-key"` is injected via `miniflare.bindings` in vitest.config (secrets are never in wrangler.jsonc).

GEMINI_API_KEY (real) and deploy are deferred to plan 01-03 (operator steps).
