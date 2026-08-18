import SwiftUI

/// Green accent, dark text and a 44 point minimum target.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(YPTypography.buttonLabel)
            .foregroundStyle(YPPalette.onAccent)
            .padding(.horizontal, YPMetrics.sectionSpacing)
            .frame(height: YPMetrics.controlHeight)
            .frame(minWidth: YPMetrics.controlMinWidth)
            .background(
                configuration.isPressed ? YPPalette.accentStrong : YPPalette.accent,
                in: .rect(cornerRadius: YPMetrics.controlRadius)
            )
            // A pressed control translates by one point.
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
