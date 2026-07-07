import Foundation
import Security

/// The headless scanning core, shared by the UI (`AppScanner`) and the App
/// Intents. Runs off the main actor; all Security/file work happens here.
enum ScanEngine {

    // MARK: - Scan

    static func scan(progress: (@Sendable (String) -> Void)? = nil) async -> [AppInfo] {
        let searchURLs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
        ]

        var discovered: [AppInfo] = []
        for baseURL in searchURLs {
            guard FileManager.default.fileExists(atPath: baseURL.path) else { continue }
            discovered.append(contentsOf: scanDirectory(baseURL, progress: progress))
        }

        // Deduplicate by bundle ID (keep first occurrence)
        var seen = Set<String>()
        let unique = discovered.filter { info in
            let key = info.bundleID.isEmpty ? info.path.path : info.bundleID
            return seen.insert(key).inserted
        }

        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Cache

    /// Wrapper persisted to disk so the previous scan can be shown on next launch.
    struct CachedScan: Codable {
        let date: Date
        let apps: [AppInfo]
    }

    private static var cacheURL: URL? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("AppInventory", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-scan.json")
    }

    static func loadCache() -> CachedScan? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedScan.self, from: data) else { return nil }
        return cached
    }

    static func saveCache(_ cached: CachedScan) {
        guard let url = cacheURL,
              let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Discovery

    private static let appleAppNames = Set([
        "Automator", "Books", "Calculator", "Calendar", "Chess",
        "Contacts", "Dictionary", "DVD Player", "FaceTime", "Feedback Assistant",
        "Find My", "Finder", "Font Book", "Freeform", "GarageBand", "Home",
        "Image Capture", "Instruments", "iPhone Mirroring", "Keynote", "Launchpad",
        "Mail", "Maps", "Messages", "Mission Control", "Music", "News",
        "Notes", "Numbers", "Pages", "Photo Booth", "Photos", "Podcasts",
        "Preview", "QuickTime Player", "Reminders", "Safari", "Shortcuts",
        "Siri", "Stickies", "Stocks", "System Information", "System Preferences",
        "System Settings", "TextEdit", "Time Machine", "TV", "Voice Memos",
        "VoiceOver Utility", "Weather", "Xcode", "Grapher",
        "Activity Monitor", "AirPort Utility", "Archive Utility", "Audio MIDI Setup",
        "Bluetooth Screen Lock", "Boot Camp Assistant", "ColorSync Utility",
        "Console", "DigitalColor Meter", "Directory Utility", "Disk Diag",
        "Disk Utility", "FileMerge", "Keychain Access", "Migration Assistant",
        "Network Utility", "RAID Utility", "Remote Desktop", "Screen Sharing",
        "Screenshot", "Simulator", "Terminal", "Ticket Viewer", "Wireless Diagnostics",
    ])

    private static func scanDirectory(
        _ directory: URL, progress: (@Sendable (String) -> Void)?
    ) -> [AppInfo] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var appURLs: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else { continue }
            enumerator.skipDescendants()
            appURLs.append(url)
        }

        var results: [AppInfo] = []
        for url in appURLs {
            progress?(url.lastPathComponent)
            if let info = buildAppInfo(url) {
                results.append(info)
            }
        }
        return results
    }

    private static func buildAppInfo(_ appURL: URL) -> AppInfo? {
        let infoPlistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard let plist = NSDictionary(contentsOf: infoPlistURL) else { return nil }

        let bundleID = plist["CFBundleIdentifier"] as? String ?? ""
        let name = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        let version = plist["CFBundleShortVersionString"] as? String
            ?? plist["CFBundleVersion"] as? String
            ?? ""

        guard !isAppleApp(bundleID: bundleID, name: name) else { return nil }

        let arch = detectArchitecture(appURL)
        let receiptExists = FileManager.default.fileExists(
            atPath: appURL.appendingPathComponent("Contents/_MASReceipt/receipt").path
        )
        let whereFrom = whereFromURL(appURL)
        let (source, signing, developer) = detectSource(
            appURL, hasReceipt: receiptExists, wasDownloaded: whereFrom != nil)
        let website = whereFrom ?? homepageWebsite(bundleID: bundleID, signing: signing)

        return AppInfo(
            name: name,
            path: appURL,
            bundleID: bundleID,
            version: version,
            architecture: arch,
            source: source,
            signing: signing,
            developer: developer,
            website: website
        )
    }

    private static func isAppleApp(bundleID: String, name: String) -> Bool {
        if bundleID.hasPrefix("com.apple.") { return true }
        if appleAppNames.contains(name) { return true }
        return false
    }

    // MARK: - Architecture Detection

    /// Uses Bundle.executableArchitectures, which correctly reads both thin and
    /// fat (Universal) Mach-O headers — unlike hand-rolled byte parsing.
    private static func detectArchitecture(_ appURL: URL) -> AppInfo.Architecture {
        guard let bundle = Bundle(url: appURL),
              let archs = bundle.executableArchitectures?.map({ $0.intValue }),
              !archs.isEmpty else { return .unknown }

        let hasARM = archs.contains(NSBundleExecutableArchitectureARM64)
        let hasIntel = archs.contains(NSBundleExecutableArchitectureX86_64)

        if hasARM && hasIntel { return .universal }
        if hasARM { return .appleSilicon }
        if hasIntel { return .intel }
        return .unknown
    }

    // MARK: - Source Detection

    /// Determines the distribution channel and signing kind from the code signature,
    /// which (unlike the quarantine xattr) survives first launch. The two are separate
    /// facts: the channel says where the app came from; the signing kind says what
    /// certificate vouches for it. Returns (channel, signing, developer name).
    private static func detectSource(
        _ appURL: URL, hasReceipt: Bool, wasDownloaded: Bool
    ) -> (AppInfo.AppSource, AppInfo.SigningKind, String) {
        guard let authority = signingLeafName(appURL) else {
            // Unsigned/ad-hoc: download metadata is the only channel evidence left;
            // without it, on this machine an unsigned app is almost always self-built.
            if hasReceipt { return (.appStore, .none, "") }
            return (wasDownloaded ? .downloaded : .selfBuilt, .none, "")
        }

        if hasReceipt || authority.hasPrefix("Apple Mac OS Application Signing") {
            return (.appStore, .appStore, "")
        }
        if authority.hasPrefix("Developer ID Application:") {
            return (.downloaded, .developerID, developerName(from: authority))
        }
        if authority.hasPrefix("Apple Development") || authority.hasPrefix("Apple Distribution") {
            return (.selfBuilt, .development, developerName(from: authority))
        }
        return (wasDownloaded ? .downloaded : .unknown, .other, "")
    }

    /// Common name of the leaf (signing) certificate, e.g.
    /// "Developer ID Application: Mozilla Corporation (43AQ936H96)". nil if unsigned.
    private static func signingLeafName(_ appURL: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return nil }

        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any],
              let certs = dict[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certs.first else { return nil }

        var commonName: CFString?
        guard SecCertificateCopyCommonName(leaf, &commonName) == errSecSuccess else { return nil }
        return commonName as String?
    }

    /// Extracts the human-readable developer name from a signing authority string,
    /// e.g. "Developer ID Application: Mozilla Corporation (43AQ936H96)" -> "Mozilla Corporation".
    private static func developerName(from authority: String) -> String {
        guard let colon = authority.firstIndex(of: ":") else { return "" }
        var name = String(authority[authority.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        if let paren = name.range(of: " (") {
            name = String(name[..<paren.lowerBound])
        }
        return name
    }

    // MARK: - Download Website

    /// Fallback website when no "where from" metadata survives: the developer's site
    /// derived from the bundle ID — but only for signed apps, where the bundle ID is
    /// a real reverse-DNS domain rather than a self-built placeholder.
    private static func homepageWebsite(bundleID: String, signing: AppInfo.SigningKind) -> String {
        switch signing {
        case .appStore, .developerID, .development:
            return homepage(fromBundleID: bundleID) ?? ""
        case .other, .none:
            return ""
        }
    }

    /// Reads the `kMDItemWhereFroms` quarantine metadata (a binary plist stored as an
    /// extended attribute) and returns the first http(s) URL, if any.
    private static func whereFromURL(_ url: URL) -> String? {
        let name = "com.apple.metadata:kMDItemWhereFroms"
        let length = getxattr(url.path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }

        var data = Data(count: length)
        let read = data.withUnsafeMutableBytes { buf in
            getxattr(url.path, name, buf.baseAddress, length, 0, 0)
        }
        guard read > 0 else { return nil }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let urls = plist as? [String] else { return nil }
        return urls.first { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
    }

    /// Derives a developer homepage from a reverse-DNS bundle ID,
    /// e.g. "org.mozilla.firefox" -> "https://mozilla.org",
    ///      "uk.co.tla-systems.pcalc" -> "https://tla-systems.co.uk".
    private static func homepage(fromBundleID id: String) -> String? {
        let parts = id.split(separator: ".").map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }

        // Handle country-code domains with a second level, e.g. "uk.co.<org>".
        let secondLevels: Set<String> = ["co", "com", "org", "net", "ac", "gov", "edu", "ne", "or"]
        let labels: [String]
        if parts[0].count == 2, parts.count >= 3, secondLevels.contains(parts[1].lowercased()) {
            labels = Array(parts[0...2])
        } else {
            labels = Array(parts[0...1])
        }

        let domain = labels.reversed().joined(separator: ".").lowercased()
        // Skip obviously non-domain placeholders used by self-built apps.
        guard domain.contains(".") else { return nil }
        return "https://\(domain)"
    }
}
