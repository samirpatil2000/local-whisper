#!/bin/bash
set -e

APP_NAME="LocalWhisper"
BUNDLE_ID="com.localwhisper.app"
DEPLOY_TARGET="26.0"

echo "🧹 Cleaning up old build..."
rm -rf build
mkdir -p build/${APP_NAME}.app/Contents/MacOS
mkdir -p build/${APP_NAME}.app/Contents/Resources

echo "🔨 Compiling Swift files..."
swiftc \
  -sdk $(xcrun --show-sdk-path --sdk macosx) \
  -target $(uname -m)-apple-macosx${DEPLOY_TARGET} \
  -parse-as-library \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Speech \
  -framework AVFoundation \
  -framework ApplicationServices \
  -framework FoundationModels \
  LocalWhisper/*.swift \
  -o build/${APP_NAME}.app/Contents/MacOS/${APP_NAME}

echo "📋 Creating Info.plist..."
cp LocalWhisper/Info.plist build/${APP_NAME}.app/Contents/Info.plist

echo "📦 Writing PkgInfo..."
echo "APPL????" > build/${APP_NAME}.app/Contents/PkgInfo

echo "🔏 Code signing..."
codesign --force --deep --sign - --entitlements LocalWhisper/LocalWhisper.entitlements build/${APP_NAME}.app

echo "🧼 Removing quarantine attribute..."
xattr -cr build/${APP_NAME}.app

echo "🔗 Adding Applications shortcut to DMG folder..."
ln -s /Applications build/Applications

echo "💿 Creating DMG..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder build \
  -ov \
  -format UDZO \
  LocalWhisper_Release.dmg

echo "🧼 Removing quarantine from DMG..."
xattr -cr LocalWhisper_Release.dmg

echo ""
echo "✅ Done! DMG is located at: LocalWhisper_Release.dmg"
echo "   If macOS still complains, run:  xattr -cr /path/to/LocalWhisper.app"
