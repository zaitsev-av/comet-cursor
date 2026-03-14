#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
APP="Comet Cursor.app"
DMG_NAME="CometCursor-${VERSION}.dmg"
STAGING="/tmp/comet-dmg-staging"

echo "Building app..."
../scripts/build.sh

echo "Creating DMG staging area..."
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -r "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "Creating DMG..."
hdiutil create \
    -volname "Comet Cursor" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "/tmp/${DMG_NAME}"

mv "/tmp/${DMG_NAME}" "./${DMG_NAME}"
rm -rf "$STAGING"

echo ""
echo "Done: ${DMG_NAME} ($(du -sh "${DMG_NAME}" | cut -f1))"
