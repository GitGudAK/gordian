# Spike Conventions

Patterns and stack choices established across spike sessions. New spikes follow these unless the question requires otherwise.

## Stack
- **Swift compiled directly with `swiftc`** (CLT Swift 5.4, macOS 11.3 SDK) — no Xcode, no SPM, no packages. Every spike must compile with the stock toolchain until Xcode is installed.
- Write to the **Swift 5.4 floor**: no async/await (use `DispatchSemaphore` for sync CLI calls), no `@Observable` macro (use `ObservableObject` + `@Published`), no `.task` (use `Timer.publish` + `onReceive`).
- Networking: **Foundation URLSession + Codable only** — mirrors the Android Retrofit/Moshi design with zero dependencies.
- UI spikes: **macOS SwiftUI windows** as the iOS stand-in (SwiftUI.framework ships in the CLT SDK). GUI apps need `-parse-as-library` with `@main`.

## Structure
- One directory per spike: `.planning/spikes/NNN-name/` with `spike.swift` (or `SessionFlow.swift` for GUI), `build.sh`, `README.md`, and a `spikeNNN-log.json` forensic log.
- CLI spikes take a mode argument (`fixtures | errorpath | status | rms | full | all`) so offline and live tests are separable.
- Fixtures live in `fixtures/` as captured-shape JSON for offline Codable validation.

## Patterns
- **Forensic log layer** in every runtime spike: in-memory event array with ISO-8601 timestamps + category tags (START/TEST/PROBE/HTTP/PASS/WARN/ERROR), exported to JSON with per-category counts and summary stats. Always `fflush(stdout)` after each log line — buffered output vanishes on crashes.
- **Hold `AVAudioEngine` in a strong reference.** `AVAudioEngine().inputNode` segfaults when the temporary deallocates; AVAudioNode does not retain its engine.
- **Bare CLIs needing TCC permissions** (mic, speech) must embed usage descriptions via `-Xlinker -sectcreate __TEXT __info_plist Info.plist`.
- Gemini payload handling: double-decode (envelope → joined `parts[].text` → inner JSON) + markdown-fence stripping. **Always set `responseSchema` in `generationConfig`** — plain `responseMimeType: application/json` on gemini-3.5-flash intermittently (~40%) omits the closing bracket. **Always concatenate all `parts`**, never read `parts[0]` alone. Keep bracket-repair + local fallback behind the schema.
- API keys come from env vars (`GEMINI_API_KEY`, optional `GEMINI_MODEL`) — never hardcoded, never committed, never echoed.

## Tools & Libraries
- Foundation, SwiftUI, Combine, AVFoundation, Speech — all present in the CLT macOS 11.3 SDK.
- Avoid: generative-ai-swift (deprecated), Firebase AI Logic (heavy), anything requiring SPM/Xcode until spike 001 remediation.
