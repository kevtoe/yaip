import SwiftUI

struct JobListPane: View {
    @Environment(TranscriptionStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            TranscriptSearchField(text: $store.searchText)
                .padding(YPMetrics.standardSpacing)

            if store.jobs.isEmpty {
                EmptyLibraryView()
            } else {
                TranscriptCountLabel(count: store.filteredJobs.count)
                JobList()
            }

            Spacer(minLength: 0)
        }
        .background(YPPalette.canvas)
    }
}
