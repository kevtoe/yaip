import Foundation

/// What languages an engine can actually handle.
enum LanguageSupport: Sendable, Hashable {
    case all
    case only(Set<String>)

    func supports(_ code: String) -> Bool {
        switch self {
        case .all:
            true
        // Match on the primary subtag so "en-AU" satisfies "en".
        case .only(let codes):
            codes.contains(String(code.prefix(2)).lowercased())
        }
    }
}
