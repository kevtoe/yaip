import SwiftUI

struct TranscriptSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: YPMetrics.compactSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(YPPalette.inkSoft)
                .accessibilityHidden(true)

            TextField("Search transcripts", text: $text)
                .textFieldStyle(.plain)
                .font(YPTypography.body)
                .foregroundStyle(YPPalette.ink)
        }
        .padding(.horizontal, YPMetrics.controlHorizontalPadding)
        // The visible control and its hit area are the same rectangle, so the
        // 44pt target is real rather than a small field in a large box.
        .frame(height: YPMetrics.controlHeight)
        .background(
            YPPalette.surfaceRaised,
            in: .rect(cornerRadius: YPMetrics.controlRadius)
        )
    }
}
