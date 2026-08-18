import SwiftUI

struct DetailPane: View {
    @Environment(TranscriptionStore.self) private var store

    var body: some View {
        if let job = store.selectedJob {
            TranscriptView(job: job)
        } else {
            Text("No transcript selected")
                .font(YPTypography.body)
                .foregroundStyle(YPPalette.inkSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(YPPalette.surface)
        }
    }
}
