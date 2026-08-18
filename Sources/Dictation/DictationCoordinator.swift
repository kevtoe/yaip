import Foundation
import Observation

/// Binds the dictation controller's phase to the overlay panel.
///
/// Kept separate so `DictationController` stays testable without AppKit, and
/// so the overlay is the only thing that knows about windows.
@MainActor
final class DictationCoordinator {
    let dictation: DictationController
    private let overlay: DictationOverlayController
    private var permissionWatch: Task<Void, Never>?

    init(dictation: DictationController = DictationController()) {
        self.dictation = dictation
        overlay = DictationOverlayController(dictation: dictation)
    }

    func start() {
        applyPreferences()

        dictation.onPhaseChange = { [weak self] phase in
            self?.overlay.setVisible(phase.isActive)
        }
        if FirstRunState.shouldPresentSetup == false {
            Task {
                await dictation.requestPermissionsAndEnable()
                await dictation.preloadModel()
            }
        } else {
            Task { await dictation.preloadModel() }
        }
        startPermissionWatch()
    }

    /// Pushes saved settings into the places that hold them as plain values.
    ///
    /// Without this they only took effect once the Settings window had been
    /// opened, so a saved sound or paste-delay preference silently did nothing
    /// for anyone who never went looking for it.
    private func applyPreferences() {
        let preferences = dictation.preferences
        DictationSounds.isEnabled = preferences.soundCuesEnabled
        TextInserter.restoreDelay = .milliseconds(preferences.pasteRestoreDelayMS)
        TextInserter.method = preferences.insertionMethod
    }

    /// macOS grants Accessibility without relaunching the app, but gives no
    /// callback when it happens. Polling while the permission is missing is the
    /// difference between "grant it and dictation just starts working" and
    /// "grant it, wonder why nothing happens, quit and reopen".
    private func startPermissionWatch() {
        permissionWatch?.cancel()
        permissionWatch = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                guard FirstRunState.shouldPresentSetup == false else { continue }
                guard dictation.isEnabled == false else { continue }
                if InputPermissions.hasAccessibility {
                    dictation.enable()
                }
            }
        }
    }

    /// `withObservationTracking` fires once, so it re-registers itself after
    /// every change. Forgetting the re-registration is the classic way this
    /// pattern silently stops working after the first event.
    private func observePhase() {
        withObservationTracking {
            _ = dictation.phase
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                overlay.setVisible(dictation.phase.isActive)
                observePhase()
            }
        }
    }
}
