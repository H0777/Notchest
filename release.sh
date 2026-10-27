#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")"
APP="$PROJECT_DIR/dist/Notchest.app"
"$PROJECT_DIR/build.sh" "$APP"

ZIP="$PROJECT_DIR/dist/Notchest-$VERSION.zip"
rm -f "$ZIP"
# ditto preserves executable permissions and the ad-hoc code signature.
ditto -c -k --keepParent "$APP" "$ZIP"

DMG="$PROJECT_DIR/dist/Notchest-$VERSION.dmg"
rm -f "$DMG"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/notchest-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
# A symlink, not a copy: this is the Applications arrow users drag the app onto.
ln -s /Applications "$STAGING/Applications"
ditto "$APP" "$STAGING/Notchest.app"
hdiutil create -volname "Notchest" -srcfolder "$STAGING" -ov -format UDZO "$DMG" -quiet

print "Release artifacts:"
print "  $ZIP"
print "  $DMG"
