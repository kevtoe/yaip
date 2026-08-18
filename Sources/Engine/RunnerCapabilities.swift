import Foundation

/// What an engine can do.
///
/// The UI reads this rather than switching on engine identity, so adding a
/// runner never requires touching a view.
struct RunnerCapabilities: Sendable, Hashable {
    /// False means audio leaves this Mac.
    var isLocal: Bool
    var supportsWordTimestamps: Bool
    var supportsTranslateToEnglish: Bool
    var supportsVocabularyPrompt: Bool
    var supportsLanguageDetection: Bool
    var languageSupport: LanguageSupport
    /// Optional duration cap for a runner. Nil means no limit.
    var maximumDuration: Duration?
}
