import AppKit

/// A panel that floats over every app and never takes focus.
///
/// Focus is the whole game here: if the overlay becomes key, the text field the
/// user was typing in loses its selection and the paste lands nowhere.
final class DictationOverlayPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        // Visible over full-screen apps and on whichever Space is in front,
        // because dictation is used from inside other people's windows.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovable = false
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        animationBehavior = .utilityWindow
    }

    // Never become key or main, no matter how it is presented.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
