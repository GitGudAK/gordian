# Gordian — App Store submission pack

Everything paste-ready for App Store Connect. Copy follows the ground rules:
no AI mentions anywhere, no em-dashes, self-reflection positioning.

## App information

| Field | Value |
|---|---|
| Name | **Gordian** (fallbacks if taken: "Gordian: Decide in 60 Seconds", "Gordian — Untie Decisions") |
| Subtitle (30 chars) | `Decide in sixty seconds` |
| Bundle ID | `dev.gordian.app` |
| SKU | `gordian-ios-001` |
| Primary category | Productivity |
| Secondary category | Lifestyle |
| Price | **Free** (7-day full trial in app), with in-app purchases |
| Privacy Policy URL | `https://gordian-proxy.gordian-app.workers.dev/privacy` |
| Support URL | `https://gordian-proxy.gordian-app.workers.dev/support` |

## Promotional text (170 chars, editable without review)

> Stuck between two choices? Describe it, answer quick gut questions against a sixty-second clock, and see your own lean in plain words. Free for a week.

## Description

> You already know. Gordian helps you admit it.
>
> Describe what you're stuck on. Gordian writes rapid-fire gut questions for your exact dilemma and starts a sixty-second clock. Quick answers leave no time to build justifications, so the pattern that emerges is your own immediate preference, stated back to you in plain words: the decision, the why, and one small next step.
>
> WHAT MAKES IT DIFFERENT
> • Questions written for your exact situation, every session
> • Either/or dilemmas get buttons labeled with your own options
> • A straight answer grounded in what you actually said, never mysticism
> • Tangled, multi-part dilemmas get untied into separate knots you can run one at a time
> • Three days later, Gordian asks whether you acted on it, answerable from the notification
>
> PRIVATE BY DESIGN
> Your dilemmas and history live only on your device. No accounts, no sign-ins, no ads, no tracking. Deleting the app deletes your history.
>
> A CLEAR DEAL
> Free for 7 days from first launch. Then a simple subscription, or a one-time lifetime unlock if subscriptions aren't your thing.
>
> Gordian is a self-reflection exercise. It reflects your own answers and is not medical, legal, financial, or professional advice.

## Keywords (100 chars)

`decision,decide,overthinking,choice,dilemma,indecisive,gut,intuition,journal,clarity,focus,mind`

## Screenshots (ready at .planning/launch/screenshots/, 1320x2868, iPhone 6.9")

1. `01-home.png` — hero + free week pill
2. `02-session.png` — live session, dilemma-specific question, custom option buttons
3. `03-verdict.png` — verdict card: decision, why, next step
4. `04-knots.png` — MORE THAN ONE KNOT decomposition
5. `05-logs.png` — history + acted-on stats
(Suggested captions if using framed screenshots later: "Name the knot" / "Sixty seconds, no overthinking" / "A straight answer" / "Big ones get untied" / "Decisions you acted on")

## In-app purchases (create BEFORE first submission; attach to the version)

| Reference | Product ID | Type | Price |
|---|---|---|---|
| Gordian Monthly | `plus.monthly` | Auto-renewable, group "Gordian Access" | $4.99 |
| Gordian Annual | `plus.annual` | Auto-renewable, same group, level 1 | $29.99 (mark BEST VALUE on paywall) |
| Gordian Lifetime | `plus.lifetime` | Non-consumable | $69.99 |

No introductory offers (the free week is handled in-app, pre-purchase).
After the record exists: offer codes on plus.monthly ("3 months free"), promo codes for plus.lifetime.

## App Privacy (nutrition label answers)

- **Data used to track you: None.**
- **Data linked to you: None.**
- **Data not linked to you:**
  - User Content ("Other User Content" — dilemma text and answers): App Functionality only. Not linked (random device ID, no account), not used for tracking.
  - Identifiers ("Device ID" — app-generated random UUID, not the advertising identifier): App Functionality only (rate limiting).
- Purchases are handled by Apple; the app itself collects no purchase info.

## Age rating questionnaire

All content descriptors "None". Unrestricted web access: No. Gambling: No.
Expected rating: 4+ (the safety gate refuses violent/self-harm content; the
crisis-resources line is supportive, not descriptive).

## Review notes (paste into App Review Information)

> Gordian requires no account. Full access is free for 7 days from first launch, after which an in-app subscription or lifetime purchase unlocks sessions (products attached to this version).
>
> To test a session: type any two-option dilemma (e.g. "Should I learn Spanish or German?") and tap Untie My Knot. Question generation takes 5-10 seconds.
>
> Safety behavior: dilemmas describing harm to self or others are refused and the app pauses new sessions for 5 minutes with crisis resources (US 988). Test with "Should I hurt my neighbor?" if desired.
>
> The notification prompt appears only after the first completed verdict (used for optional follow-up reminders). Microphone/speech are optional, used for spoken reflections, transcribed on-device.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` is set in the project (standard HTTPS only). No documentation needed.

## Remaining operator steps (in order)

1. **Apple Developer Program** — enroll at developer.apple.com ($99/yr; approval up to 48 h).
2. **Agreements, Tax, Banking** in App Store Connect — REQUIRED before paid IAPs can be sold; the banking form can take days to clear, start it immediately.
3. **Certificates/Team in Xcode** — open the project, Signing & Capabilities, select your team (bundle ID `dev.gordian.app` registers automatically). Add the **In-App Purchase** capability.
4. **App Store Connect record** — My Apps → "+" → iOS app, name Gordian, bundle ID, SKU above. Fill App Information, upload screenshots, paste copy from this file.
5. **Create the 3 IAPs** (table above) and attach them to version 1.0.
6. **Archive & upload** — in Xcode: Product → Archive (device target), Organizer → Distribute → App Store Connect. (Requires your signing; cannot be done headless without your account.)
7. **TestFlight yourself for a day** — install on your real phone; the purchase flow, notifications, and mic behave differently on-device than in the Simulator.
8. **Submit for review** with the review notes above.
9. **After approval — launch-day codes (~10 min):**
   - Offer codes: Subscriptions → Gordian Monthly → Offer Codes → Create Offer
     (Free, 3 periods, all eligibility) → custom code `GORDIAN-LAUNCH`
     (cap ~200, 30-day expiry) + a 25-code one-time-use batch for gifts.
   - Promo codes: version page → Gordian Lifetime → generate on demand
     (100/version, single-use, 28-day expiry — mint when handing out).
   - Paste the app's numeric Apple ID into `RedeemCodeView.appStoreID` so
     redeem links pre-fill (ship in 1.0.1).

## Known non-blockers (documented)

- Trial clock resets on reinstall (UserDefaults); server-side hardening path exists via device first-seen date.
- Crisis resources are US-only (988); localize before non-US marketing push.
- workers.dev domain serves API + legal pages; custom domain decision deferred (some networks filter workers.dev).
