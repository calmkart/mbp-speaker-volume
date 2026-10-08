#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
target="build/MBP Speaker Volume.app"
mkdir -p "$target/Contents/MacOS"
xcrun swiftc -O -parse-as-library AudioDevice.swift App.swift \
  -o "$target/Contents/MacOS/MBPSpeakerVolume"
cp Info.plist "$target/Contents/Info.plist"
codesign --force --sign - "$target"
codesign --verify --strict "$target"
printf '%s\n' "$target"
