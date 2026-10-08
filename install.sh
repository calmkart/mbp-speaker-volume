#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
zsh build.sh
target="/Applications/MBP Speaker Volume.app"
ditto "build/MBP Speaker Volume.app" "$target"
codesign --verify --strict "$target"
agent="$HOME/Library/LaunchAgents/local.buzz.mbp-speaker-volume.login.plist"
mkdir -p "${agent:h}"
cat > "$agent" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.buzz.mbp-speaker-volume.login</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/open</string><string>-g</string>
    <string>/Applications/MBP Speaker Volume.app</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
PLIST
chmod 644 "$agent"
domain="gui/$(id -u)"
label="local.buzz.mbp-speaker-volume.login"
launchctl bootout "$domain/$label" 2>/dev/null || true
launchctl enable "$domain/$label"
launchctl bootstrap "$domain" "$agent"
print -r -- "Installed: $target"
print -r -- "Login startup: $agent"
