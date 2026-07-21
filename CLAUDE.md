# Gordian

60-second decision-paralysis-bypass app. Android original in `app/` (Kotlin/Compose), native iOS port in `ios/` (SwiftUI, iOS 17+, uncompiled until Xcode is installed). Planning artifacts in `.planning/`.

## Auto-load routing

- **Spike findings for gordian** (implementation patterns, constraints, gotchas) → `Skill("spike-findings-gordian")`

## Ground rules

- Gemini structured-output calls always use `responseSchema` and concatenate response `parts` — see `.claude/skills/spike-findings-gordian/references/gemini-structured-output.md` before touching AI code.
- Hold `AVAudioEngine` in a strong reference; never `AVAudioEngine().inputNode`.
- Requirements live in `.planning/REQUIREMENTS.md`; product direction in `.planning/notes/ios-product-direction.md`.
- **AI is invisible (user decision 2026-07-21):** user-facing copy never mentions AI, models, or providers — anywhere (app strings, notifications, paywall, App Store listing). Say "written for your exact dilemma", never "written by AI". No em-dashes in user-facing copy either.
