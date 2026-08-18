import SwiftUI

/// Switches between the finished transcript and the in-progress or failed
/// states, replacing content in place rather than reaching for a modal.
struct TranscriptBody: View {
    @Bindable var job: TranscriptionJob

    var body: some View {
        switch job.state {
        case .finished:
            if let result = job.result, result.segments.isEmpty == false {
                SegmentList(segments: result.segments)
            } else {
                TranscriptStatusMessage(text: "No speech detected.")
            }

        case .failed(let message):
            TranscriptStatusMessage(text: message, tint: YPPalette.critical)

        case .transcribing(_, let partial):
            TranscriptStatusMessage(text: partial ?? "Transcribing…")

        case .loadingModel(let fraction):
            TranscriptStatusMessage(
                text: "Loading model \(fraction.formatted(.percent.precision(.fractionLength(0))))"
            )

        case .queued:
            TranscriptStatusMessage(text: "Queued")
        }
    }
}
