#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
DESTINATION="${1:-$PROJECT_DIR/dist/Notchest.app}"
BUILD_DIR="${NOTCHEST_BUILD_DIR:-$PROJECT_DIR/.build}"
swift build --package-path "$PROJECT_DIR" --scratch-path "$BUILD_DIR" -c release
BIN_DIR="$(swift build --package-path "$PROJECT_DIR" --scratch-path "$BUILD_DIR" -c release --show-bin-path)"
mkdir -p "$DESTINATION/Contents/MacOS" "$DESTINATION/Contents/Resources"
cp "$BIN_DIR/Notchest" "$DESTINATION/Contents/MacOS/Notchest"
cp "$BIN_DIR/NotchestCommand" "$DESTINATION/Contents/MacOS/NotchestCommand"
cp "$PROJECT_DIR/Resources/Info.plist" "$DESTINATION/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/SwiftTerm-LICENSE.txt" "$DESTINATION/Contents/Resources/SwiftTerm-LICENSE.txt"
if [[ -f "$PROJECT_DIR/Resources/Notchest.icns" ]]; then
  cp "$PROJECT_DIR/Resources/Notchest.icns" "$DESTINATION/Contents/Resources/Notchest.icns"
fi
codesign --force --sign - "$DESTINATION/Contents/MacOS/NotchestCommand"
codesign --force --sign - "$DESTINATION"
print "Built: $DESTINATION"
