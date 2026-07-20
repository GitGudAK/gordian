#!/bin/bash
# Builds spike003 with the TCC usage descriptions embedded in the binary's __info_plist
# section (required for a bare CLI to request mic/speech authorization without crashing).
set -e
cd "$(dirname "$0")"
swiftc -o spike003 spike.swift \
  -framework AVFoundation -framework Speech \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist
echo "built ./spike003 — run: ./spike003 status | rms | full"
