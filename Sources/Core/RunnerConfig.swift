import Foundation

/// How the user wants transcription done in one context.
struct RunnerConfig: Codable, Hashable, Sendable {
    var engine: EngineSelection
    var language: LanguageMode = .auto
    /// Whisper's translate task. Ignored by engines that cannot do it.
    var translateToEnglish = false
    var wordTimestamps = false
    /// Biases decoding toward these terms. Whisper takes them as an initial
    /// prompt; engines without prompt conditioning ignore them.
    var vocabulary: [String] = []

    /// Dictation wants latency, so it defaults to Parakeet.
    static let defaultDictation = RunnerConfig(
        engine: ModelDescriptor.defaultDictationSelection
    )

    /// Batch wants accuracy and language coverage, so it defaults to Whisper.
    static let defaultBatch = RunnerConfig(
        engine: .whisperKit(model: WhisperModel.largeV3Turbo.rawValue),
        wordTimestamps: true
    )
}
