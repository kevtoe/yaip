import SwiftUI

/// Everything dictated, newest first, with where it went and whether it
/// actually landed.
struct DictationHistoryView: View {
    @Bindable var history: DictationHistory
    @State private var searchText = ""

    private var visible: [DictationRecord] {
        history.matching(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            TranscriptSearchField(text: $searchText)
                .padding(YPMetrics.standardSpacing)

            if history.records.isEmpty {
                EmptyDictationView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(visible) { record in
                            DictationRow(record: record) {
                                history.remove(record)
                            }
                        }
                    }
                    .padding(.horizontal, YPMetrics.standardSpacing)
                    .padding(.bottom, YPMetrics.standardSpacing)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(YPPalette.canvas)
    }
}

private struct EmptyDictationView: View {
    var body: some View {
        VStack(spacing: YPMetrics.compactSpacing) {
            Image(systemName: "mic")
                .font(.largeTitle)
                .fontWeight(.light)
                .foregroundStyle(YPPalette.inkSoft)
                .accessibilityHidden(true)
            Text("Nothing dictated yet")
                .font(YPTypography.body)
                .foregroundStyle(YPPalette.inkMuted)
            Text("Use your dictation shortcut in any app.")
                .font(YPTypography.supporting)
                .foregroundStyle(YPPalette.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
        .accessibilityElement(children: .combine)
    }
}
