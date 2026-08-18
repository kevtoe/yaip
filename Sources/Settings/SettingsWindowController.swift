import AppKit
import SwiftUI

/// Owns the settings window, for the same reason the main window is owned in
/// AppKit: it must open on demand, every time, regardless of scene restoration.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    private let dictation: DictationController
    private let models: ModelManager
    private let initialSection: SettingsSection

    init(
        dictation: DictationController,
        models: ModelManager,
        initialSection: SettingsSection = .general
    ) {
        self.dictation = dictation
        self.models = models
        self.initialSection = initialSection
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Refresh on every open: models may have been downloaded or deleted
        // outside the app since it was last shown. Off the main thread, so a
        // slow or cloud-synced folder cannot stall opening the window.
        Task { await models.refresh() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Yaip Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 760, height: 520)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("YaipSettingsWindow")

        window.contentView = NSHostingView(
            rootView: SettingsView(
                dictation: dictation,
                models: models,
                initialSection: initialSection
            )
                .preferredColorScheme(.dark)
                .tint(YPPalette.accent)
        )
        return window
    }
}
