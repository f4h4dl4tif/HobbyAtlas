#!/bin/bash
# Builds HobbyAtlas.app (Apple Silicon) and wraps it for distribution:
# dist/HobbyAtlas-<version>.pkg, .zip (pkg + guide), .dmg and a loose "How to Install.txt".
# build.sh only targets arm64, so this package is Apple Silicon only.
set -euo pipefail
cd "$(dirname "$0")"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
./build.sh
ARCHS=$(lipo -archs build/HobbyAtlas.app/Contents/MacOS/HobbyAtlas)
[ "$ARCHS" = "arm64" ] || { echo "Expected an arm64 binary, got: $ARCHS"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/HobbyAtlas.app/Contents/Info.plist)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root/Applications" dist
cp -R build/HobbyAtlas.app "$WORK/root/Applications/"

# Always install into /Applications, even if another copy of HobbyAtlas exists elsewhere on the Mac.
pkgbuild --analyze --root "$WORK/root" "$WORK/components.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$WORK/components.plist"

pkgbuild --root "$WORK/root" \
  --component-plist "$WORK/components.plist" \
  --scripts Installer/scripts \
  --identifier local.hobbyatlas.app.pkg \
  --version "$VERSION" \
  --install-location / \
  "$WORK/HobbyAtlas-component.pkg" >/dev/null

cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>HobbyAtlas</title>
    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64"/>
    <domains enable_localSystem="true"/>
    <volume-check>
        <allowed-os-versions><os-version min="14.0"/></allowed-os-versions>
    </volume-check>
    <choices-outline><line choice="default"><line choice="app"/></line></choices-outline>
    <choice id="default"/>
    <choice id="app" visible="false"><pkg-ref id="local.hobbyatlas.app.pkg"/></choice>
    <pkg-ref id="local.hobbyatlas.app.pkg" version="$VERSION" onConclusion="none">HobbyAtlas-component.pkg</pkg-ref>
</installer-gui-script>
XML

OUT="dist/HobbyAtlas-$VERSION.pkg"
productbuild --distribution "$WORK/distribution.xml" \
  --resources Installer/resources \
  --package-path "$WORK" \
  "$OUT" >/dev/null

echo "Created $(pwd)/$OUT ($(du -h "$OUT" | cut -f1))"

# Ship the install guide next to the package: as a loose file and in a zip with the .pkg.
GUIDE="Installer/How to Install.txt"
cp "$GUIDE" "dist/How to Install.txt"
ZIPDIR="$WORK/HobbyAtlas-$VERSION"
mkdir -p "$ZIPDIR"
cp "$OUT" "$GUIDE" "$ZIPDIR/"
ZIP="dist/HobbyAtlas-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --keepParent "$ZIPDIR" "$ZIP"
echo "Created $(pwd)/$ZIP (installer + How to Install.txt)"

# Also make a drag-to-Applications disk image from the same build.
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
cp -R build/HobbyAtlas.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$GUIDE" "$STAGE/"
DMG="dist/HobbyAtlas-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "HobbyAtlas" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
echo "Created $(pwd)/$DMG ($(du -h "$DMG" | cut -f1))"
