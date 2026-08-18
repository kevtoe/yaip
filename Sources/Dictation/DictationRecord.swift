import Foundation

/// One dictation, kept so nothing said is ever unrecoverable.
///
/// The insertion paths can all fail (Electron apps, secure input, an app that
/// ignores the paste), and when they do the words must still be somewhere the
/// user can get at them.
struct DictationRecord: Identifiable, Codable, Hashable, Sendable {
    enum Delivery: String, Codable, Sendable {
        /// Written straight into the focused field via Accessibility.
        case inserted
        /// Pasted through the clipboard.
        case pasted
        /// Could not be delivered; left on the clipboard.
        case copiedOnly

        var label: String {
            switch self {
            case .inserted, .pasted: "Inserted"
            case .copiedOnly:        "Not inserted"
            }
        }

        var didReachTheApp: Bool {
            self != .copiedOnly
        }
    }

    let id: UUID
    let date: Date
    let text: String
    /// Where it was meant to go, e.g. "Slack".
    let targetAppName: String?
    let targetBundleID: String?
    let delivery: Delivery
    /// Why it was not inserted, when it was not.
    let failureReason: String?
    let engineIdentifier: String
    let modelIdentifier: String
    let spokenSeconds: Double

    init(
        id: UUID = UUID(),
        date: Date = .now,
        text: String,
        targetAppName: String?,
        targetBundleID: String?,
        delivery: Delivery,
        failureReason: String? = nil,
        engineIdentifier: String,
        modelIdentifier: String,
        spokenSeconds: Double
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.targetAppName = targetAppName
        self.targetBundleID = targetBundleID
        self.delivery = delivery
        self.failureReason = failureReason
        self.engineIdentifier = engineIdentifier
        self.modelIdentifier = modelIdentifier
        self.spokenSeconds = spokenSeconds
    }

    var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
