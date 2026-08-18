import SwiftUI

/// The state marker on the dictation overlay.
///
/// Colour is never the only signal: the headline beside it always names the
/// state in words.
struct StatusDot: View {
    let phase: DictationPhase

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: YPMetrics.statusDotSize, height: YPMetrics.statusDotSize)
            .accessibilityHidden(true)
    }

    private var tint: Color {
        switch phase {
        case .idle:         YPPalette.inkSoft
        case .listening:    YPPalette.recording
        case .transcribing: YPPalette.accent
        case .delivered:    YPPalette.accent
        case .failed:       YPPalette.critical
        }
    }
}
