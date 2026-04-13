#!/bin/bash
# build_app.sh — Builds the Ponude app and packages it as a proper macOS .app bundle
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Ponude"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/build/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "🔨 Building ${APP_NAME}..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/${APP_NAME}" "$MACOS_DIR/${APP_NAME}"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Ponude</string>
    <key>CFBundleDisplayName</key>
    <string>Ponude</string>
    <key>CFBundleIdentifier</key>
    <string>hr.lotusrc.ponude</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>Ponude</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
PLIST

# Create icon from source image if sips is available
ICON_SOURCE="$SCRIPT_DIR/AppIcon.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Creating app icon..."
    ICONSET_DIR="$SCRIPT_DIR/build/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # Generate all required icon sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null 2>&1
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null 2>&1
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null 2>&1
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1
    
    # Convert iconset to icns
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "  ✓ AppIcon.icns created"
else
    echo "  ⚠ No AppIcon.png found, skipping icon creation"
fi

# Copy bundled resources (logos, templates)
echo "📋 Copying resources..."
RESOURCES_SRC="$SCRIPT_DIR/Ponude/Resources"
if [ -d "$RESOURCES_SRC" ]; then
    for f in "$RESOURCES_SRC"/*.png "$RESOURCES_SRC"/*.html "$RESOURCES_SRC"/*.json; do
        [ -f "$f" ] && cp "$f" "$RESOURCES_DIR/" && echo "  ✓ $(basename "$f")"
    done
fi

# Fallback: copy root-level logo PNGs if not already in Resources
for logo in "$SCRIPT_DIR"/lotusrc.png "$SCRIPT_DIR"/varazdinstudio.png; do
    if [ -f "$logo" ] && [ ! -f "$RESOURCES_DIR/$(basename "$logo")" ]; then
        cp "$logo" "$RESOURCES_DIR/" && echo "  ✓ $(basename "$logo") (from project root)"
    fi
done

# Code-sign with entitlements (required for WKWebView PDF export)
ENTITLEMENTS="$SCRIPT_DIR/Ponude/Ponude.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    echo "🔏 Code-signing with entitlements..."
    codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
    echo "  ✓ Signed with entitlements"
else
    echo "  ⚠ No entitlements file found, signing without entitlements"
    codesign --force --sign - "$APP_BUNDLE"
fi

echo ""
echo "✅ ${APP_NAME}.app built successfully!"
echo "   Location: $APP_BUNDLE"
echo ""
echo "🚀 Launching..."
open "$APP_BUNDLE"
