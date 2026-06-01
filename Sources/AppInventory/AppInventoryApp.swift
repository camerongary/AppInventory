import SwiftUI

@main
struct AppInventoryApp: App {
    var body: some Scene {
        WindowGroup("App Inventory") {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
