---
spike: 002
name: gemini-swift-client
type: standard
validates: "Given a Gemini API key, when generateContent is called from Swift/URLSession with responseMimeType application/json, then 12 bypass questions decode via Codable"
verdict: VALIDATED
related: [001-ios-toolchain-readiness]
tags: [gemini, urlsession, codable, ai]
---

# Spike 002: Gemini Swift Client

## What This Validates
Given a Gemini API key, when the v1beta `generateContent` endpoint is called from Swift URLSession with `responseMimeType: application/json`, then the three structured payloads Gordian depends on (bypass-question array, verdict object, error envelope) decode via Codable — matching the Android Retrofit/Moshi behavior 1:1.

## Research
| Approach | Tool/Library | Pros | Cons | Status |
|----------|-------------|------|------|--------|
| Raw URLSession + Codable | Foundation only | Zero deps, mirrors Android design, compiles with CLT Swift 5.4 today | Hand-rolled DTOs | **Chosen** |
| generative-ai-swift SDK | Google SDK | Typed API | Deprecated → Firebase AI Logic; needs SPM/modern Swift/Xcode | Rejected |
| Firebase AI Logic | Firebase | Managed keys | Heavy, needs Firebase project + Xcode | Rejected |

The REST contract was ported from the Android source (`GeminiService.kt`, `MainViewModel.kt`), including the markdown-fence cleanup and prompt text, rather than re-derived from docs.

## How to Run
```bash
cd .planning/spikes/002-gemini-swift-client
swiftc -o spike002 spike.swift            # compiles with stock CLT Swift 5.4
./spike002 fixtures                       # offline Codable validation
./spike002 errorpath                      # live endpoint, intentionally bad key
export GEMINI_API_KEY=your-key-here
./spike002 questions                      # live: 12 bypass questions
./spike002 verdict                        # live: Gordian Verdict synthesis
./spike002 all                            # everything + forensic log
```
Optional: `GEMINI_MODEL=...` to override the default `gemini-3.5-flash` (same model the Android app calls).

## What to Expect
- `fixtures`: 3 PASS lines (12 questions decoded, verdict sentiment, error message).
- `errorpath`: HTTP 400 with the decoded Google error message ("API key not valid...").
- `questions`: a numbered list of 12 sharp yes/no questions printed as the iOS app would show them.
- `verdict`: SENTIMENT / ANALYSIS / PROBE block.
- Every run exports `spike002-log.json` (forensic event log with timestamps, HTTP latencies, categories).

## Observability
Forensic log layer: in-memory event array (ISO-8601 timestamps, category tags START/TEST/HTTP/PASS/WARN/ERROR), exported to `spike002-log.json` with per-category counts, duration, and error count.

## Investigation Trail
1. First compile failed: over-eager optional chaining (`parts?.first`) — Swift 5.4 is stricter than expected about optional chaining on non-optionals. Fixed; clean compile with stock CLT.
2. Fixtures pass: the exact Moshi DTO shape from Android ports to Codable with no surprises. The double-decode pattern (envelope → `parts[0].text` → inner JSON) works identically.
3. Ported Android's markdown-fence stripping (` ```json ` prefix removal). With `responseMimeType: application/json` it's usually unnecessary, but keeping it costs nothing and guards regressions.
4. Live error path: endpoint reachable from URLSession, responded HTTP 400 in ~200ms, error envelope decoded cleanly. This proves transport, TLS, request encoding, and error DTOs — everything except an authenticated generation.
5. Swift 5.4 has no async/await, so the spike uses `DispatchSemaphore`. **The real iOS build (modern Xcode) should use `async/await` + `URLSession.data(for:)` instead** — this pattern is spike-only.
6. Live runs with a real key: `gemini-3.5-flash` is valid; verdict test passed first try (~7s latency — it's a *thinking* model, ~2000 thought tokens per call). Questions test **failed intermittently (~40%: 3 of 7 runs)**.
7. Forensics on the failing responses: `finishReason: STOP`, single part, but the JSON array text ends **without the closing `]`**. Not truncation by token limit — the thinking model just sometimes emits invalid JSON under plain `responseMimeType: application/json`. A `thoughtSignature` blob is attached to the part (harmless, ignored by Codable).
8. **The deployed Android app has this exact bug in production**: `MainViewModel` would hit the same ~40% parse failure, silently `catch`, and serve generic fallback questions instead of personalized ones. Users would never know.
9. Fix validated: adding `responseSchema: {type: ARRAY, items: {type: STRING}}` to `generationConfig` (constrained decoding) → **6/6 consecutive passes, zero repairs**. A defensive bracket-repair function (`repairJSONArray`) stays in as belt-and-suspenders and recovered truncated payloads in testing.
10. Also hardened: response `parts` are now concatenated instead of reading `parts[0]` only (Gemini may split output across parts; Android reads `firstOrNull()` — second latent bug).

## Results
**Verdict: VALIDATED** — all four test modes green end-to-end with a live key, including a 12-question generation and a full Gordian Verdict synthesis.

Proven:
- The full Android networking stack (Retrofit + Moshi + OkHttp) collapses to ~80 lines of Foundation-only Swift. No third-party dependencies needed on iOS.
- Request/response DTOs, JSON-mode payload decoding, and Google's error envelope all work under Codable.
- Latency profile: ~150ms error path, ~7s for generation calls (thinking model) — the iOS UI must show a generation state, exactly like the Android `isGeneratingQuestions` flag does.

**Non-negotiables for the real build (all learned the hard way here):**
1. Always set `responseSchema` on structured-output calls — plain `responseMimeType: application/json` is only ~60% reliable on this model.
2. Concatenate all response `parts`, never read `parts[0]` alone.
3. Keep a JSON-repair + local-fallback ladder behind the schema (the Android fallback-question UX design is right; its parse layer isn't).
4. The API key used during spiking was pasted in chat — **rotate it in AI Studio** before shipping anything.
