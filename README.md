# App Inventory

A native macOS (SwiftUI) app that inventories the non-Apple applications installed on your Mac — handy when rebuilding a machine.

For each app it reports:

- **Architecture** — Apple Silicon, Intel, or Universal (read via `Bundle.executableArchitectures`)
- **Source** — the distribution channel, determined from the code signature and
  download metadata: **App Store**, **Downloaded**, or **Self-Built**
- **Signing** — the kind of certificate: **Developer ID**, **App Store**,
  **Development**, or **None**
- **Signed By** — the developer name from the signing certificate
- Version, Bundle ID, and full path

## Features

- Scans `/Applications`, `~/Applications`, and `/Applications/Utilities`
- Sortable columns, search (⌘F), and filters by architecture and source — sort and
  filters are remembered across launches
- **Website** column with a clickable link to re-download each app
- Remembers your last scan and shows it on launch
- Full menu-bar command model: Scan (⌘R), Export as CSV (⌘E) / JSON / PDF, and an
  **Inventory** menu with Show in Finder (⌘⇧R) and Open (⌘O)
- Select multiple rows; **drag them to Finder, Terminal, or an editor**, or copy
  with ⌘C (file URL + path)
- Right-click a row: **Show in Finder**, **Open**, **Open Download Website**,
  **Copy Path**, **Copy Bundle ID**
- Export your inventory as **CSV**, **JSON**, or **PDF** (the PDF keeps the website links clickable), plus **Copy List** for a quick rebuild checklist
- VoiceOver-friendly: nothing is conveyed by color alone

## Download

Grab the latest `.dmg` from the [Releases](https://github.com/camerongary/AppInventory/releases)
page, open it, and drag **App Inventory** to Applications. The app is signed with an
Apple Development certificate (not Developer ID, and not notarized), so on first
launch right-click it and choose **Open** to get past Gatekeeper's prompt.

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
auto-increments the patch component on commits that change app code (documentation-only
commits don't bump it). Enable it once after cloning:

```sh
git config core.hooksPath .githooks
```

## Requirements

- macOS 15+
- Swift 5.9+ toolchain

## Acknowledgments

Developed collaboratively with [Claude Code](https://claude.com/claude-code)
(Anthropic's Claude Opus 4.8), which contributed the application code, the icon
generator, and the build tooling. Individual contributions are recorded via
`Co-Authored-By` trailers in the commit history.
