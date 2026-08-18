import AppKit
import OSLog
import SwiftUI

/// Shows and hides the dictation overlay, anchored to wherever the user is
/// typing rather than parked at the bottom of the screen.
@MainActor
final class DictationOverlayController {
    private let log = Logger(subsystem: "app.yaip.v1", category: "Overlay")
    private var panel: DictationOverlayPanel?
    private let dictation: DictationController

    /// Gap between the caret and the overlay.
    private static let caretGap: CGFloat = 10
    /// Keep this far clear of any screen edge.
    private static let screenMargin: CGFloat = 12

    init(dictation: DictationController) {
        self.dictation = dictation
    }

    func setVisible(_ visible: Bool) {
        guard visible else {
            panel?.orderOut(nil)
            log.debug("overlay hidden")
            return
        }
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        // orderFrontRegardless shows it without activating Yaip, which would
        // pull focus out of whatever the user is typing in.
        panel.orderFrontRegardless()
        log.debug("overlay shown, visible=\(panel.isVisible, privacy: .public)")
    }

    /// Re-anchor without re-showing. Called when dictation starts, since the
    /// caret may have moved since the last time.
    func reanchor() {
        guard let panel, panel.isVisible else { return }
        position(panel)
    }

    private func makePanel() -> DictationOverlayPanel {
        let size = NSSize(width: YPMetrics.overlayWidth, height: YPMetrics.overlayHeight)
        let panel = DictationOverlayPanel(contentRect: NSRect(origin: .zero, size: size))

        let host = NSHostingView(
            rootView: DictationOverlayView(dictation: dictation)
                .preferredColorScheme(.dark)
                .tint(YPPalette.accent)
        )
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        return panel
    }

    private func position(_ panel: NSPanel) {
        let size = panel.frame.size
        let anchor = dictation.preferences.overlayNearCaret
            ? CaretLocator.anchorRect()
            : nil
        let origin = anchor.map { rect in
            // Above the caret by preference, so the overlay never covers the
            // words being typed.
            CGPoint(x: rect.midX - size.width / 2, y: rect.maxY + Self.caretGap)
        } ?? fallbackOrigin(for: size)

        let final = clamped(origin, size: size)
        panel.setFrameOrigin(final)
        log.debug("""
            anchor=\(anchor.map(NSStringFromRect) ?? "none", privacy: .public) \
            origin=\(NSStringFromPoint(final), privacy: .public)
            """)
    }

    /// Bottom centre of the screen holding the pointer, when accessibility
    /// gives us nothing to anchor to.
    private func fallbackOrigin(for size: NSSize) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return .zero }
        return CGPoint(x: frame.midX - size.width / 2, y: frame.minY + 96)
    }

    /// Keeps the panel fully on screen. Without this, dictating into a field
    /// near the top of the display puts the overlay under the menu bar, and a
    /// field near the right edge pushes it off entirely.
    private func clamped(_ origin: CGPoint, size: NSSize) -> CGPoint {
        let target = NSRect(origin: origin, size: size)
        let screen = NSScreen.screens.first { $0.frame.intersects(target) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }

        var point = origin
        point.x = min(max(point.x, visible.minX + Self.screenMargin),
                      visible.maxX - size.width - Self.screenMargin)

        // If there is no room above the caret, flip to below it.
        if point.y + size.height > visible.maxY - Self.screenMargin {
            point.y = origin.y - size.height - Self.caretGap * 2
        }
        point.y = min(max(point.y, visible.minY + Self.screenMargin),
                      visible.maxY - size.height - Self.screenMargin)
        return point
    }
}
