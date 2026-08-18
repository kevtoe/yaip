import SwiftUI

struct JobList: View {
    @Environment(TranscriptionStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(store.filteredJobs) { job in
                    JobRow(job: job, isSelected: job.id == store.selectedJobID)
                        .contextMenu {
                            Button("Transcribe Again") { store.retranscribe(job) }
                            Button("Remove", role: .destructive) { store.remove(job) }
                        }
                }
            }
            .padding(.horizontal, YPMetrics.compactSpacing)
        }
        .scrollContentBackground(.hidden)
    }
}
