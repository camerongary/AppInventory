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
    <string>15.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Stamp the current version into the bundle.
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" \
                        -c "Set :CFBundleShortVersionString $VERSION" \
                        "$APP_DIR/Info.plist"

# App Intents metadata (Shortcuts discovery). SwiftPM doesn't run Xcode's
# extractor build phase, so emit compiler const-values and invoke it manually.
TC="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain"
SDK="$(xcrun --show-sdk-path)"
AIM_TMP=$(mktemp -d)
plutil -extract constValueProtocols json -o "$AIM_TMP/protos.json" \
    "$TC/usr/share/swift/SwiftConstantValues/AppIntents.json"
xcrun swiftc -typecheck Sources/AppInventory/*.swift \
    -sdk "$SDK" -target arm64-apple-macos15.0 -wmo -module-name AppInventory \
    -const-gather-protocols-list "$AIM_TMP/protos.json" \
    -emit-const-values-path "$AIM_TMP/AppInventory.swiftconstvalues"
ls Sources/AppInventory/*.swift > "$AIM_TMP/sources.txt"
echo "$AIM_TMP/AppInventory.swiftconstvalues" > "$AIM_TMP/constvals.txt"
xcrun appintentsmetadataprocessor \
    --output "$APP_DIR/Resources" \
    --toolchain-dir "$TC" --module-name AppInventory --sdk-root "$SDK" \
    --xcode-version "$(xcodebuild -version | tail -1 | awk '{print $3}')" \
    --platform-family macOS --deployment-target 15.0 \
    --target-triple arm64-apple-macos15.0 \
    --source-file-list "$AIM_TMP/sources.txt" \
    --swift-const-vals-list "$AIM_TMP/constvals.txt" \
    --force --quiet-warnings > /dev/null 2>&1
rm -rf "$AIM_TMP"
if [ -f "$APP_DIR/Resources/Metadata.appintents/extract.actionsdata" ]; then
    echo "App Intents metadata embedded"
else
    echo "WARNING: App Intents metadata missing — Shortcuts actions won't appear"
fi

# Sign with the user's Apple Development identity. A stable signature keeps
# TCC/Gatekeeper grants across rebuilds (ad-hoc identities change every build).
# Falls back to ad-hoc if the certificate is missing/expired so builds never break.
SIGN_IDENTITY="Apple Development: cameron@camerongary.com (NL2W63U24F)"
if security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP_NAME.app"
    echo "Signed: $SIGN_IDENTITY"
else
    codesign --force --sign - "$APP_NAME.app"
    echo "Signed: ad-hoc (development certificate not found)"
fi

echo "Built: $(pwd)/$APP_NAME.app (v$VERSION)"

# Install to /Applications. Remove the destination FIRST — otherwise `cp -R src dst`
# copies INTO the existing bundle, creating a stale nested AppInventory.app/AppInventory.app.
DEST="/Applications/$APP_NAME.app"
rm -rf "$DEST"
cp -R "$APP_NAME.app" "$DEST"
echo "Installed: $DEST"
