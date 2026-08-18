import SwiftUI

/// The menu bar surface.
///
/// Says exactly what is and is not working.
struct DictationMenu: View {
    @Bindable var dictation: DictationController
    @Bindable var models: ModelManager
    /// The app delegate owns the windows, so opening them is passed in rather
    /// than going through SwiftUI's scene-based `openWindow`.
    let onOpenWindow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        @Bindable var preferences = dictation.preferences

        Text(statusLine)

        if let problem = dictation.permissionProblem {
            Divider()
            Text(problem.localizedDescription)
            Button("Open Accessibility Settings", action: InputPermissions.openAccessibilitySettings)
            Button("Open Input Monitoring Settings", action: InputPermissions.openInputMonitoringSettings)
            Button("Try Again", action: dictation.enable)
        }

        Divider()

        // Recording a shortcut needs a focused window, so the menu links to
        // Settings rather than offering a picker that could not express a
        // combination anyway.
        Picker("Activation", selection: $preferences.activationMode) {
            ForEach(DictationActivationMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }

        Picker("Model", selection: $preferences.engine) {
            ForEach(models.catalog.filter {
                models.installation(for: $0).isInstalled
                    || $0.selection == preferences.engine
            }) { model in
                Text(model.displayName).tag(model.selection)
            }
        }

        Toggle("Sound Cues", isOn: $preferences.soundCuesEnabled)
            .onChange(of: preferences.soundCuesEnabled, initial: true) {
                DictationSounds.isEnabled = preferences.soundCuesEnabled
            }

        Divider()

        Button("Open Yaip…", action: onOpenWindow)
        Button("Settings…", action: onOpenSettings)
            .keyboardShortcut(",")
        Button("Quit Yaip") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLine: String {
        guard dictation.permissionProblem == nil else { return "Dictation unavailable" }
        guard dictation.isEnabled else { return "Dictation off" }

        return switch dictation.phase {
        case .listening:    "Listening…"
        case .transcribing: "Transcribing…"
        default:
            switch dictation.preferences.activationMode {
            case .pushToTalk: "Hold \(dictation.preferences.shortcut.displayString) to dictate"
            case .toggle:     "Tap \(dictation.preferences.shortcut.displayString) to dictate"
            }
        }
    }
}
