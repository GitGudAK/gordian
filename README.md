# Gordian

**Untie the knot.** Gordian is a decision-making app for people stuck in loops: describe what you're wrestling with, answer twelve rapid-fire gut questions against a 60-second clock, and get a straight answer — your dilemma, your decision, why, and the next step. Quick answers leave no time to build justifications; the pattern is your gut talking.

- **The 60-second session** — one dilemma, twelve questions, no time to overthink. Yes/no dilemmas get Yes/No buttons; either/or dilemmas ("Spanish or German?") get buttons labeled with your own options.
- **A straight verdict** — the decision in plain words, the why grounded in your actual answers, and one concrete next step. No mysticism.
- **Close the loop** — three days later, Gordian asks whether you acted on it, answerable straight from the notification. Logs track decisions *acted on*, not just made.
- **The Daily Knot & weekly recap** — an optional morning reflection question and a Sunday summary. Every notification type has its own toggle; quiet weeks get no recap.
- **Private by design** — dilemmas and history live only on the device. AI question generation is the only thing that touches a server.
- **Never dead-ends** — with AI, questions are written for your exact dilemma; without it, a built-in bank keeps every session working offline.

## Repository layout

| Path | What it is |
|---|---|
| `ios/` | The native iOS app (SwiftUI, iOS 17+, SwiftData, `@Observable`) — the primary product |
| `app/` | The original Android app (Kotlin / Jetpack Compose) this project converted from |
| `.planning/` | Roadmap, requirements, strategy notes, spike records (GSD workflow) |
| `.claude/skills/spike-findings-gordian/` | Proven implementation patterns from the spike phase (Gemini structured-output hardening, audio pipeline, toolchain notes) |

## iOS development

**Prerequisites:** Xcode 16+ (this repo is routinely built with Xcode 16.4 / iOS 18.5 SDK — the last Intel-compatible release).

```bash
open ios/Gordian.xcodeproj          # set a signing team, then Run
# or headless:
cd ios && xcodebuild -project Gordian.xcodeproj -scheme Gordian \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build build
```

Debug builds accept launch arguments for jumping straight to screens: `-demoSession`, `-demoBinary`, `-demoVerdict`, `-demoLive`, `-fastFollowUp`, `-fastDailyKnot`, `-tabLogs`, `-tabGuides`.

## Architecture notes

- AI calls use Gemini's `generateContent` with `responseSchema` (mandatory — plain JSON mode truncates ~40% of the time on thinking models; see the spike findings), full response-`parts` concatenation, and a repair + local-fallback ladder.
- In production the model runs behind a small proxy (Phase 1 of the roadmap) holding the operator's API key — the app ships with no keys and no accounts.
- Roadmap: `.planning/ROADMAP.md` · Requirements: `.planning/REQUIREMENTS.md` · Business strategy: `.planning/notes/b2c-strategy.md` · Design tickets: GitHub issues labeled `design`.

## Android (original)

**Prerequisites:** [Android Studio](https://developer.android.com/studio)

1. Open the repo root in Android Studio and let it import
2. Create `.env` with `GEMINI_API_KEY` (see `.env.example`)
3. Remove `signingConfig = signingConfigs.getByName("debugConfig")` from `app/build.gradle.kts`
4. Run on an emulator or device
