import SwiftUI

/// The persistent bottom strip: one icon and one line of plain text.
struct ActivityStrip: View {
    @Environment(TranscriptionStore.self) private var store

    var body: some View {
        HStack(spacing: YPMetrics.compactSpacing) {
            Image(systemName: "waveform.path")
                .foregroundStyle(YPPalette.inkMuted)
                .accessibilityHidden(true)

            Text("Activity")
                .font(YPTypography.controlLabel)
                .foregroundStyle(YPPalette.ink)

            Text(verbatim: "·")
                .foregroundStyle(YPPalette.inkSoft)
                .accessibilityHidden(true)

            Text(store.activityMessage)
                .font(YPTypography.supporting)
                .foregroundStyle(YPPalette.inkMuted)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.horizontal, YPMetrics.sectionSpacing)
        .frame(height: YPMetrics.activityHeight)
        .background(YPPalette.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Activity: \(store.activityMessage)")
    }
}
