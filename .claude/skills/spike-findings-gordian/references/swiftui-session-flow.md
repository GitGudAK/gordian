# SwiftUI Session Flow (60-second pressure UX)

## Requirements

- Visual identity matches Android: near-black/gold palette, three tabs, 60s session flow (REQ-004).
- Native iOS interaction patterns: SF Symbols, spring/crossfade animations, Dynamic Type respect, dark mode locked (REQ-004).
- Sessions never dead-end on API failure (REQ-006).

## How to Build It

**Production implementation: [ios/Gordian/](../../../ios/Gordian/)** — full port already exists (13 files). Key mappings proven in spike 004 and carried into the port:

| Android | iOS |
|---|---|
| `StateFlow` + `collectAsState()` | `@Observable` class + plain property access |
| `viewModelScope.launch` | `Task { }` on `@MainActor` |
| Compose `Canvas` timer arc | `Circle().trim(from:to:)` + `.rotationEffect(-90°)` |
| Per-question crossfade | `.id(questionIndex)` + `.transition(.opacity)` |
| `rememberInfiniteTransition` | `TimelineView(.animation)` + `Canvas` (CalmingAnimation) |
| Room + Flow | SwiftData `@Model` + `@Query(sort:order:)` |

Timer semantics (verified against `MainViewModel.kt`): the rapid-fire path keeps ONE 60s clock for the whole session — `submitRapidFireAnswer` never resets it. Questions wrap around modulo the list. Timer expiry → `evaluateFullSessionAndLog()` → VERDICT.

Palette (exact, from `Color.kt`): background #08090B, surface #131518, surfaceVariant #1E2127, gold #D4AF37, textLight #EAEAEA, textMuted #9A9FA5, red #E05C5C, goldAccent #F1E4C3.

## What to Avoid

- Don't re-derive the state machine — `FocusScreenState` (home → clarifying → activeSession → verdict) is already ported 1:1 in `SessionViewModel`.
- Don't reset the countdown per question (an older Android code path does; the live rapid-fire path doesn't).
- The whole session UI worked within SwiftUI-2.0-era APIs in the spike — no design element requires modern-only features, so never block polish on API availability.

## Constraints

- Session "feel" (pressure cadence, sub-10s urgency) still needs human verification — run `sources/004-swiftui-session-flow/build.sh` for the macOS prototype, or the iOS app once Xcode lands.
- The macOS prototype is Swift 5.4-floor code; the iOS port is the modern-idiom version. When they disagree, the iOS port wins.

## Origin

Synthesized from spike: 004 (PARTIAL — runs as macOS app; Simulator gated on toolchain). Source: sources/004-swiftui-session-flow/. Production port: ios/Gordian/.
