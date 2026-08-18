import SwiftUI

struct ContentView: View {
    @Environment(TranscriptionStore.self) private var store
    let dictation: DictationController
    let onOpenSettings: () -> Void

    @State private var section: WorkspaceSection
    @State private var isDropTargeted = false

    init(
        dictation: DictationController,
        initialSection: WorkspaceSection = .home,
        onOpenSettings: @escaping () -> Void
    ) {
        self.dictation = dictation
        self.onOpenSettings = onOpenSettings
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar(section: $section, onOpenSettings: onOpenSettings)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                ToolbarStrip(title: section.label, onOpenSettings: onOpenSettings)
                Divider().overlay(YPPalette.line)

                Group {
                    switch section {
                    case .home:
                        HomeView(
                            dictation: dictation,
                            section: $section,
                            onOpenSettings: onOpenSettings
                        )
                    case .dictations:
                        DictationHistoryView(history: dictation.history)
                    case .transcripts:
                        TranscriptWorkspace()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(YPPalette.line)
                ActivityStrip()
            }
            .background(YPPalette.canvas)
        }
        .dropDestination(for: URL.self) { urls, _ in
            // Dropping media always means transcription, so follow the user
            // there rather than filing it somewhere out of sight.
            section = .transcripts
            store.add(urls: urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            DropIndicator(isVisible: isDropTargeted)
        }
    }
}
