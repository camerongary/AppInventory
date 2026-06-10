#!/bin/bash
set -e

APP_NAME="AppInventory"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app/Contents"

# Version: single source of truth in the VERSION file (auto-bumped per commit).
VERSION="1.0"
[ -f VERSION ] && VERSION=$(tr -d '[:space:]' < VERSION)

# Build
swift build -c release

# Create bundle structure
rm -rf "$APP_NAME.app"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/MacOS/$APP_NAME"

# Copy app icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_DIR/Resources/AppIcon.icns"
fi

# Write Info.plist
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AppInventory</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.cameron.appinventory</string>
    <key>CFBundleName</key>
    <string>App Inventory</string>
    <key>CFBundleDisplayName</key>
    <string>App Inventory</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Stamp the current version into the bundle.
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" \
                        -c "Set :CFBundleShortVersionString $VERSION" \
                        "$APP_DIR/Info.plist"

echo "Built: $(pwd)/$APP_NAME.app (v$VERSION)"

# Install to /Applications. Remove the destination FIRST — otherwise `cp -R src dst`
# copies INTO the existing bundle, creating a stale nested AppInventory.app/AppInventory.app.
DEST="/Applications/$APP_NAME.app"
rm -rf "$DEST"
cp -R "$APP_NAME.app" "$DEST"
echo "Installed: $DEST"
