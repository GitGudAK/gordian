# Apple — resubmission pack for 1.0 (rejected 2026-07-28)

Submission ID `43dade4d-e964-462a-8e89-f970d6fa2ec4` · rejected on **3.1.1** (codes
unlocking content) and **2.1** (purchase flow not reachable).

Two things to send, in two different places. Paste each block as-is.

---

## 1 — Reply to App Review

App Store Connect → the rejected submission → **Reply to App Review**.

> Hello,
>
> Thank you for the detailed review. Both issues are addressed in the build attached to this resubmission.
>
> **Guideline 3.1.1 — codes unlocking content.** We have removed the in-app code entry screen entirely. Redemption is now handled exclusively by the App Store's own offer code redemption sheet, presented in-app via StoreKit. The app no longer accepts, validates, or acts on any code itself, and no longer links out to a web page for redemption. All access is unlocked solely by In-App Purchase.
>
> **Guideline 2.1 — reviewing the purchase flow.** Gordian has no accounts and no login of any kind, so a demo account is not applicable. The previous build gated the paywall behind a 7-day, device-local free trial, which is why the purchase flow could not be reached during review. We have added a permanent "See plans" button in Settings that opens the full purchase flow on demand.
>
> To review the complete purchase flow: launch the app, tap the gear icon in the top right, then tap **See plans**. Monthly, annual, and lifetime purchases are all presented there, and "Redeem a code" on the same screen opens the App Store redemption sheet.
>
> Thank you,
> Ashwin

---

## 2 — App Review Information → Notes

App Store Connect → the version → **App Review Information** → Notes field.

> Gordian has no accounts and no login, so no demo account is required or possible.
>
> TO SEE THE FULL PURCHASE FLOW: tap the gear icon (top right), then "See plans". This opens the paywall on demand — monthly, annual, and lifetime — without waiting out the 7-day trial. "Redeem a code" on the same screen opens the App Store's own offer-code redemption sheet; the app itself never unlocks anything.
>
> To test a session: type any two-option dilemma (e.g. "Should I learn Spanish or German?") and tap Untie My Knot. Question generation takes 5-10 seconds.
>
> Safety behavior: dilemmas about harming others are refused with a warning. Dilemmas involving self-harm are refused with a supportive crisis-resources line (US 988) and no penalty. Test with "Should I slash my neighbor's tires?" if desired.
>
> The notification prompt appears only after the first completed verdict (used for optional follow-up reminders). Microphone and speech are optional, used for spoken reflections, transcribed on-device.

---

## Checklist before hitting Resubmit

- [ ] New build from `main` attached (must include commits `ba9ab17` + `24d0dc2`)
- [ ] Review notes above pasted into App Review Information
- [ ] Reply above posted to App Review
- [ ] Decide: ship Private Mode in 1.0, or tighten its TestFlight gate before submitting
