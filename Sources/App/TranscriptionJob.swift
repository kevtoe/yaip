import Foundation
import Observation

/// One completed or in-flight transcription.
@MainActor
@Observable
final class TranscriptionJob: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var title: String
    var state: TranscriptionJobState = .queued
    var result: TranscriptionResult?
    var duration: Duration?

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        title = sourceURL.deletingPathExtension().lastPathComponent
    }

    /// The one-line summary shown under the title in the list.
    var statusSummary: String {
        switch state {
        case .queued:
            "Queued"
        case .loadingModel(let fraction):
            "Loading model \(fraction.formatted(.percent.precision(.fractionLength(0))))"
        case .transcribing(let fraction, _):
            fraction.map {
                "Transcribing \($0.formatted(.percent.precision(.fractionLength(0))))"
            } ?? "Transcribing…"
        case .failed(let message):
            message
        case .finished:
            finishedSummary
        }
    }

    private var finishedSummary: String {
        var parts = [String]()
        if let duration { parts.append(duration.minuteSecondLabel) }
        if let result {
            // Plain pluralisation, not `inflect:` markup: this is composed into
            // a String, and grammar agreement only resolves inside a literal
            // `Text`, so the markup would render verbatim.
            let count = result.segments.count
            parts.append("\(count) segment\(count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    func matches(_ query: String) -> Bool {
        title.localizedStandardContains(query)
            || (result?.text.localizedStandardContains(query) ?? false)
    }
}
