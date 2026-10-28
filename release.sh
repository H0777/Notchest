#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")"
APP="$PROJECT_DIR/dist/Notchest.app"
"$PROJECT_DIR/build.sh" "$APP"

# Build-time tools stay in an ignored environment; nothing is installed globally or bundled.
TOOLS="$PROJECT_DIR/.build/dmg-tools"
REQUIREMENTS="$PROJECT_DIR/Scripts/dmg-requirements.txt"
if ! "$TOOLS/bin/python" - "$REQUIREMENTS" <<'PY' 2>/dev/null
from importlib.metadata import version
from pathlib import Path
import sys
for line in Path(sys.argv[1]).read_text().splitlines():
    if line.strip() and not line.startswith("#"):
        package, expected = line.split("==")
        if version(package) != expected:
            sys.exit(1)
PY
then
  python3 -m venv "$TOOLS"
  "$TOOLS/bin/python" -m pip install --disable-pip-version-check -r "$REQUIREMENTS"
fi

swift "$PROJECT_DIR/Scripts/generate-installer-art.swift"
STAGING="$(mktemp -d "$PROJECT_DIR/dist/.release.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ZIP="$STAGING/Notchest-$VERSION.zip"
DMG="$STAGING/Notchest-$VERSION.dmg"
# ditto preserves executable permissions and the ad-hoc code signature.
ditto -c -k --keepParent "$APP" "$ZIP"
ditto -x -k "$ZIP" "$STAGING/zip-check"
codesign --verify --deep --strict "$STAGING/zip-check/Notchest.app"
"$TOOLS/bin/python" "$PROJECT_DIR/Scripts/build-dmg.py" "$APP" "$DMG"
"$TOOLS/bin/python" "$PROJECT_DIR/Scripts/check-dmg.py" "$DMG" --app "$APP"

# Replace previous artifacts only after both new packages pass validation.
mv -f "$ZIP" "$PROJECT_DIR/dist/Notchest-$VERSION.zip"
mv -f "$DMG" "$PROJECT_DIR/dist/Notchest-$VERSION.dmg"
print "Release artifacts:"
print "  $PROJECT_DIR/dist/Notchest-$VERSION.zip"
print "  $PROJECT_DIR/dist/Notchest-$VERSION.dmg"
