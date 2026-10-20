#!/bin/bash
# Builds DeskTasks.app, installs it to ~/Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")"

APP="$HOME/Applications/DeskTasks.app"
pkill -x DeskTasks 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O Model.swift Views.swift Snapshot.swift main.swift -o "$APP/Contents/MacOS/DeskTasks"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DeskTasks</string>
    <key>CFBundleIdentifier</key><string>com.arun.desktasks</string>
    <key>CFBundleExecutable</key><string>DeskTasks</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
open "$APP"
echo "Installed and launched: $APP"
