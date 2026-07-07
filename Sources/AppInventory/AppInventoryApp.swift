import SwiftUI

@main
struct AppInventoryApp: App {
    var body: some Scene {
        WindowGroup("App Inventory") {
            ContentView()
        }
        .defaultSize(width: 1150, height: 650)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            InventoryCommands()
            CommandGroup(replacing: .help) {
                Link("App Inventory Help",
                     destination: URL(string: "https://github.com/camerongary/AppInventory#readme")!)
                Link("View Project on GitHub",
                     destination: URL(string: "https://github.com/camerongary/AppInventory")!)
            }
        }
    }
}
