import SwiftUI

/// Model picker.
///
/// Carries a real text label for VoiceOver and Voice Control, with
/// `.labelStyle(.iconOnly)` keeping the toolbar visually quiet.
struct EngineMenu: View {
    @Environment(TranscriptionStore.self) private var store
    @Environment(ModelManager.self) private var models

    var body: some View {
        Menu("Transcription Model", systemImage: "slider.horizontal.3") {
            ForEach(models.catalog.filter {
                models.installation(for: $0).isInstalled
                    || $0.selection == store.config.engine
            }) { model in
                Toggle(isOn: binding(for: model)) {
                    Text("\(model.displayName) · \(model.formattedSize) · \(model.languageSummary)")
                }
            }
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: YPMetrics.iconButtonSize, height: YPMetrics.iconButtonSize)
        .background(
            YPPalette.surfaceRaised,
            in: .rect(cornerRadius: YPMetrics.iconButtonRadius)
        )
        .foregroundStyle(YPPalette.ink)
    }

    private func binding(for model: ModelDescriptor) -> Binding<Bool> {
        // A menu of mutually exclusive toggles reads better to VoiceOver than
        // buttons with hand-drawn checkmarks, and gives the selected state for
        // free.
        Binding(
            get: { store.config.engine == model.selection },
            set: { isOn in
                guard isOn else { return }
                store.config.engine = model.selection
            }
        )
    }
}
