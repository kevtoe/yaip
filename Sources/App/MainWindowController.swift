import AppKit
import SwiftUI

/// Owns the main window directly rather than relying on a SwiftUI `Window`
/// scene.
///
/// The scene approach restores whatever visibility the window had when the app
/// last quit, so once it had been closed the app launched to nothing but a menu
/// bar icon and looked broken. Managing the window here means "open Yaip"
/// always shows Yaip.
@MainActor
final class MainWindowController {
    private var window: NSWindow?

    private let store: TranscriptionStore
    private let dictation: DictationController
    private let models: ModelManager
    private let initialSection: WorkspaceSection
    private let onOpenSettings: () -> Void

    init(
        store: TranscriptionStore,
        dictation: DictationController,
        models: ModelManager,
        initialSection: WorkspaceSection = .home,
        onOpenSettings: @escaping () -> Void
    ) {
        self.store = store
        self.dictation = dictation
        self.models = models
        self.initialSection = initialSection
        self.onOpenSettings = onOpenSettings
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: YPMetrics.defaultWindowWidth,
                height: YPMetrics.defaultWindowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Yaip"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(
            width: YPMetrics.minimumWindowWidth,
            height: YPMetrics.minimumWindowHeight
        )
        window.isReleasedWhenClosed = false   // reuse it when reopened
        window.center()
        window.setFrameAutosaveName("YaipMainWindow")

        let root = ContentView(
            dictation: dictation,
            initialSection: initialSection,
            onOpenSettings: onOpenSettings
        )
            .environment(store)
            .environment(models)
            .preferredColorScheme(.dark)
            // Sidebar selection and other system controls pick up the tint, so
            // the window does not mix our accent with the system blue.
            .tint(YPPalette.accent)
        window.contentView = NSHostingView(rootView: root)

        return window
    }
}
