import Foundation

/// A single timed piece of transcribed speech.
///
/// Timings are milliseconds from the start of the media so the model stays
/// integer-exact; converting to `TimeInterval` at the edges avoids
/// accumulating float drift across a long recording.
struct Segment: Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var startMS: Int
    var endMS: Int
    var speakerID: UUID?
    var words: [Word]
    /// Normalised to 0...1, higher is better. Whisper exposes an average token
    /// log-probability; Parakeet reports one figure per result.
    var confidence: Double?

    init(
        id: UUID = UUID(),
        text: String,
        startMS: Int,
        endMS: Int,
        speakerID: UUID? = nil,
        words: [Word] = [],
        confidence: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.startMS = startMS
        self.endMS = endMS
        self.speakerID = speakerID
        self.words = words
        self.confidence = confidence
    }

    var start: Duration { .milliseconds(startMS) }
    var end: Duration { .milliseconds(endMS) }
    var duration: Duration { .milliseconds(endMS - startMS) }
}
