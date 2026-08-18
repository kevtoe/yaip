import AppKit
import SwiftUI

@MainActor
final class FirstRunWindowController {
    private var window: NSWindow?
    private let dictation: DictationController
    private let onComplete: () -> Void

    init(dictation: DictationController, onComplete: @escaping () -> Void) {
        self.dictation = dictation
        self.onComplete = onComplete
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 530),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Up Yaip"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: FirstRunSetupView(dictation: dictation) { [weak self] in
                self?.window?.close()
                self?.onComplete()
            }
            .preferredColorScheme(.dark)
            .tint(YPPalette.accent)
            .background(YPPalette.canvas)
        )
        return window
    }
}
