#!/bin/bash

# ESPP Manager macOS Build Script
# Erstellt einen signierten und notarisierten Build für macOS

set -e

echo "🚀 Starting ESPP Manager macOS Build..."

# Build the Flutter app
echo "📦 Building Flutter app..."
flutter build macos --release

# Variables
APP_NAME="ESPP Manager"
APP_PATH="build/macos/Build/Products/Release/$APP_NAME.app"
DMG_NAME="ESPP-Manager-macOS.dmg"
TEAM_ID="V7QY567836"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    exit 1
fi

# Sign the app
echo "✍️ Signing app..."
codesign --deep --force --verify --verbose --sign "$TEAM_ID" --options runtime "$APP_PATH"

# Create DMG
echo "💿 Creating DMG..."
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --app-drop-link 450 185 \
        "$DMG_NAME" \
        "$APP_PATH"
else
    echo "⚠️ create-dmg not found, creating simple DMG..."
    hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_NAME"
fi

# Sign the DMG
echo "✍️ Signing DMG..."
codesign --force --sign "$TEAM_ID" "$DMG_NAME"

echo "✅ Build complete! DMG created: $DMG_NAME"
echo ""
echo "📝 Next steps for notarization:"
echo "1. xcrun notarytool submit $DMG_NAME --apple-id miboomers@gmail.com --team-id $TEAM_ID --wait"
echo "2. xcrun stapler staple $DMG_NAME"