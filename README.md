# App Inventory

A native macOS (SwiftUI) app that inventories the non-Apple applications installed on your Mac — handy when rebuilding a machine.

For each app it reports:

- **Architecture** — Apple Silicon, Intel, or Universal (read via `Bundle.executableArchitectures`)
- **Source** — where it came from, determined from the code signature:
  - **App Store** (Mac App Store signing / `_MASReceipt`)
  - **Developer ID** (signed by a known developer — downloaded from their site)
  - **Development** (Apple Development/Distribution signed)
  - **Unsigned / Self-Built**
- **Signed By** — the developer name from the signing certificate
- Version, Bundle ID, and full path

## Features

- Scans `/Applications`, `~/Applications`, and `/Applications/Utilities`
- Sortable columns, search, and filters by architecture and source
- Right-click a row: **Show in Finder**, **Open**, **Copy Path**, **Copy Bundle ID**
- **Export CSV** and **Copy List** for your rebuild checklist

## Building

```sh
swift build -c release      # build only
bash build_app.sh           # build, bundle into AppInventory.app, install to /Applications
```

The app icon is generated from [`make_icon.py`](make_icon.py); `build_app.sh` bundles `AppIcon.icns`.

## Requirements

- macOS 13+
- Swift 5.9+ toolchain
