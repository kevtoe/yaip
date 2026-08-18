import SwiftUI

struct SegmentRow: View {
    let segment: Segment

    var body: some View {
        HStack(alignment: .top, spacing: YPMetrics.standardSpacing) {
            Text(segment.start.paddedTimecode)
                .font(YPTypography.timecode)
                .foregroundStyle(YPPalette.inkSoft)
                .frame(width: YPMetrics.transcriptGutterWidth, alignment: .leading)
                .accessibilityLabel("At \(segment.start.minuteSecondLabel)")

            Text(segment.text)
                .font(YPTypography.transcript)
                .lineSpacing(YPTypography.transcriptLineSpacing)
                .foregroundStyle(YPPalette.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, YPMetrics.segmentVerticalPadding)
    }
}
