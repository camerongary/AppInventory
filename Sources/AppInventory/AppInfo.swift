import Foundation

struct AppInfo: Identifiable, Codable {
    var id = UUID()
    let name: String
    let path: URL
    let bundleID: String
    let version: String
    let architecture: Architecture
    let source: AppSource
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

    enum AppSource: String, CaseIterable, Comparable, Codable {
        case appStore = "App Store"
        case developerID = "Developer ID"
        case development = "Development"
        case unsigned = "Unsigned / Self-Built"
        case unknown = "Unknown"

        static func < (lhs: AppSource, rhs: AppSource) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var systemImage: String {
            switch self {
            case .appStore: return "cart.fill"
            case .developerID: return "checkmark.seal.fill"
            case .development: return "hammer.fill"
            case .unsigned: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
    }

    var csvRow: String {
        [name, version, architecture.rawValue, source.rawValue, developer, website, bundleID, path.path]
            .map { field in "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: ",")
    }

    static let csvHeader = "Name,Version,Architecture,Source,Signed By,Website,Bundle ID,Path"
}
