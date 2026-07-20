# Requirements

Requirements that have emerged from exploration and spiking. IDs are stable; downstream phases reference them.

## v1 — iOS App

- **REQ-001** — AI features work with zero user setup: the app calls a first-party backend proxy that holds the Gemini API key. No bring-your-own-key flow in the consumer UX.
- **REQ-002** — No user accounts. Anonymous usage with device attestation (DeviceCheck / App Attest) for proxy rate limiting.
- **REQ-003** — Decision history is stored on-device only. User dilemmas and reflections are never persisted server-side.
- **REQ-004** — Visual identity matches the Android app (near-black/gold palette, three-tab structure, 60-second session flow); interaction patterns are native iOS (SF Symbols, native navigation, spring animations, Dynamic Type, dark-mode correctness).
- **REQ-005** — Every Gemini structured-output call sets `responseSchema` and concatenates all response `parts`; JSON repair + local fallback questions remain as the degradation ladder (spike 002 evidence: ~40% invalid JSON without schema).
- **REQ-006** — All AI generation surfaces show a loading state sized for ~7s thinking-model latency; sessions never dead-end on API failure (fallback questions/verdict).
- **REQ-007** — App Store review readiness: microphone and speech-recognition usage descriptions, privacy nutrition label consistent with REQ-003, AI-generated-content policy compliance.
- **REQ-008** — Voice input uses on-device speech recognition where supported (spike 003: `supportsOnDeviceRecognition == true`), with the RMS sentiment wave driven from the same audio tap.
