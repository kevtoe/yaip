import SwiftUI

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: YPMetrics.compactSpacing) {
            Image(systemName: "waveform")
                .font(.largeTitle)
                .fontWeight(.light)
                .foregroundStyle(YPPalette.inkSoft)
                .accessibilityHidden(true)

            Text("Drop audio or video here")
                .font(YPTypography.body)
                .foregroundStyle(YPPalette.inkMuted)

            Text("or press \u{2318}O")
                .font(YPTypography.supporting)
                .foregroundStyle(YPPalette.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
        .accessibilityElement(children: .combine)
    }
}
