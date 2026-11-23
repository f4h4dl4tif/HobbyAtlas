#!/bin/zsh
# Builds HobbyAtlas.app (Apple Silicon) into build/. Needs only the Xcode Command Line Tools.
set -e
cd "$(dirname "$0")"
APP=build/HobbyAtlas.app
rm -rf "$APP" build/HobbyAtlas.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Newer SDKs implement @State as a macro; the Command Line Tools can't find its plugin, so prefer Xcode when present.
[[ -d /Applications/Xcode.app ]] && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos14.0 Sources/*.swift -o "$APP/Contents/MacOS/HobbyAtlas"

swift Tools/make_icon.swift build/HobbyAtlas.iconset
iconutil -c icns build/HobbyAtlas.iconset -o "$APP/Contents/Resources/HobbyAtlas.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>HobbyAtlas</string>
  <key>CFBundleDisplayName</key><string>HobbyAtlas</string>
  <key>CFBundleIdentifier</key><string>local.hobbyatlas.app</string>
  <key>CFBundleExecutable</key><string>HobbyAtlas</string>
  <key>CFBundleIconFile</key><string>HobbyAtlas</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>HobbyAtlas</string>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
