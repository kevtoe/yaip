import Foundation

/// Which engine to run, and how it is configured.
///
/// A tagged union so it round-trips through JSON, versions cleanly, and lets
/// each context (dictation, batch, live captions) hold an independent choice.
enum EngineSelection: Codable, Hashable, Sendable {
    case whisperKit(model: String)
    case fluidParakeet(model: String)
    case appleSpeech(localeIdentifier: String)
    case registeredLocal(id: UUID, engine: LocalModelEngine, displayName: String)

    var engineIdentifier: String {
        switch self {
        case .whisperKit:       "whisperkit"
        case .fluidParakeet:    "fluid-parakeet"
        case .appleSpeech:      "apple-speech"
        case .registeredLocal(_, let engine, _):
            engine == .whisperKit ? "whisperkit" : "fluid-parakeet"
        }
    }

    var modelIdentifier: String {
        switch self {
        case .whisperKit(let model):    model
        case .fluidParakeet(let model): model
        case .appleSpeech(let locale):  "apple-speech-\(locale)"
        case .registeredLocal(let id, _, _): "registered-\(id.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case .whisperKit(let model):
            WhisperModel(rawValue: model)?.displayName ?? "Whisper"
        case .fluidParakeet(let model):
            ParakeetModel(rawValue: model)?.displayName ?? "Parakeet"
        case .appleSpeech:
            "Apple Speech"
        case .registeredLocal(_, _, let displayName):
            displayName
        }
    }

    var isSupportedOnCurrentOS: Bool {
        if case .appleSpeech = self {
            if #available(macOS 26, *) { return true }
            return false
        }
        return true
    }
}
