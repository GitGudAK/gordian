# Gordian iOS — Design Review

**Date:** 2026-07-20 · **Method:** every screen captured on iPhone 16 Pro simulator + asset-catalog inspection · **Lens:** Rams' ten principles
**Tickets:** GitHub issues [#1–#13](https://github.com/GitGudAK/gordian/issues?q=label%3Adesign)

## The verdict in one paragraph

The bones are genuinely good: a disciplined two-color palette (gold on near-black) applied consistently, a strong central ritual (the 60-second ring), one excellent moment of restraint-in-motion (the verdict's breathing animation), and — after today's simplifications — an honest core loop: dilemma → gut answers → plain decision. What holds it back is ornament: the app *talks about itself* too much ("cognitive analysis engine", "deep calibration"), decorates where it should inform (unexplained pills, unlabeled charts, twin CTAs), and skips craft where nobody's looking (no app icon, fixed font sizes, 24pt tap targets). Rams: *"Good design is honest… and thorough down to the last detail."* The honesty is now mostly there; the thoroughness is the work ahead.

## What must not change

- The palette and its discipline. Two colors carrying the whole identity is the strongest design decision in the app.
- The countdown ring as the centerpiece of the session.
- The verdict animation — provided it shrinks to serve the answer instead of preceding it (#6).
- The dilemma → decision → why → next step verdict structure.
- Guide cards: icon-in-circle, title, honest read-time. The one screen that already says what it is.

## Findings by principle (worst offenses)

| Rams principle | Offense | Ticket |
|---|---|---|
| **Honest** | Gold-filled YES vs muted red NO biases the instrument itself — the tool nudges its own readings | **#8 (the most important finding)** |
| Honest | "COGNITIVE CLARITY RESTORED" asserts an outcome the app can't know; jargon labels throughout | #3 |
| Thorough | No app icon at all; "NODE"/"KNOT" typo; raw `DECISION:` prefix rendered in Logs | #1, #6, #9 |
| Useful | The verdict — the deliverable — sits below the fold behind decoration | #6 |
| Understandable | Chart with three unexplained colors; stats that don't sum; hidden tap-to-pause | #10, #7 |
| Unobtrusive | Two identical gold CTAs on one screen; brand rendered twice on home | #2, #11 |
| Useful for everyone | Fixed font sizes kill Dynamic Type; 24pt tap targets; missing VoiceOver labels | #5, #11(targets), #13 |
| Long-lasting | Settings hidden inside a content tab will confuse every future addition | #4 |

## Ticket index

| # | P | Title |
|---|---|---|
| [1](https://github.com/GitGudAK/gordian/issues/1) | P0 | No app icon — home screen tile is blank |
| [2](https://github.com/GitGudAK/gordian/issues/2) | P1 | One primary action per screen — twin gold CTAs on home |
| [3](https://github.com/GitGudAK/gordian/issues/3) | P1 | Honest, plain language pass |
| [4](https://github.com/GitGudAK/gordian/issues/4) | P1 | Settings buried inside Guides |
| [5](https://github.com/GitGudAK/gordian/issues/5) | P1 | Dynamic Type is dead (REQ-004 violation) |
| [6](https://github.com/GitGudAK/gordian/issues/6) | P1 | Verdict below the fold; NODE→KNOT typo |
| [7](https://github.com/GitGudAK/gordian/issues/7) | P2 | Session: dual progress systems, hidden pause, decorative brain |
| [8](https://github.com/GitGudAK/gordian/issues/8) | P2 | **Biased instrument: gold YES vs muted NO** |
| [9](https://github.com/GitGudAK/gordian/issues/9) | P2 | Logs cards: duplication, mislabeled metadata, leaked formatting |
| [10](https://github.com/GitGudAK/gordian/issues/10) | P2 | Logs stats ignore binary sessions; legendless chart |
| [11](https://github.com/GitGudAK/gordian/issues/11) | P2 | Destructive actions: permanent trash, small targets |
| [12](https://github.com/GitGudAK/gordian/issues/12) | P2 | Brand redundancy + muddy logo asset + radius drift |
| [13](https://github.com/GitGudAK/gordian/issues/13) | P3 | Accessibility labels + symbol-weight consistency |

**Suggested order:** #1 (five minutes, most visible) → #8 (integrity of the product) → #3+#6 together (one copy/layout pass) → #2, #4 → #5 → the P2 detail set.
