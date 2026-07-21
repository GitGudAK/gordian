---
title: Habit loops — retention through value, not nagging
trigger_condition: v1 shipped; retention becomes the active question (extends re-engagement-layer)
planted_date: 2026-07-20
---

# Habit Loops (v2)

User direction (2026-07-20): make Gordian habit-forming; notify users when new guides publish.

Ranked mechanics (Hook model: trigger → action → variable reward → investment), Gordian-specific:

1. **Decision follow-ups ("close the loop") — build first.** N days after a verdict, local notification: "You decided X. Did you act on it?" One-tap yes/no writes back to the log. Logs become a record of kept/broken decisions — real invested value, the strongest retention force. Needs: notification permission flow, follow-up scheduling per log entry, acted-on field in DecisionLog.
2. **The Daily Knot.** One reflective question/day as widget + optional morning notification. Content can ship in-binary (365 canned) or via remote feed.
3. **Decisiveness streaks.** Count decisions acted on (from follow-ups), not app opens. Honest metric, on brand.
4. **Home-screen widget.** Last verdict + start-session bolt (extends re-engagement-layer seed).
5. **Weekly recap.** Local notification Sunday evening: sessions run, decisions acted on.
6. **New-guide notifications** (explicit user ask). DEPENDENCY: guides must load remotely first — Phase 1 backend serves guides.json; app uses BGAppRefreshTask to detect unseen guides → local notification. No APNs needed for v1 of this.

Ethics guardrail: this is a decision-help tool — retention must come from closed loops and stored value, never from anxiety triggers. Every notification is user-disableable per type in Settings.

Related: [[re-engagement-layer]], [[voice-session-mode]], `.planning/ROADMAP.md` Phase 1 (remote guides endpoint).
