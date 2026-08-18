import SwiftUI

struct DictationSettingsPage: View {
    @Bindable var dictation: DictationController
    @Bindable var models: ModelManager

    private var preferences: DictationPreferences { dictation.preferences }

    var body: some View {
        @Bindable var preferences = preferences

        VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
            SettingsGroup(
                title: "Shortcut",
                footnote: preferences.activationMode.explanation
            ) {
                SettingsRow(title: "Dictation") {
                    Text(dictation.isEnabled ? "Running" : "Not running")
                        .font(YPTypography.supporting)
                        .foregroundStyle(dictation.isEnabled ? YPPalette.accent : YPPalette.warning)
                }
                Divider().overlay(YPPalette.line)

                SettingsRow(
                    title: "Dictation Shortcut",
                    detail: "Click, then press the shortcut you want."
                ) {
                    ShortcutRecorder(
                        shortcut: $preferences.shortcut,
                        setMonitorSuspended: dictation.setRecording
                    )
                    .onChange(of: preferences.shortcut) { dictation.enable() }
                }
                Divider().overlay(YPPalette.line)

                SettingsRow(
                    title: "Activation Mode",
                    detail: preferences.activationMode == .pushToTalk
                        ? "Recording starts on key down and finishes the moment you release."
                        : "Recording starts on the first press and finishes on the next."
                ) {
                    Picker("", selection: $preferences.activationMode) {
                        ForEach(DictationActivationMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }

                if preferences.activationMode == .pushToTalk,
                   preferences.shortcut.isModifierOnly == false {
                    Divider().overlay(YPPalette.line)
                    Text("""
                        Push to talk works best with a single modifier held down. A full \
                        combination is easier to use in Toggle mode.
                        """)
                        .font(YPTypography.supporting)
                        .foregroundStyle(YPPalette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, YPMetrics.standardSpacing)
                        .padding(.vertical, 12)
                }

                if let warning = preferences.shortcut.conflictWarning {
                    Divider().overlay(YPPalette.line)
                    Text(warning)
                        .font(YPTypography.supporting)
                        .foregroundStyle(YPPalette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, YPMetrics.standardSpacing)
                        .padding(.vertical, 12)
                }
            }

            SettingsGroup(title: "Model") {
                SettingsRow(
                    title: "Dictation Model",
                    detail: "Dictation favours speed. Apple Speech needs no download."
                ) {
                    Picker("", selection: $preferences.engine) {
                        ForEach(models.catalog.filter {
                            models.installation(for: $0).isInstalled
                                || $0.selection == preferences.engine
                        }) { model in
                            Text(model.displayName).tag(model.selection)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }

            SettingsGroup(title: "Overlay and Feedback") {
                SettingsRow(
                    title: "Overlay Position",
                    detail: preferences.overlayNearCaret
                        ? "Appears just above the text you are typing in."
                        : "Appears at the bottom of the screen."
                ) {
                    Picker("", selection: $preferences.overlayNearCaret) {
                        Text("Near Text Field").tag(true)
                        Text("Bottom of Screen").tag(false)
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                Divider().overlay(YPPalette.line)

                SettingsRow(
                    title: "Sound Cues",
                    detail: "A short sound when dictation starts, stops and fails."
                ) {
                    Toggle("", isOn: $preferences.soundCuesEnabled)
                        .labelsHidden()
                        .onChange(of: preferences.soundCuesEnabled, initial: true) {
                            DictationSounds.isEnabled = preferences.soundCuesEnabled
                        }
                }
            }

            if let problem = dictation.permissionProblem {
                SettingsGroup(title: "Permissions") {
                    VStack(alignment: .leading, spacing: YPMetrics.compactSpacing) {
                        Text(problem.localizedDescription)
                            .font(YPTypography.body)
                            .foregroundStyle(YPPalette.critical)
                        if let suggestion = problem.recoverySuggestion {
                            Text(suggestion)
                                .font(YPTypography.supporting)
                                .foregroundStyle(YPPalette.inkMuted)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                permissionButtons
                            }
                            VStack(alignment: .leading) {
                                permissionButtons
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(YPMetrics.standardSpacing)
                }
            }
        }
    }

    @ViewBuilder
    private var permissionButtons: some View {
        Button("Accessibility", action: InputPermissions.openAccessibilitySettings)
        Button("Input Monitoring", action: InputPermissions.openInputMonitoringSettings)
        Button("Try Again", action: dictation.enable)
    }
}
