import SwiftUI

/// Landing screen: what you can do, then what you just did.
struct HomeView: View {
    @Environment(TranscriptionStore.self) private var store
    let dictation: DictationController
    @Binding var section: WorkspaceSection
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speak. Yaip types.")
                        .font(YPTypography.windowTitle)
                        .foregroundStyle(YPPalette.ink)
                    Text("Local Mac dictation with a history you can copy or clear.")
                        .font(YPTypography.body)
                        .foregroundStyle(YPPalette.inkMuted)
                }

                DictationReadyCard(dictation: dictation)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ActionTile(title: "Open Files", symbol: "folder", action: openFiles)
                    ActionTile(title: "Dictations", symbol: "mic") { section = .dictations }
                    ActionTile(title: "Transcriptions", symbol: "text.alignleft") {
                        section = .transcripts
                    }
                    ActionTile(
                        title: "Manage Models",
                        symbol: "internaldrive",
                        action: onOpenSettings
                    )
                    ActionTile(
                        title: "Shortcut",
                        symbol: "command",
                        action: onOpenSettings
                    )
                    ActionTile(
                        title: "Settings",
                        symbol: "gearshape",
                        action: onOpenSettings
                    )
                }

                if dictation.history.records.isEmpty == false {
                    RecentDictations(history: dictation.history) { section = .dictations }
                }
            }
            .padding(YPMetrics.sectionSpacing)
        }
        .scrollContentBackground(.hidden)
    }

    private func openFiles() {
        let urls = MediaFileImporter.chooseFiles()
        guard urls.isEmpty == false else { return }
        section = .transcripts
        store.add(urls: urls)
    }
}

/// States the one thing the user most needs to know on opening the app.
private struct DictationReadyCard: View {
    @Bindable var dictation: DictationController

    var body: some View {
        HStack(spacing: YPMetrics.standardSpacing) {
            Image(systemName: dictation.isEnabled ? "mic.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(dictation.isEnabled ? YPPalette.accent : YPPalette.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(YPTypography.sectionTitle)
                    .foregroundStyle(YPPalette.ink)
                Text(detail)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(YPMetrics.standardSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YPPalette.surface, in: .rect(cornerRadius: YPMetrics.selectedRowRadius))
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        guard dictation.isEnabled else { return "Dictation is not running" }
        let shortcut = dictation.preferences.shortcut.displayString
        return switch dictation.preferences.activationMode {
        case .pushToTalk: "Hold \(shortcut) anywhere to dictate"
        case .toggle:     "Tap \(shortcut) anywhere to dictate"
        }
    }

    private var detail: String {
        if let problem = dictation.permissionProblem {
            return problem.localizedDescription
        }
        return "Speak, then release to insert the text into the active app."
    }
}

private struct ActionTile: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: YPMetrics.compactSpacing) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(YPPalette.inkMuted)
                Text(title)
                    .font(YPTypography.controlLabel)
                    .foregroundStyle(YPPalette.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(YPMetrics.standardSpacing)
            .background(YPPalette.surface, in: .rect(cornerRadius: YPMetrics.controlRadius))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct RecentDictations: View {
    @Bindable var history: DictationHistory
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.compactSpacing) {
            HStack {
                Text("Today")
                    .font(YPTypography.sectionTitle)
                    .foregroundStyle(YPPalette.ink)
                Spacer()
                Button("See All", action: onSeeAll)
                    .buttonStyle(.plain)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.accent)
            }

            ForEach(history.records.prefix(5)) { record in
                DictationRow(record: record) { history.remove(record) }
            }
        }
    }
}
