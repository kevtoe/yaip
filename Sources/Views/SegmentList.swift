import SwiftUI

struct SegmentList: View {
    let segments: [Segment]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(segments) { segment in
                    SegmentRow(segment: segment)
                }
            }
            .padding(YPMetrics.sectionSpacing)
        }
        .scrollContentBackground(.hidden)
    }
}
