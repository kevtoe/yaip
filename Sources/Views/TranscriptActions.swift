import SwiftUI

struct TranscriptActions: View {
    let result: TranscriptionResult

    var body: some View {
        HStack {
            Spacer()
            Button("Copy Transcript", action: copyTranscript)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(YPMetrics.standardSpacing)
    }

    private func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.text, forType: .string)
    }
}
