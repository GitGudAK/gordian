---
title: B2C strategy — operator key, freemium, launch sequence
date: 2026-07-20
context: User direction: "I have a Gemini API key ready. I need to use this in the app, and make this app B2C business."
---

# Gordian B2C Strategy

## Key architecture (non-negotiable)
The operator's Gemini key lives ONLY server-side in the Phase 1 proxy (Cloudflare Worker-class host, free tier). Never embedded in the app binary (extractable → bill abuse). Proxy owns prompts + model choice → post-launch iteration without app releases. Per-device rate limits + hard daily spend cap from day one; App Attest hardening can follow launch.

## Unit economics
Session ≈ 3 calls ≈ <$0.01. Heavy user ≈ $0.10–0.30/month. Price from value, not cost.

## Monetization — honest freemium
- **Free:** unlimited offline sessions (bank), 3 AI-personalized sessions/week, follow-ups, logs. Never dead-ends (REQ-006 constant preserved).
- **Gordian Plus:** $3.99/mo · $19.99/yr — unlimited AI sessions, Daily Knot+, streaks/recaps, voice mode (v2). Apple Small Business Program → 85% net.
- Meter creates the upgrade moment at peak motivation (mid-dilemma, wanting personal questions).

## Go-to-market
- Short-video content engine: 60s sessions screen-recorded per real dilemma (TikTok/Reels/Shorts) — the product is natively the content format.
- App Store search: decision paralysis, overthinking, can't decide. Product Hunt. Careful Reddit (r/DecidingToBeBetter).
- Privacy story as marketing: "your dilemmas never leave your phone."

## Compliance (launch-blocking)
- Remove "therapeutic tool" claim and any therapy/health language (App Store review + liability). Reposition: decision-making exercise.
- Ship crisis-input path (SENSITIVE classification → resources, never gamified) before launch.

## Build order
1. Phase 1: proxy with operator key (+ Gemini flash vs Claude Haiku 4.5 bake-off; hybrid Haiku-questions/Sonnet-verdict option)
2. Phase 3: app→proxy integration; remove BYO-key plumbing (also fixes "questions always the same" for every user)
3. Phase 3.5 (new): monetization — StoreKit 2 subscription, AI-session metering, paywall
4. Phase 5: launch readiness (copy compliance, crisis path, privacy labels, screenshots)
5. Launch + content loop

## North-star metric
"Decisions acted on" (from the follow-up loop) — retention driver, paywall justification, and a defensible marketing claim.
