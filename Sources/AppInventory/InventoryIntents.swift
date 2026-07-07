import AppIntents
import Foundation

/// Shortcuts action: run a fresh scan and return the number of apps found.
struct ScanAppsIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Apps"
    static let description = IntentDescription("Scans this Mac for non-Apple applications and returns the number found. The result is saved and shown the next time App Inventory opens.")

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let apps = await ScanEngine.scan()
        ScanEngine.saveCache(.init(date: Date(), apps: apps))
        return .result(value: apps.count,
                       dialog: "Found \(apps.count) third-party apps.")
    }
}

enum InventoryExportFormat: String, AppEnum {
    case json
    case csv

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Format"
    static let caseDisplayRepresentations: [InventoryExportFormat: DisplayRepresentation] = [
        .json: "JSON",
        .csv: "CSV",
    ]
}

/// Shortcuts action: return the inventory as a file (from the latest saved
/// scan, scanning first if none exists).
struct GetInventoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get App Inventory"
    static let description = IntentDescription("Returns the app inventory as a CSV or JSON file, using the most recent scan (or scanning first if none has been saved).")

    @Parameter(title: "Format", default: .json)
    var format: InventoryExportFormat

    @Parameter(title: "Rescan First",
               description: "Run a fresh scan instead of using the saved one.",
               default: false)
    var rescanFirst: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Get app inventory as \(\.$format)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let apps: [AppInfo]
        if !rescanFirst, let cached = ScanEngine.loadCache(), !cached.apps.isEmpty {
            apps = cached.apps
        } else {
            apps = await ScanEngine.scan()
            ScanEngine.saveCache(.init(date: Date(), apps: apps))
        }

        switch format {
        case .csv:
            let content = AppInfo.csvHeader + "\n"
                + apps.map(\.csvRow).joined(separator: "\n")
            return .result(value: IntentFile(
                data: Data(content.utf8), filename: "AppInventory.csv"))
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(apps.map(\.exportItem))
            return .result(value: IntentFile(data: data, filename: "AppInventory.json"))
        }
    }
}

struct AppInventoryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanAppsIntent(),
            phrases: ["Scan apps with \(.applicationName)"],
            shortTitle: "Scan Apps",
            systemImageName: "arrow.clockwise")
        AppShortcut(
            intent: GetInventoryIntent(),
            phrases: ["Get app inventory from \(.applicationName)"],
            shortTitle: "Get Inventory",
            systemImageName: "square.and.arrow.up")
    }
}
