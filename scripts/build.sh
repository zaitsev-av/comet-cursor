#!/bin/bash
set -e

echo "Сборка CometCursor..."
swift build -c release

BINARY=".build/release/CometCursorApp"
APP="Comet Cursor.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BINARY"                    "$APP/Contents/MacOS/CometCursor"
cp "Resources/Info.plist"       "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns"     "$APP/Contents/Resources/AppIcon.icns"

codesign --deep --force --sign - "$APP"

echo "✓ Собрано: $APP"
echo "  Запуск:  open \"$APP\""
