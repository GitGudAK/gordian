# iOS Toolchain (this machine)

## Requirements

- The real build targets iOS 17+ with Xcode 16+ (the `ios/Gordian.xcodeproj` uses Xcode 16 synchronized groups, `@Observable`, SwiftData).

## How to Build It

Remediation checklist for this Mac (macOS 15.7, Intel) — user actions, in order:

1. Free ~30 GB disk (was 25 GiB free; Xcode expansion needs ~40 GB headroom).
2. Install Xcode from the Mac App Store (~15 GB).
3. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
4. Launch Xcode once; install the iOS Simulator runtime (Settings → Platforms, ~8 GB).
5. Verify: `xcodebuild -version && xcrun simctl list devices available`
6. Then: `open ios/Gordian.xcodeproj`, set a signing team, run.

## What to Avoid

- **Don't assume the CLT toolchain can do anything modern.** Stock state: Swift 5.4 (2021), macOS 11.3 SDK, no iOS SDK, no simctl. No async/await, no `@Observable`, no `.task`.
- **Don't write spike code in modern Swift** until Xcode is installed — it won't compile here. Spike to the 5.4 floor (see CONVENTIONS.md).
- The `ios/` port has **never been compiled** (written pre-Xcode); expect minor first-build fixups and budget a session for them.

## Constraints

- Intel Mac: Simulator performance modest; current Xcode still supports it on macOS 15.
- Useful escape hatch discovered: the old CLT SDK ships SwiftUI/Speech/AVFoundation, so runnable macOS prototypes are possible without Xcode (spikes 003/004 exploit this).

## Origin

Synthesized from spike: 001 (INVALIDATED — environment gap, not product gap). Source: sources/001-ios-toolchain-readiness/ (includes captured evidence.txt).
