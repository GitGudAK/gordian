---
status: SEED — founder-approved direction, NOT committed, NOT scheduled
source: /gsd-explore session, 2026-07-30
mockups: assets/social-mockups.html (also published: https://claude.ai/code/artifact/44eb64d0-00c0-4015-b636-3aae2525e489)
---

# Decisions as social objects — milestone-2 candidate features

## The thesis

V1 treats every decision as disposable: one person, one dilemma, one verdict, a
log row. The explore session located the churn risk there — after two weeks the
app has learned things about the user it never says, and nothing about using it
ever reaches another human. Blowout consumer apps win on identity (the app
knows me), proof (it is visibly right), and spread (using it puts it in front
of others). All four seeds below attack one of those. None are committed.

## Seed 1 — The Mirror (decision personality)   [identity]

After ~10 sessions, Gordian names the user's decision style from their own
verdict history: "You decide fast about money and slow about people. You have
never regretted a leap." Monthly Mirror; yearly Wrapped-style edition designed
to be shared. Nobody else has this data: journals have no verdicts, chatbots
have no forced gut answers. Highest blowout potential of the four; the share
motive (self-identity) is the strongest that exists.

Depends on: nothing to start; sharpened by Seed 2's data.
Est: 2-3 weeks (pattern generation via proxy op over local logs + report UI).

## Seed 2 — The gut track record   [proof / retention moat]

Second follow-up ~30 days after an acted-on decision: glad or regret? Then the
app can say "Your gut is 9-for-11 when you act within a day." The app becomes
more trustworthy the longer it is used; quitting means abandoning accumulated
proof. Cold-start-proof moat. Feeds Seed 1.

Depends on: existing follow-up loop (digest). Est: ~1 week.

## Seed 3 — Shared Knots   [spread, deep]

One dilemma, two people, same frozen sixty seconds, no peeking; reveal shows
where guts agree and collide, one joint next step. "A mirror for two, never a
judge." Full flow mocked in assets/social-mockups.html (Act II).

Design calls made during explore (revisit at planning):
- Rendezvous WITHOUT accounts: own-server ephemeral state, token links,
  TTL + delete after reveal. NOT CloudKit (iOS-only; Android app exists).
- Privacy posture: sharing is explicit transmission — Private Mode does not
  apply to shared knots; needs privacy-policy section + nutrition-label update.
- V1 requires the app on both ends: the invite IS the growth loop
  ("Ashwin wants to untie a knot with you"). Web-session fallback deferred.
- No push infrastructure: reveal-on-next-open; the humans notify each other in
  the chat the invite traveled through. Suspense as a feature.
- Question set generated ONCE and frozen; comparison is a NEW proxy op
  (two answer sets -> agreement map + joint framing).

Est: 3-6 weeks — biggest build since launch (proxy ops, TTL storage in a DO,
universal links, two-phase session state, reveal UI).

## Seed 4 — The Verdict Card   [spread, shallow / the experiment]

On-device rendered share card (ImageRenderer -> ShareLink): knot mark, the
decision as one imperative line, date, "decided in 61 seconds", whispered
wordmark. Story 9:16 + square 1:1. Dilemma text OFF by default — people
announce the cut, not the deliberation; it is the announcement artifact for
life decisions people already announce in chats. App Store link travels in the
share TEXT, never on the image. Mocked in assets/social-mockups.html (Act I).

Est: ~1 week, zero server, zero review risk. Campaign-tagged store links give
first-ever attribution data.

## Sequencing (agreed in session)

Card (4) ships first — one week, and its share data de-risks the Shared Knots
bet before committing 3-6 weeks. Track record (2) is cheap and starts the
30-day data clock early. Mirror (1) lands once enough history exists. Knots (3)
anchors the milestone only if the card proves decisions spread.

## Explicitly rejected / parked during exploration

- Daily Knot tap-through improvements: parked by founder ("ignore the daily knot").
- Capture-friction features (widget/Action Button/Siri): needs customer
  validation first; founder declined to speculate.
