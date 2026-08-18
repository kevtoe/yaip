import Foundation

/// How holding the key maps to a recording.
enum DictationActivationMode: String, CaseIterable, Codable, Sendable {
    /// Hold to record, release to transcribe.
    case pushToTalk
    /// Tap to start, tap again to stop.
    case toggle

    var displayName: String {
        switch self {
        case .pushToTalk: "Push to Talk"
        case .toggle:     "Toggle"
        }
    }

    var explanation: String {
        switch self {
        case .pushToTalk:
            "Hold the key while you speak, then release."
        case .toggle:
            "Tap once to start, tap again to stop. Useful for long passages."
        }
    }
}
