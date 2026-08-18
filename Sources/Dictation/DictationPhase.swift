import Foundation

/// What the dictation overlay is showing.
enum DictationPhase: Equatable, Sendable {
    case idle
    case listening
    case transcribing
    case delivered(text: String, outcome: String)
    case failed(String)

    var isActive: Bool {
        self != .idle
    }
}
