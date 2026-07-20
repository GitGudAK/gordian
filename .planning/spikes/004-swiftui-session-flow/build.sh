#!/bin/bash
set -e
cd "$(dirname "$0")"
swiftc -o SessionFlow SessionFlow.swift -framework SwiftUI -framework Combine -parse-as-library
echo "built ./SessionFlow — run it and a Gordian window appears"
