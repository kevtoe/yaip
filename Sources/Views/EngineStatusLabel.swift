import SwiftUI

/// Says which local engine is selected.
struct EngineStatusLabel: View {
    @Environment(TranscriptionStore.self) private var store

    var body: some View {
        HStack(spacing: YPMetrics.compactSpacing) {
            Circle()
                .fill(YPPalette.accent)
                .frame(width: YPMetrics.statusDotSize, height: YPMetrics.statusDotSize)
            Text(store.engineLabel)
                .font(YPTypography.supporting)
                .foregroundStyle(YPPalette.inkMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current engine: \(store.engineLabel)")
    }
}
