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
- **Website** column with a clickable link to re-download each app
- Remembers your last scan and shows it on launch
- Right-click a row: **Show in Finder**, **Open**, **Copy Path**, **Copy Bundle ID**
- Export your inventory as **CSV**, **JSON**, or **PDF** (the PDF keeps the website links clickable), plus **Copy List** for a quick rebuild checklist

## Download

Grab the latest `.dmg` from the [Releases](https://github.com/camerongary/AppInventory/releases)
page, open it, and drag **App Inventory** to Applications. The app is ad-hoc signed
(no Developer ID), so on first launch right-click it and choose **Open** to get past
Gatekeeper's "unidentified developer" prompt.

## Building

```sh
swift build -c release      # build only
bash build_app.sh           # build, bundle into AppInventory.app, install to /Applications
bash make_dmg.sh            # build + package into AppInventory-<version>.dmg
```

The app icon is generated from [`make_icon.py`](make_icon.py); `build_app.sh` bundles `AppIcon.icns`.

## Versioning

The version lives in the [`VERSION`](VERSION) file (single source of truth, stamped into
the bundle by `build_app.sh`). A tracked pre-commit hook ([`.githooks/pre-commit`](.githooks/pre-commit))
auto-increments the patch component on every commit. Enable it once after cloning:

```sh
git config core.hooksPath .githooks
```

## Requirements

- macOS 13+
- Swift 5.9+ toolchain

## Acknowledgments

Developed collaboratively with [Claude Code](https://claude.com/claude-code)
(Anthropic's Claude Opus 4.8), which contributed the application code, the icon
generator, and the build tooling. Individual contributions are recorded via
`Co-Authored-By` trailers in the commit history.
