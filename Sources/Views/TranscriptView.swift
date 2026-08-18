import SwiftUI

struct TranscriptView: View {
    @Bindable var job: TranscriptionJob

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TranscriptHeader(job: job)
            Divider().overlay(YPPalette.line)

            TranscriptBody(job: job)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let result = job.result, job.state == .finished {
                Divider().overlay(YPPalette.line)
                TranscriptActions(result: result)
            }
        }
        .background(YPPalette.surface)
    }
}
