import Foundation

/// Options for one job, after language routing has resolved the engine.
struct TranscriptionOptions: Sendable {
    /// Resolved BCP-47 code. Nil means the engine should detect it.
    var language: String?
    var translateToEnglish: Bool
    var wordTimestamps: Bool
    var vocabulary: [String]

    init(from config: RunnerConfig, resolvedLanguage: String? = nil) {
        language = resolvedLanguage ?? config.language.explicitCode
        translateToEnglish = config.translateToEnglish
        wordTimestamps = config.wordTimestamps
        vocabulary = config.vocabulary
    }
}
