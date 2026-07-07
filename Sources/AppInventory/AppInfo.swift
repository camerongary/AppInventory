import Foundation
import CoreTransferable

struct AppInfo: Identifiable, Codable {
    var id = UUID()
    let name: String
    let path: URL
    let bundleID: String
    let version: String
    let architecture: Architecture
    let source: AppSource
    let signing: SigningKind
    let developer: String   // signing identity (e.g. "Mozilla Corporation"), or "" if none
    let website: String     // best-effort download/developer URL, or "" if unknown

    enum Architecture: String, CaseIterable, Comparable, Codable {
        case appleSilicon = "Apple Silicon"
        case intel = "Intel"
        case universal = "Universal"
        case unknown = "Unknown"

        static func < (lhs: Architecture, rhs: Architecture) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The distribution channel — where the app came from. One fact per column:
    /// the certificate details live in `signing`/`developer`, not here.
    enum AppSource: String, CaseIterable, Comparable, Codable {
        case appStore = "App Store"
        case downloaded = "Downloaded"
        case selfBuilt = "Self-Built"
        case unknown = "Unknown"

        static func < (lhs: AppSource, rhs: AppSource) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var systemImage: String {
            switch self {
            case .appStore: return "cart.fill"
            case .downloaded: return "arrow.down.circle.fill"
            case .selfBuilt: return "hammer.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
    }

    /// The kind of certificate the app is signed with.
    enum SigningKind: String, CaseIterable, Comparable, Codable {
        case developerID = "Developer ID"
        case appStore = "App Store"
        case development = "Development"
        case other = "Other"
        case none = "None"

        static func < (lhs: SigningKind, rhs: SigningKind) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var csvRow: String {
        [name, version, architecture.rawValue, source.rawValue, signing.rawValue,
         developer, website, bundleID, path.path]
            .map { field in "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: ",")
    }

    static let csvHeader = "Name,Version,Architecture,Source,Signing,Signed By,Website,Bundle ID,Path"

    /// Clean, stable shape for JSON export: plain POSIX path and CSV-matching
    /// field names, in a logical (non-alphabetical) order.
    struct Export: Encodable {
        let name: String
        let version: String
        let architecture: String
        let source: String
        let signing: String
        let signedBy: String
        let website: String
        let bundleID: String
        let path: String
    }

    var exportItem: Export {
        Export(name: name, version: version, architecture: architecture.rawValue,
               source: source.rawValue, signing: signing.rawValue, signedBy: developer,
               website: website, bundleID: bundleID, path: path.path)
    }
}

// Lets rows be dragged to Finder/Terminal/editors and copied with ⌘C, offering
// both the app's file URL and its POSIX path so each destination gets a sensible
// representation (Finder → the bundle, text fields → the path).
extension AppInfo: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.path)
        ProxyRepresentation(exporting: { $0.path.path })
    }
}
