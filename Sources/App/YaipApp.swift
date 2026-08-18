import SwiftUI

@main
struct YaipApp: App {
    @NSApplicationDelegateAdaptor(YaipAppDelegate.self) private var delegate

    init() {
        BundledFontRegistrar.registerUrbanist()
    }

    var body: some Scene {
        // The menu bar is the always-present surface: dictation works whether
        // or not a window is open. The main and settings windows are owned by
        // the app delegate rather than declared as scenes, because a SwiftUI
        // `Window` restores its last visibility and so can launch to nothing.
        //
        // Nothing here reads observable state. Doing so re-enters the scene
        // graph while it is still building and hangs the app at launch.
        MenuBarExtra {
            DictationMenu(
                dictation: delegate.coordinator.dictation,
                models: delegate.models,
                onOpenWindow: delegate.showMainWindow,
                onOpenSettings: delegate.showSettings
            )
        } label: {
            MenuBarIcon(dictation: delegate.coordinator.dictation)
        }
    }
}
