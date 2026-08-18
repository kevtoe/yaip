import SwiftUI

/// The file transcription half: list on the left, transcript on the right.
struct TranscriptWorkspace: View {
    var body: some View {
        HStack(spacing: 0) {
            JobListPane()
                .frame(width: 340)
            Divider().overlay(YPPalette.line)
            DetailPane()
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
}
