import SwiftUI

struct TranscriptStatusMessage: View {
    let text: String
    var tint: Color = YPPalette.inkMuted

    var body: some View {
        Text(text)
            .font(YPTypography.body)
            .foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .padding(YPMetrics.sectionSpacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
