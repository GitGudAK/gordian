---
title: Monetization — free week, subscription/lifetime, coupon lanes
date: 2026-07-21
status: BUILT in-app (commit pending ASC setup); supersedes both the freemium
  meter plan AND the paid-upfront decision of earlier today
---

# Gordian monetization (final shape)

User requirements (2026-07-21): free access for 1 week after download; then charged;
operator can gift lifetime access and 3-month access via coupon codes. AI-always stands.

## In-app (BUILT)
- `EntitlementManager.swift` (StoreKit 2): products `plus.monthly` ($4.99), `plus.annual`
  ($29.99), `plus.lifetime` ($69.99, non-consumable). Access = purchase OR in-trial.
- **Trial:** 7 days anchored at first launch (device-side). No purchase or account needed
  to start it; home shows a "FREE WEEK · N DAYS LEFT" pill.
- **Paywall** replaces the Focus home when trial ends with no purchase. Logs/Guides stay
  accessible (user's data is theirs). A session in flight always finishes.
- Settings → MEMBERSHIP: status line, "Redeem a code" (offer-code sheet), Restore.
- Debug args: `-expireTrial`, `-resetTrial`. Local testing: `Gordian/Products.storekit`
  + shared scheme; purchase sheets only work when launched FROM XCODE (simctl launches
  skip the StoreKit config — paywall then shows "Loading plans…", which is also the
  graceful state before ASC products exist in production).

## Coupon lanes (Apple-native, zero custom backend)
- **3 months free** → subscription **Offer Codes** on plus.monthly (ASC → subscription →
  Offer Codes → "3 months free" → custom codes or one-time-use batches; 150k/quarter).
  Redeemed via the in-app "Redeem a code" sheet.
- **Lifetime** → **Promo Codes** for plus.lifetime (ASC → app version → Promo Codes;
  100/version, refreshes each release). Redeemed on the App Store redeem page.

## App Store Connect runbook (operator, when creating the app record)
1. App record: free app (price $0) + In-App Purchases.
2. Subscription group "Gordian Access": plus.monthly $4.99/mo, plus.annual $29.99/yr.
   No introductory offer (the free week is handled in-app, pre-purchase).
3. Non-consumable: plus.lifetime $69.99.
4. Offer code campaign on plus.monthly: "3 months free", free payment mode, 3 periods.
5. Promo codes for lifetime: generate per version as needed.

## Known gaps / later hardening
- Trial anchor is UserDefaults → a delete/reinstall restarts the week. Acceptable at
  launch; mitigation when it matters: proxy already knows each device's first-seen date
  (X-Device-ID meter) — return a `trial_expired` signal server-side.
- Price points are placeholders in Products.storekit; real prices set in ASC.
- App Review note: free week must be clearly disclosed on the App Store listing
  ("Free for 7 days, then subscription or one-time purchase").
