#!/bin/bash
# Build AppInventory.app and package it into a distributable DMG with a
# drag-to-Applications layout. Output: AppInventory-<version>.dmg
set -e

APP_NAME="AppInventory"
VOL_NAME="App Inventory"

VERSION="1.0"
[ -f VERSION ] && VERSION=$(tr -d '[:space:]' < VERSION)

# Build the app bundle first.
bash build_app.sh

DMG="${APP_NAME}-${VERSION}.dmg"
STAGE=$(mktemp -d)

# Stage the app plus a symlink to /Applications for drag-installation.
cp -R "$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG"

rm -rf "$STAGE"
echo "Created: $(pwd)/$DMG"
