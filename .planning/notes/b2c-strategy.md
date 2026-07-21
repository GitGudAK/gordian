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

## Coupons & gifted access (user direction 2026-07-20)

Two grant types the operator can hand out, done the Apple-native way (how Endel, Calm, etc. run partner/press promos — no custom redemption backend, no App Review 3.1.1 risk from self-built unlock codes):

**Product catalog (StoreKit 2, Phase 3.5):**
- `plus.monthly` — auto-renewable, $3.99/mo
- `plus.annual` — auto-renewable, $19.99/yr
- `plus.lifetime` — non-consumable (price TBD, ~$49.99)

**1. "3 months access" → App Store Offer Codes** on the subscription:
- Created in App Store Connect (subscription → Offer Codes): a "3 months free" offer, issued either as memorable custom codes with redemption limits (e.g. `GORDIAN-LAUNCH`) or one-time-use code batches (CSV export for partners/press).
- Redeemed in-app via StoreKit's offer-code redemption sheet, or via link `https://apps.apple.com/redeem?ctx=offercodes&id=<appId>&code=<CODE>`.
- Capacity: up to 150,000 codes per app per quarter — effectively unlimited at our scale. Apple handles expiry, one-use enforcement, and the transition to paid after 3 months.

**2. "Lifetime access" → App Store Promo Codes** for the `plus.lifetime` non-consumable:
- App Store Connect promo codes grant the IAP free; limit 100 per product per app version (refreshes each release) — right-sized for press, friends & family, and super-fans.
- Redeemed on the App Store redeem page or via redeem link.
- If >100/version is ever needed: ship versions more frequently, or revisit — do NOT build self-managed unlock codes (App Review Guideline 3.1.1 risk; also breaks with anonymous, serverless entitlements).

**Entitlement resolution (app-side, no server):** Plus = active subscription entitlement OR owned `plus.lifetime` transaction, via StoreKit 2 `Transaction.currentEntitlements`. Works fully offline, consistent with the anonymous/local-only privacy constant.

**Redemption UX:** Settings → "Redeem a code" row → offer-code sheet (subscriptions) + a small "have a promo code?" link to the App Store redeem page (lifetime).

## North-star metric
"Decisions acted on" (from the follow-up loop) — retention driver, paywall justification, and a defensible marketing claim.
