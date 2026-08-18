import Foundation

/// Parakeet TDT models served through FluidAudio.
enum ParakeetModel: String, CaseIterable, Sendable {
    case v3 = "parakeet-tdt-0.6b-v3"

    var displayName: String {
        switch self {
        case .v3: "Parakeet TDT v3"
        }
    }

    var approximateBytes: Int64 {
        switch self {
        case .v3: 494_000_000
        }
    }

    var languageSupport: LanguageSupport {
        switch self {
        case .v3: .only(Self.v3Languages)
        }
    }

    /// Parakeet TDT v3: 25 European languages plus Japanese.
    ///
    /// Vietnamese is deliberately absent, which is the entire reason
    /// `LanguageRouter` exists. Do not "fix" this list by adding codes the
    /// model was never trained on.
    static let v3Languages: Set<String> = [
        "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu",
        "it", "ja", "lt", "lv", "mt", "nl", "pl", "pt", "ro", "ru", "sk", "sl",
        "sv", "uk",
    ]
}
