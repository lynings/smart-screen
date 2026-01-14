#!/bin/bash
# ==============================================================================
# build-app.sh
# ==============================================================================
# Purpose:
#   Build SmartScreen and package it as a proper .app bundle
#   This allows macOS to recognize the app for permission management
#
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_NAME="SmartScreen"
APP_BUNDLE="$PROJECT_ROOT/$APP_NAME.app"
BUNDLE_ID="com.smartscreen.app"
SIGNING_IDENTITY="SmartScreen Dev"

# ==============================================================================
# Check/Create signing certificate
# ==============================================================================
check_or_create_certificate() {
    if security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
        echo "✅ Found signing certificate: $SIGNING_IDENTITY"
        return 0
    fi
    
    echo "⚠️  No signing certificate found."
    echo ""
    echo "To preserve screen recording permission across rebuilds,"
    echo "please create a self-signed certificate:"
    echo ""
    echo "1. Open Keychain Access"
    echo "2. Menu: Keychain Access > Certificate Assistant > Create a Certificate"
    echo "3. Name: $SIGNING_IDENTITY"
    echo "4. Identity Type: Self Signed Root"
    echo "5. Certificate Type: Code Signing"
    echo "6. Click Create"
    echo ""
    echo "Then run this script again."
    echo ""
    return 1
}

echo "🔨 Building SmartScreen..."
echo "================================"

# 1. Build the executable
cd "$PROJECT_ROOT"
swift build -c release

# 2. Create .app bundle structure
echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy executable
cp "$BUILD_DIR/arm64-apple-macosx/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || \
cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || \
cp "$BUILD_DIR/arm64-apple-macosx/debug/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 4. Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Smart Screen</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>SmartScreen needs screen recording permission to capture your screen.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>SmartScreen needs microphone access to record audio with your screen recordings.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.video</string>
</dict>
</plist>
EOF

# 5. Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# 6. Code sign the app (if certificate exists)
if security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
    echo "🔏 Signing app with '$SIGNING_IDENTITY'..."
    codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
    SIGNED=true
else
    echo "⚠️  Skipping code signing (no certificate)"
    SIGNED=false
fi

echo ""
echo "================================"
echo "✅ Build complete!"
echo ""
echo "📍 App location: $APP_BUNDLE"
echo ""
echo "🚀 To run the app:"
echo "   open $APP_BUNDLE"
echo ""

if [ "$SIGNED" = true ]; then
    echo "🔏 App is signed with '$SIGNING_IDENTITY'"
    echo "   Screen recording permission will persist across rebuilds."
else
    echo "🔐 To preserve permissions across rebuilds:"
    echo "   1. Create a self-signed certificate named '$SIGNING_IDENTITY'"
    echo "      (Keychain Access > Certificate Assistant > Create a Certificate)"
    echo "   2. Re-run this script"
    echo ""
    echo "🔐 To grant Screen Recording permission (one-time):"
    echo "   1. Run the app once"
    echo "   2. Go to System Settings > Privacy & Security > Screen Recording"
    echo "   3. Find 'SmartScreen' and enable it"
fi
echo ""
