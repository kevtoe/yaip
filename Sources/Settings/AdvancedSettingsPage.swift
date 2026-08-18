import SwiftUI

struct AdvancedSettingsPage: View {
    @Bindable var models: ModelManager
    @Bindable var dictation: DictationController

    @State private var isConfirmingHistoryDelete = false

    private var preferences: DictationPreferences { dictation.preferences }

    var body: some View {
        @Bindable var preferences = preferences

        VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
            SettingsGroup(
                title: "Dictation",
                footnote: "Raise the restore delay if pasted text goes missing in an app."
            ) {
                SettingsRow(
                    title: "Insertion Method",
                    detail: preferences.insertionMethod.explanation
                ) {
                    Picker("", selection: $preferences.insertionMethod) {
                        ForEach(TextInserter.Method.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                    .onChange(of: preferences.insertionMethod, initial: true) {
                        TextInserter.method = preferences.insertionMethod
                    }
                }
                Divider().overlay(YPPalette.line)

                SettingsRow(title: "Clipboard Restore Delay") {
                    Picker("", selection: $preferences.pasteRestoreDelayMS) {
                        Text("300 ms").tag(300)
                        Text("500 ms").tag(500)
                        Text("800 ms").tag(800)
                        Text("1.2 s").tag(1200)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: preferences.pasteRestoreDelayMS, initial: true) {
                        TextInserter.restoreDelay =
                            .milliseconds(preferences.pasteRestoreDelayMS)
                    }
                }
            }

            SettingsGroup(title: "Storage") {
                SettingsRow(
                    title: "Model Cache",
                    detail: "Downloaded models on disk. Delete individual models under Local Models."
                ) {
                    Text(models.totalBytesOnDisk.formatted(.byteCount(style: .file)))
                        .font(YPTypography.metadata)
                        .foregroundStyle(YPPalette.inkMuted)
                }
                Divider().overlay(YPPalette.line)
                SettingsRow(
                    title: "Dictation History",
                    detail: "\(dictation.history.records.count) saved"
                ) {
                    Button("Delete All", role: .destructive) {
                        isConfirmingHistoryDelete = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete all dictation history?",
            isPresented: $isConfirmingHistoryDelete,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { dictation.history.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Anything not yet pasted somewhere will be lost.")
        }
    }
}
