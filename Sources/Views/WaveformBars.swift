import SwiftUI

/// Live microphone level, scrolling right to left.
///
/// Its only job is to answer "is it hearing me?" before you have finished the
/// sentence, so it shows the recent history of levels rather than one value
/// smeared across a fixed shape. A static envelope cannot distinguish "quiet"
/// from "not listening", which is the failure that matters.
struct WaveformBars: View {
    /// Newest last. Values 0...1.
    let levels: [Float]

    private static let minimumBarHeight: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(YPPalette.waveformActive)
                        .frame(height: barHeight(for: level, in: height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(for level: Float, in available: CGFloat) -> CGFloat {
        Self.minimumBarHeight + (available - Self.minimumBarHeight) * CGFloat(level)
    }
}

#Preview {
    WaveformBars(levels: (0..<32).map { _ in Float.random(in: 0...1) })
        .frame(width: 200, height: 20)
        .padding()
        .background(YPPalette.surface)
}
