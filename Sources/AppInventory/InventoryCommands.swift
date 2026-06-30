import SwiftUI

/// Actions the active inventory window exposes to the menu bar. ContentView
/// publishes this via `.focusedSceneValue`; the menu commands read it so every
/// toolbar/context action is also reachable (and shortcut-driven) from the menus.
struct InventoryActions {
    var isScanning: Bool
    var hasApps: Bool
    var hasSelection: Bool
    var scan: () -> Void
    var exportCSV: () -> Void
    var exportJSON: () -> Void
    var exportPDF: () -> Void
    var copyList: () -> Void
    var showInFinder: () -> Void
    var openSelected: () -> Void
}

private struct InventoryActionsKey: FocusedValueKey {
    typealias Value = InventoryActions
}

extension FocusedValues {
    var inventoryActions: InventoryActions? {
        get { self[InventoryActionsKey.self] }
        set { self[InventoryActionsKey.self] = newValue }
    }
}

struct InventoryCommands: Commands {
    @FocusedValue(\.inventoryActions) private var actions

    var body: some Commands {
        // Scan sits with File's "New"-style commands.
        CommandGroup(after: .newItem) {
            Button("Scan for Apps") { actions?.scan() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions?.isScanning ?? true)
        }

        // Exports go in File's Import/Export section.
        CommandGroup(after: .importExport) {
            Button("Export as CSV…") { actions?.exportCSV() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!(actions?.hasApps ?? false))
            Button("Export as JSON…") { actions?.exportJSON() }
                .disabled(!(actions?.hasApps ?? false))
            Button("Export as PDF…") { actions?.exportPDF() }
                .disabled(!(actions?.hasApps ?? false))
        }

        // Domain menu for selection/list actions.
        CommandMenu("Inventory") {
            Button("Show in Finder") { actions?.showInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!(actions?.hasSelection ?? false))
            Button("Open") { actions?.openSelected() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(!(actions?.hasSelection ?? false))
            Divider()
            Button("Copy List") { actions?.copyList() }
                .disabled(!(actions?.hasApps ?? false))
        }
    }
}
