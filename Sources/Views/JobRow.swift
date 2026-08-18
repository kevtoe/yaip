import SwiftUI

/// A row in the transcript list.
///
/// A real `Button` rather than `onTapGesture`, so VoiceOver and Full Keyboard
/// Access treat it as the control it is.
struct JobRow: View {
    @Environment(TranscriptionStore.self) private var store
    @Bindable var job: TranscriptionJob
    let isSelected: Bool

    var body: some View {
        Button(action: select) {
            HStack(spacing: YPMetrics.compactSpacing) {
                // Selection is a tonal fill plus an accent left bar, as in RL.
                Rectangle()
                    .fill(isSelected ? YPPalette.accent : .clear)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(job.title)
                        .font(YPTypography.controlLabel)
                        .foregroundStyle(YPPalette.ink)
                        .lineLimit(1)
                    Text(job.statusSummary)
                        .font(YPTypography.supporting)
                        .foregroundStyle(YPPalette.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if job.state.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(YPPalette.accent)
                }
            }
            .padding(.trailing, YPMetrics.standardSpacing)
            .frame(height: YPMetrics.rowHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? YPPalette.surfaceRaised : .clear,
            in: .rect(cornerRadius: YPMetrics.selectedRowRadius)
        )
        .accessibilityLabel(job.title)
        .accessibilityValue(job.statusSummary)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func select() {
        store.selectedJobID = job.id
    }
}
