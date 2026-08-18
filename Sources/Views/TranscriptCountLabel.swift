import SwiftUI

struct TranscriptCountLabel: View {
    let count: Int

    var body: some View {
        // Automatic grammar agreement rather than a hand-rolled plural.
        Text("^[\(count) transcript](inflect: true)")
            .font(YPTypography.supporting)
            .foregroundStyle(YPPalette.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, YPMetrics.sectionSpacing)
            .padding(.bottom, YPMetrics.compactSpacing)
    }
}
