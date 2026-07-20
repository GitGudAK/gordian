---
spike: 004
name: swiftui-session-flow
type: standard
validates: "Given the 60s countdown + rapid-fire flow, when built in SwiftUI, then the pressure-session feel matches the Android version"
verdict: PARTIAL
related: [001-ios-toolchain-readiness, 002-gemini-swift-client, 003-speech-rms-swift]
tags: [swiftui, timer, ux]
---

# Spike 004: SwiftUI Session Flow

## What This Validates
The 60-second pressure session — countdown ring, rapid-fire yes/no cadence, verdict reveal — is Gordian's entire product feel. This spike rebuilds the Android `FocusScreenState` flow (HOME → ACTIVE_SESSION → VERDICT) in SwiftUI to prove the interaction model ports. Because the iOS Simulator is blocked (spike 001), it runs as a **macOS SwiftUI window**, exploiting spike 001's finding that SwiftUI.framework ships in the CLT macOS SDK.

## How to Run
```bash
cd .planning/spikes/004-swiftui-session-flow
./build.sh
./SessionFlow          # a dark Gordian window appears
```

## What to Expect
- HOME: gold "GORDIAN" wordmark on near-black, "UNTIE THE KNOT" button.
- SESSION: a 60s circular countdown (turns red under 10s), the Android fallback bypass questions one at a time, YES/NO buttons with a quick crossfade on answer, running question counter.
- VERDICT: sentiment derived from your yes/no balance, analysis text, probe quote, YES/NO tally, and a NEW SESSION loop back.
- Palette is a 1:1 port of `ui/theme/Color.kt` (DarkBackground #08090B, GoldPrimary #D4AF37, RedAccent #E05C5C…).

## Investigation Trail
1. Wrote the flow deliberately within iOS-14-era SwiftUI limits (Swift 5.4: no `.task`, no `@Observable` macro, no async/await) — `ObservableObject` + `Timer.publish` + `onReceive`. This is the *floor*; the real iOS build on modern Xcode gets nicer APIs for free.
2. Compiled clean on the first attempt against the macOS 11.3 SDK — including `switch` inside `ViewBuilder` and `@StateObject`, both SwiftUI 2.0 features. No workarounds needed.
3. Smoke test: app launched, window stayed alive 4s, no crash, clean kill.
4. Not ported in this spike (intentionally out of scope): the CLARIFYING screen (Gemini-dependent — spike 002's territory), voice input (spike 003's), Room persistence, and the Insights/Calibrate tabs. The spike isolates the *session feel* question only.
5. Timer semantics note: Android restarts the 60s clock per question (`nextQuestion()` resets `countdownSeconds = 60`); the spike keeps one 60s clock for the whole rapid-fire run, which matches how `submitRapidFireAnswer` (the newer flow) actually behaves. Verified against `MainViewModel.kt` — the rapid-fire path never resets the clock mid-session.

## Results
**Verdict: PARTIAL → expected VALIDATED after you run it and the pressure feel lands.** The definitive iOS validation (Simulator, touch targets, haptics) stays gated on spike 001 remediation, but the flow logic and view structure are proven portable.

Proven:
- The whole Android session state machine (~5 StateFlows) collapses into one `ObservableObject` with 5 `@Published` properties — the MVVM shapes map 1:1 (`StateFlow` → `@Published`, `collectAsState()` → `@ObservedObject`).
- The countdown/question/verdict flow renders and animates in SwiftUI 2.0-era APIs, so nothing about the design needs modern-only features.
- Compose → SwiftUI layout translation was mechanical for these screens (Column→VStack, Box→ZStack, Modifier chains→view modifiers).

User checkpoint: run `./SessionFlow`, do a full 60s session answering from the gut, and judge: does the pressure cadence feel like the Android app? Pay attention to question-transition snappiness and whether the sub-10s red state raises urgency.
