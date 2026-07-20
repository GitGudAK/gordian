# Gemini Structured Output (Swift)

## Requirements

- Every Gemini structured-output call MUST set `responseSchema` in `generationConfig` (REQ-005).
- Response `parts` MUST be concatenated — never read `parts[0]` alone (REQ-005).
- Keep the degradation ladder: schema → bracket repair → local fallback questions (REQ-005/006).
- All generation surfaces show a loading state sized for ~7s latency (REQ-006).
- API key from user settings/env — never hardcoded (MANIFEST).

## How to Build It

**The production implementation already exists: [ios/Gordian/GeminiClient.swift](../../../ios/Gordian/GeminiClient.swift).** Use it as-is; extend rather than rewrite. Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=API_KEY`, plain URLSession + Codable, zero dependencies.

The load-bearing parts:

1. **Schema-constrained decoding** (the fix that took reliability from ~60% → 6/6):
```json
"generationConfig": {
  "temperature": 0.8,
  "responseMimeType": "application/json",
  "responseSchema": {"type": "ARRAY", "items": {"type": "STRING"}}
}
```
For object payloads (verdict): `{"type": "OBJECT", "properties": {"sentiment": {"type": "STRING"}, ...}, "required": [...]}`.

2. **Join all parts** when extracting text:
```swift
let text = (decoded.candidates?.first?.content?.parts ?? []).compactMap(\.text).joined()
```

3. **Repair ladder** before giving up: strip markdown fences, trim trailing comma, append missing `]`, then fall back to the canned question list (see `SessionViewModel.fallbackBypassQuestions`).

4. **Error envelope**: non-2xx responses decode as `{"error": {"code", "message", "status"}}` — surface `message`, never the raw body.

## What to Avoid

- **Plain `responseMimeType: "application/json"` without a schema.** gemini-3.5-flash is a thinking model and intermittently (~40% observed: 3 of 7 live runs) emits the JSON array *without the closing bracket*, with `finishReason: STOP` and a `thoughtSignature` blob attached. It looks like a client bug; it isn't.
- **Reading `parts[0]` only** — Gemini can split output across parts. (The Android app has both of these bugs; a fix task exists.)
- **Deprecated `generative-ai-swift` SDK / Firebase AI Logic** — evaluated and rejected; raw URLSession is smaller and sufficient.
- **Trusting "exactly 12 questions"** — the prompt asks for 12, but tolerate 5–15.

## Constraints

- ~7s per generation call (thinking model, ~2,000 thought tokens per call); error path ~150–200ms.
- Model name `gemini-3.5-flash` verified valid (2026-07-20). If 404: fall back to `gemini-flash-latest`.
- `thoughtSignature` in response parts is harmless — Codable ignores it.
- The spike key was pasted in chat — rotate before any release.

## Origin

Synthesized from spike: 002 (VALIDATED). Source: sources/002-gemini-swift-client/. Production port: ios/Gordian/GeminiClient.swift.
