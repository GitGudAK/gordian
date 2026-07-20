---
spike: 001
name: ios-toolchain-readiness
type: standard
validates: "Given this Mac (macOS 15.7, CLT-only), when we attempt an iOS SwiftUI build, then the toolchain compiles and a Simulator boots"
verdict: INVALIDATED
related: [002-gemini-swift-client, 003-speech-rms-swift, 004-swiftui-session-flow]
tags: [toolchain, xcode, environment]
---

# Spike 001: iOS Toolchain Readiness

## What This Validates
Given this Mac (macOS 15.7.7, Command Line Tools only), when we attempt to build and run an iOS SwiftUI app, then the toolchain compiles it and a Simulator boots.

## How to Run
```bash
bash -c 'cat evidence.txt'   # captured evidence
# or re-gather: xcode-select -p; xcodebuild -version; xcrun --show-sdk-path --sdk iphonesimulator
```

## What to Expect
As of 2026-07-20: every iOS-specific probe fails. See `evidence.txt`.

## Investigation Trail
1. `xcodebuild -version` → fails: active developer dir is a CommandLineTools instance, not Xcode.
2. `/Applications` contains no Xcode of any version.
3. `xcrun --show-sdk-path --sdk iphonesimulator` → SDK cannot be located. No iOS SDK exists on this machine.
4. `xcrun simctl` → utility not found. No Simulator runtime.
5. CLT toolchain is **severely outdated**: Swift 5.4 (Xcode 12.5 era, 2021) with a **macOS 11.3 SDK**, running on macOS 15.7. No async/await (needs 5.5+), no modern SwiftUI APIs, no `@Observable` macro.
6. Surprise finding: the old macOS 11.3 SDK **does** ship SwiftUI.framework, Speech.framework, and AVFoundation.framework — so limited macOS-side prototyping of app pieces is possible without Xcode (exploited by spikes 002/003/004).
7. Surprise finding #2: **disk space is a second blocker** — only ~25 GiB free on `/`. Xcode 16.x needs ~15 GB download and ~40+ GB free during expansion/first-launch component install. An Xcode install will likely fail or leave the disk critically full without cleanup first.
8. Arch note: toolchain targets `x86_64-apple-darwin` (Intel Mac). Current Xcode still supports Intel on macOS 15, but iOS Simulator performance will be modest.

## Results
**Verdict: INVALIDATED (as-is).** This Mac cannot build or run an iOS app today. Nothing about the *project* is infeasible — this is purely an environment gap, with a concrete remediation path:

**Remediation checklist (user actions — cannot be automated):**
1. Free ~30 GB of disk space (currently 25 GiB free; Xcode expansion needs ~40 GB headroom).
2. Install Xcode from the Mac App Store (or `xcodes`/Apple Developer downloads), ~15 GB.
3. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
4. Launch Xcode once to install the iOS platform (Settings → Platforms → iOS Simulator runtime, ~8 GB more).
5. Re-verify: `xcodebuild -version && xcrun simctl list devices available`

**Impact on remaining spikes:** 002 (Gemini client) and 003 (speech/RMS) proceed now against the macOS SDK with Swift 5.4 (pre-async/await syntax). 004 (SwiftUI session flow) is built as source + a macOS-SDK compile check; running it in an iOS Simulator stays blocked until remediation.
