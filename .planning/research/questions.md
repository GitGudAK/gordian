# Open Research Questions

## Backend proxy abuse protection (added 2026-07-20, from /gsd-explore)

How should an **anonymous** Gemini proxy for a consumer iOS app protect itself? Sub-questions:

- App Attest / DeviceCheck integration: how does the server validate attestations, and what's the failure UX on old devices/simulators?
- Per-device rate limiting without accounts: token bucket per attested device ID? What limits match the product (a session = ~3 Gemini calls)?
- Cost containment: hard daily spend caps, per-device quotas, and what the app shows when a cap is hit (degrade to local fallback questions?).
- Prompt abuse: users' dilemma text is forwarded to Gemini — does the proxy need input length caps / content filtering to protect the API key's standing?
- Hosting shape: smallest respectable option (Cloudflare Workers / Cloud Run / Vercel) for ~7s-latency streaming-friendly calls.
