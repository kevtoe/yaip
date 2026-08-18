import Foundation

/// Whisper models as published in the WhisperKit CoreML repository.
enum WhisperModel: String, CaseIterable, Sendable {
    case tiny         = "openai_whisper-tiny"
    case base         = "openai_whisper-base"
    case small        = "openai_whisper-small"
    case largeV3Turbo = "openai_whisper-large-v3-v20240930_turbo_632MB"
    case largeV3      = "openai_whisper-large-v3"

    var displayName: String {
        switch self {
        case .tiny:         "Tiny"
        case .base:         "Base"
        case .small:        "Small"
        case .largeV3Turbo: "Large V3 Turbo"
        case .largeV3:      "Large V3"
        }
    }

    var approximateBytes: Int64 {
        switch self {
        case .tiny:         77_000_000
        case .base:         148_000_000
        case .small:        488_000_000
        case .largeV3Turbo: 632_000_000
        case .largeV3:      3_100_000_000
        }
    }

    /// Whisper is trained on 99 languages, so treat it as universal. It is the
    /// backstop the language router falls back to.
    var languageSupport: LanguageSupport { .all }
}
