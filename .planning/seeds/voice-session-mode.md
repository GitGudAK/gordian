---
title: Voice session mode — conversational back-and-forth with a calming voice
trigger_condition: v2 — after v1 ships to the App Store
planted_date: 2026-07-20
---

# Voice Session Mode (V2)

A dedicated experience, separate from the tap-through session: the app *speaks* each bypass question in a calming voice, the user answers aloud, and the loop advances hands-free — a back-and-forth conversation, "calming Siri" feel.

Decided 2026-07-20: deferred to V2 by user; inline mic/reflection UI was removed from the v1 session screen the same day.

## Spike plan already scoped (run these when picked up)

| Spike | Validates | Risk |
|---|---|---|
| 005a tts-avspeech | AVSpeechSynthesizer premium/enhanced voices sound calm, not robotic | High — kills premise if robotic |
| 005b tts-gemini | Gemini TTS quality justifies per-question latency + cost | High |
| 006 voice-loop | TTS→listen→advance turn-taking works hands-free (TTS fully stops before mic opens) | Medium |

Known constraints: Apple does not expose actual Siri voices to apps; premium system voices may require a one-time download in Settings; Simulator speech recognition may lack on-device support (test on hardware). Build as a DEBUG "Voice Lab" screen for A/B listening.

Existing assets: `ios/Gordian/SpeechRecognizer.swift` (recognition + RMS, spike-003-proven) still powers dictation on the home/clarifying screens and is the input half of this loop.

Related: [[re-engagement-layer]], [[ios-product-direction]]
