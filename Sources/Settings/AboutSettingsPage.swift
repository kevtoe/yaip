import AppKit
import SwiftUI

struct AboutSettingsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
            HStack(spacing: YPMetrics.standardSpacing) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppIdentity.name)
                        .font(YPTypography.windowTitle)
                        .foregroundStyle(YPPalette.ink)
                    Text("\(AppIdentity.tagline) AI in the middle.")
                        .font(YPTypography.sectionTitle)
                        .foregroundStyle(YPPalette.accent)
                    Text("Private Mac dictation that runs locally.")
                        .font(YPTypography.body)
                        .foregroundStyle(YPPalette.inkMuted)
                }
            }

            SettingsGroup {
                SettingsRow(title: "Made by") {
                    Link(AppIdentity.creatorName, destination: AppIdentity.creatorURL)
                }
                Divider().overlay(YPPalette.line)
                SettingsRow(title: "Version") {
                    Text(AppVersion.displayString)
                        .font(YPTypography.metadata)
                        .foregroundStyle(YPPalette.inkMuted)
                }
                Divider().overlay(YPPalette.line)
                SettingsRow(
                    title: "Privacy",
                    detail: "Dictation audio and history stay on this Mac."
                ) {
                    EmptyView()
                }
            }

            SettingsGroup(
                title: "Acknowledgements",
                footnote: "Select an item to read its bundled notice or licence."
            ) {
                ForEach(Array(Acknowledgement.allCases.enumerated()), id: \.element.id) { index, item in
                    AcknowledgementRow(item: item)
                    if index < Acknowledgement.allCases.count - 1 {
                        Divider().overlay(YPPalette.line)
                    }
                }
            }
        }
    }
}

private struct AcknowledgementRow: View {
    let item: Acknowledgement
    @State private var isPresented = false

    var body: some View {
        SettingsRow(title: item.title, detail: item.detail) {
            Button("View") { isPresented = true }
        }
        .sheet(isPresented: $isPresented) {
            LicenceSheet(item: item, isPresented: $isPresented)
        }
    }
}

private struct LicenceSheet: View {
    let item: Acknowledgement
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.title)
                    .font(YPTypography.sectionTitle)
                    .foregroundStyle(YPPalette.ink)
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(YPMetrics.standardSpacing)

            Divider().overlay(YPPalette.line)

            ScrollView {
                Text(item.notice)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(YPPalette.inkMuted)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(YPMetrics.standardSpacing)
            }
        }
        .frame(width: 680, height: 520)
        .background(YPPalette.canvas)
    }
}

private enum Acknowledgement: String, CaseIterable, Identifiable {
    case whisperKit
    case fluidAudio
    case whisper
    case parakeet
    case urbanist

    var id: Self { self }

    var title: String {
        switch self {
        case .whisperKit: "WhisperKit by Argmax"
        case .fluidAudio: "FluidAudio by FluidInference"
        case .whisper:    "Whisper by OpenAI"
        case .parakeet:   "Parakeet TDT v3"
        case .urbanist:   "Urbanist typeface"
        }
    }

    var detail: String {
        switch self {
        case .whisperKit: "Local Whisper inference, MIT licence."
        case .fluidAudio: "Local Parakeet inference, Apache 2.0 licence."
        case .whisper:    "Speech recognition model and source by OpenAI."
        case .parakeet:   "NVIDIA model converted to Core ML by FluidInference, CC BY 4.0."
        case .urbanist:   "Interface typeface by The Urbanist Project Authors."
        }
    }

    var notice: String {
        let names: [String]
        switch self {
        case .whisperKit:
            names = ["ArgmaxOSS-MIT.txt", "ArgmaxOSS-NOTICES.txt"]
        case .fluidAudio:
            names = ["FluidAudio-Apache-2.0.txt"]
        case .whisper:
            names = ["WhisperTiny-Model-Notice.txt", "OpenAI-Whisper-MIT.txt", "Apache-2.0.txt"]
        case .parakeet:
            names = ["Parakeet-TDT-v3-Notice.txt"]
        case .urbanist:
            names = ["Urbanist-OFL.txt"]
        }
        let text = names.compactMap(loadResource).joined(separator: "\n\n")
        return text.isEmpty ? "Notice unavailable." : text
    }

    private func loadResource(_ name: String) -> String? {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let url = Bundle.main.url(forResource: parts[0], withExtension: parts[1])
        else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
