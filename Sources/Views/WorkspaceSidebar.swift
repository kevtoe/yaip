import SwiftUI

struct WorkspaceSidebar: View {
    @Binding var section: WorkspaceSection
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(AppIdentity.name)
                        .font(YPTypography.sectionTitle)
                        .foregroundStyle(YPPalette.ink)
                    Text(AppIdentity.tagline)
                        .font(YPTypography.supporting)
                        .foregroundStyle(YPPalette.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)

            Divider().overlay(YPPalette.line)

            List(selection: $section) {
                ForEach(WorkspaceSection.allCases.filter { $0.group == nil }) { item in
                    Label(item.label, systemImage: item.symbol)
                        .tag(item)
                }

                Section("History") {
                    ForEach(WorkspaceSection.allCases.filter { $0.group == "History" }) { item in
                        Label(item.label, systemImage: item.symbol)
                            .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider().overlay(YPPalette.line)

            Button(action: onOpenSettings) {
                Label("Settings", systemImage: "gearshape")
                    .font(YPTypography.body)
                    .foregroundStyle(YPPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: YPMetrics.controlHeight)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .padding(YPMetrics.compactSpacing)
        }
    }
}
