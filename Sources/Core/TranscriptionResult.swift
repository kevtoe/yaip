import Foundation

/// What a runner hands back.
///
/// Deliberately engine-agnostic: nothing here leaks which engine produced it
/// except `engineIdentifier`, so views never switch on engine identity.
struct TranscriptionResult: Sendable {
    var segments: [Segment]
    var detectedLanguage: Locale.Language?
    var engineIdentifier: String
    var modelIdentifier: String
    /// Wall-clock time the transcription took, for the speed readout.
    var elapsed: Duration

    var text: String {
        segments
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
