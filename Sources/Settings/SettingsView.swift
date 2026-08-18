import SwiftUI

struct SettingsView: View {
    let dictation: DictationController
    @Bindable var models: ModelManager

    @State private var section: SettingsSection

    init(
        dictation: DictationController,
        models: ModelManager,
        initialSection: SettingsSection = .general
    ) {
        self.dictation = dictation
        self.models = models
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(SettingsSection.groupOrder, id: \.self) { group in
                    Section(group) {
                        ForEach(SettingsSection.allCases.filter { $0.group == group }) { item in
                            Label(item.label, systemImage: item.symbol)
                                .tag(item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } detail: {
            VStack(spacing: 0) {
                Text(section.label)
                    .font(YPTypography.windowTitle)
                    .foregroundStyle(YPPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, YPMetrics.sectionSpacing)
                    .frame(height: YPMetrics.settingsHeaderHeight)
                    .accessibilityAddTraits(.isHeader)

                Divider().overlay(YPPalette.line)

                ScrollView {
                    Group {
                        switch section {
                        case .general:     GeneralSettingsPage(dictation: dictation)
                        case .dictation:   DictationSettingsPage(dictation: dictation, models: models)
                        case .microphone:  MicrophoneSettingsPage()
                        case .localModels: LocalModelsPage(models: models, dictation: dictation)
                        case .advanced:    AdvancedSettingsPage(models: models, dictation: dictation)
                        case .about:       AboutSettingsPage()
                        }
                    }
                    .frame(maxWidth: YPMetrics.settingsContentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(YPMetrics.sectionSpacing)
                }
                // Each destination is a distinct page. Recreate its scroller
                // so a long page cannot lend its offset to the next one.
                .id(section)
                .scrollContentBackground(.hidden)
            }
            .background(YPPalette.canvas)
        }
    }
}

// MARK: - Shared building blocks

/// A titled group of rows, matching the grouped look of macOS settings.
struct SettingsGroup<Content: View>: View {
    var title: String?
    var footnote: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.compactSpacing) {
            if let title {
                Text(title)
                    .font(YPTypography.sectionTitle)
                    .foregroundStyle(YPPalette.ink)
            }

            VStack(spacing: 0) {
                content
            }
            .background(YPPalette.surface, in: .rect(cornerRadius: YPMetrics.controlRadius))

            if let footnote {
                Text(footnote)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One labelled row with a trailing control.
struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let control: Control

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: YPMetrics.standardSpacing) {
                labels
                Spacer(minLength: 0)
                control
            }

            VStack(alignment: .leading, spacing: YPMetrics.compactSpacing) {
                labels
                control
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, YPMetrics.standardSpacing)
        .padding(.vertical, 12)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(YPTypography.body)
                .foregroundStyle(YPPalette.ink)
            if let detail {
                Text(detail)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                }
        }
        .layoutPriority(1)
    }
}
