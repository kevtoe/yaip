import AppKit
import SwiftUI

/// Starts dictation at launch and owns the app's windows.
///
/// Dictation lives here rather than in a view's `task` because it is the
/// product: it has to run whether or not a window is open.
@MainActor
final class YaipAppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: DictationCoordinator
    let store: TranscriptionStore
    let models: ModelManager
    private let screenshotDestination: ScreenshotDestination?

    private var mainWindow: MainWindowController?
    private var settingsWindow: SettingsWindowController?
    private var firstRunWindow: FirstRunWindowController?

    override init() {
        let destination = ScreenshotDestination(arguments: CommandLine.arguments)
        screenshotDestination = destination
        let presentationMode = destination != nil
        let history = presentationMode ? DictationHistory.screenshotDemo() : DictationHistory()
        let preferences: DictationPreferences
        if presentationMode {
            let defaults = UserDefaults(suiteName: "app.yaip.v1.screenshot")!
            defaults.removePersistentDomain(forName: "app.yaip.v1.screenshot")
            preferences = DictationPreferences(defaults: defaults)
            preferences.engine = .whisperKit(model: WhisperModel.tiny.rawValue)
        } else {
            preferences = DictationPreferences()
        }
        coordinator = DictationCoordinator(
            dictation: DictationController(
                history: history,
                preferences: preferences,
                presentationMode: presentationMode
            )
        )
        let transcriptionStore = TranscriptionStore()
        if presentationMode {
            transcriptionStore.config = RunnerConfig(
                engine: .whisperKit(model: WhisperModel.tiny.rawValue)
            )
        }
        store = transcriptionStore
        models = ModelManager()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ReleaseVerifier.runIfRequested() { return }
        let isScreenshotMode = screenshotDestination != nil

        RunnerRegistry.shared.setLocalModelResolverFromMainActor { [weak self] id in
            await self?.models.resolveRegisteredModel(id)
        }
        if isScreenshotMode == false {
            Task {
                await models.refresh()
                if case .registeredLocal(let id, _, _) = coordinator.dictation.preferences.engine,
                   models.isRegistered(id) == false {
                    coordinator.dictation.preferences.engine = ModelDescriptor.defaultDictationSelection
                }
            }
            coordinator.start()
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["YAIP_PREVIEW_OVERLAY"] == "1" {
            coordinator.dictation.previewListeningOverlay()
        }
        #endif

        settingsWindow = SettingsWindowController(
            dictation: coordinator.dictation,
            models: models,
            initialSection: screenshotDestination == .about ? .about : .general
        )
        mainWindow = MainWindowController(
            store: store,
            dictation: coordinator.dictation,
            models: models,
            initialSection: screenshotDestination == .history ? .dictations : .home,
            onOpenSettings: { [weak self] in self?.showSettings() }
        )

        if screenshotDestination == .about {
            showSettings()
            return
        }
        if isScreenshotMode {
            showMainWindow()
            return
        }

        if FirstRunState.shouldPresentSetup == false {
            showMainWindow()
        } else {
            firstRunWindow = FirstRunWindowController(
                dictation: coordinator.dictation,
                onComplete: { [weak self] in self?.showMainWindow() }
            )
            firstRunWindow?.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.dictation.disable()
    }

    /// Closing the window leaves dictation running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        if FirstRunState.shouldPresentSetup {
            firstRunWindow?.show()
        } else {
            showMainWindow()
        }
        return true
    }

    func showMainWindow() {
        mainWindow?.show()
    }

    func showSettings() {
        settingsWindow?.show()
    }

}

private enum ScreenshotDestination {
    case home
    case history
    case about

    init?(arguments: [String]) {
        if arguments.contains("--screenshot-home") { self = .home }
        else if arguments.contains("--screenshot-history") { self = .history }
        else if arguments.contains("--screenshot-about") { self = .about }
        else { return nil }
    }
}
