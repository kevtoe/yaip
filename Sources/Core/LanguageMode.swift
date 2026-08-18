import Foundation

/// Whether the user pinned a language or wants it detected.
enum LanguageMode: Codable, Hashable, Sendable {
    case auto
    case fixed(String)   // BCP-47, e.g. "en", "vi"

    var explicitCode: String? {
        if case .fixed(let code) = self { code } else { nil }
    }
}
