import SwiftUI

/// The accent border shown while a file is dragged over the window.
struct DropIndicator: View {
    let isVisible: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: YPMetrics.selectedRowRadius)
            .strokeBorder(YPPalette.accent, lineWidth: 2)
            .padding(8)
            .opacity(isVisible ? 1 : 0)
            // Opacity only, so Reduce Motion needs no special case.
            .animation(.easeOut(duration: 0.16), value: isVisible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
