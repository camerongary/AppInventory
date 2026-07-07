import Foundation

/// UI-facing scan state. The actual scanning lives in `ScanEngine`, shared
/// with the App Intents so Shortcuts can scan without the window.
@MainActor
class AppScanner: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var isScanning = false
    @Published var scanProgress = ""
    @Published var totalScanned = 0
    @Published var lastScanDate: Date?

    init() {
        if let cached = ScanEngine.loadCache() {
            apps = cached.apps
            lastScanDate = cached.date
            scanProgress = "Loaded \(apps.count) apps from last scan"
        }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        apps = []
        totalScanned = 0

        Task {
            let found = await ScanEngine.scan { appName in
                Task { @MainActor in
                    self.scanProgress = "Scanning \(appName)..."
                    self.totalScanned += 1
                }
            }
            apps = found
            lastScanDate = Date()
            isScanning = false
            scanProgress = "Found \(apps.count) third-party apps"
            ScanEngine.saveCache(.init(date: lastScanDate ?? Date(), apps: apps))
        }
    }
}
