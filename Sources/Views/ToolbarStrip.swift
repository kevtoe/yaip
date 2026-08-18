import SwiftUI

/// Section title left, exact engine state right.
struct ToolbarStrip: View {
    let title: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: YPMetrics.standardSpacing) {
            Text(title)
                .font(YPTypography.windowTitle)
                .foregroundStyle(YPPalette.ink)

            Spacer()
            EngineStatusLabel()
            EngineMenu()

            Button("Settings", systemImage: "gearshape", action: onOpenSettings)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(YPPalette.ink)
                .frame(width: YPMetrics.iconButtonSize, height: YPMetrics.iconButtonSize)
                .background(
                    YPPalette.surfaceRaised,
                    in: .rect(cornerRadius: YPMetrics.iconButtonRadius)
                )
                .help("Settings, models and shortcuts")
        }
        .padding(.horizontal, YPMetrics.sectionSpacing)
        .frame(height: YPMetrics.toolbarHeight)
        .background(YPPalette.surface)
    }
}
