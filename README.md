<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/d5899638-c30a-4e2f-a84f-11ae1826ddec

## iOS App (`ios/`)

A native SwiftUI port of the Android app (same look and feel, iOS 17+). Built with modern idioms: `@Observable`, SwiftData (replacing Room), async/await URLSession (replacing Retrofit), and `SFSpeechRecognizer` + `AVAudioEngine` with hand-computed RMS for the sentiment wave (replacing Android `SpeechRecognizer`). Includes the spike-002 Gemini hardening: `responseSchema` on every structured call, response `parts` concatenation, and bracket-repair + local fallbacks.

**Prerequisites:** Xcode 16+ (see `.planning/spikes/001-ios-toolchain-readiness/` if setting up this machine).

1. `open ios/Gordian.xcodeproj`
2. Select a signing team (Signing & Capabilities) — bundle id `dev.gordian.app`
3. Run on a simulator or device
4. Optional: paste a Gemini API key in the Guides tab ("Deep Cognitive Calibration") — without it, the app uses local fallback questions, same as Android

Status: source-complete port, written on a machine without Xcode — expect first-build fixups (see `ios/` commit notes).

## Run Locally (Android)

**Prerequisites:**  [Android Studio](https://developer.android.com/studio)


1. Open Android Studio
2. Select **Open** and choose the directory containing this project
3. Allow Android Studio to fix any incompatibilities as it imports the project.
4. Create a file named `.env` in the project directory and set `GEMINI_API_KEY` in that file to your Gemini API key (see `.env.example` for an example)
5. Remove this line from the app's `build.gradle.kts` file: `signingConfig = signingConfigs.getByName("debugConfig")`
6. Run the app on an emulator or physical device
