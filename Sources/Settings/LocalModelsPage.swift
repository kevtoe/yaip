import AppKit
import SwiftUI

/// Download, activate and delete on-device models.
struct LocalModelsPage: View {
    @Bindable var models: ModelManager
    @Bindable var dictation: DictationController

    private var installed: [ModelDescriptor] {
        models.catalog.filter {
            $0.isRegistered == false && models.installation(for: $0).isInstalled
        }
    }

    private var available: [ModelDescriptor] {
        models.catalog.filter {
            $0.isRegistered == false && models.installation(for: $0).isInstalled == false
        }
    }

    private var registered: [ModelDescriptor] {
        models.catalog.filter(\.isRegistered)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
            SettingsGroup(
                title: "Model Library",
                footnote: "Download a model or use a compatible Core ML folder already on this Mac. Yaip never deletes imported folders."
            ) {
                SettingsRow(
                    title: "Use an Existing Model Folder",
                    detail: "Supports WhisperKit and Parakeet TDT v3 Core ML folders."
                ) {
                    Button("Choose Folder…", systemImage: "folder.badge.plus") {
                        chooseExistingModel()
                    }
                }

                if let error = models.importError {
                    Divider().overlay(YPPalette.line)
                    HStack(alignment: .top, spacing: YPMetrics.compactSpacing) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(YPPalette.warning)
                            .accessibilityHidden(true)
                        Text(error)
                            .font(YPTypography.supporting)
                            .foregroundStyle(YPPalette.warning)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Dismiss") { models.clearImportError() }
                    }
                    .padding(YPMetrics.standardSpacing)
                }
            }

            if registered.isEmpty == false {
                SettingsGroup(
                    title: "Registered Folders",
                    footnote: "These models stay in their original folders. Forget removes only Yaip's reference."
                ) {
                    ForEach(registered) { model in
                        ModelCard(
                            model: model,
                            installation: models.installation(for: model),
                            registeredPath: model.registeredID.flatMap {
                                models.registeredModel($0)?.modelFolder.lastKnownPath
                            },
                            canDeleteFiles: false,
                            isActive: dictation.config.engine == model.selection,
                            onActivate: { dictation.config.engine = model.selection },
                            onDownload: {},
                            onDelete: {
                                if dictation.config.engine == model.selection {
                                    dictation.config.engine = ModelDescriptor.defaultDictationSelection
                                }
                                if let id = model.registeredID { models.forgetRegisteredModel(id) }
                            },
                            onReveal: {
                                if let id = model.registeredID { models.revealRegisteredModel(id) }
                            },
                            onRelocate: {
                                if let id = model.registeredID { relocateRegisteredModel(id) }
                            }
                        )
                        if model.id != registered.last?.id {
                            Divider().overlay(YPPalette.line)
                        }
                    }
                }
            }

            SettingsGroup(
                title: "Ready to Use",
                footnote: "Included, built-in and downloaded models ready for transcription."
            ) {
                ForEach(installed) { model in
                    ModelCard(
                        model: model,
                        installation: models.installation(for: model),
                        registeredPath: nil,
                        canDeleteFiles: models.canDeleteManagedFiles(for: model),
                        isActive: dictation.config.engine == model.selection,
                        onActivate: { dictation.config.engine = model.selection },
                        onDownload: { startDownload(model) },
                        onDelete: {
                            if dictation.config.engine == model.selection {
                                dictation.config.engine = ModelDescriptor.defaultDictationSelection
                            }
                            models.delete(model)
                        },
                        onReveal: nil,
                        onRelocate: nil
                    )
                    if model.id != installed.last?.id { Divider().overlay(YPPalette.line) }
                }
            }

            if available.isEmpty == false {
                SettingsGroup(title: "Available to Download") {
                    ForEach(available) { model in
                        ModelCard(
                            model: model,
                            installation: models.installation(for: model),
                            registeredPath: nil,
                            canDeleteFiles: models.canDeleteManagedFiles(for: model),
                            isActive: false,
                            onActivate: { dictation.config.engine = model.selection },
                            onDownload: { startDownload(model) },
                            onDelete: { models.delete(model) },
                            onReveal: nil,
                            onRelocate: nil
                        )
                        if model.id != available.last?.id { Divider().overlay(YPPalette.line) }
                    }
                }
            }

            SettingsGroup(
                title: "Storage",
                footnote: "Downloaded models stay in Yaip's Application Support folder."
            ) {
                SettingsRow(
                    title: "Downloaded Models",
                    detail: "Stored outside Documents and cloud-synced folders."
                ) {
                    HStack(spacing: YPMetrics.compactSpacing) {
                        Text(models.totalBytesOnDisk.formatted(.byteCount(style: .file)))
                            .font(YPTypography.metadata)
                            .foregroundStyle(YPPalette.inkMuted)
                        Button("Reveal", action: models.revealManagedModels)
                    }
                }

                Divider().overlay(YPPalette.line)

                if models.strayModelBytes > 0 {
                    SettingsRow(
                        title: "Models in your Documents folder",
                        detail: "\(models.strayModelBytes.formatted(.byteCount(style: .file))) found in ~/Documents/huggingface. This folder may belong to another app."
                    ) {
                        Button("Reveal in Finder") { models.revealStrayModels() }
                    }
                } else {
                    SettingsRow(
                        title: "Check Documents Folder",
                        detail: "Look for older model downloads in ~/Documents/huggingface."
                    ) {
                        Button("Check") {
                            Task { await models.checkForStrayModels() }
                        }
                    }
                }
            }
        }
        .task {
            await models.refresh()
        }
    }

    private func chooseExistingModel() {
        models.clearImportError()
        guard let modelURL = chooseFolder(
            message: "Choose the folder that directly contains the Core ML model files."
        ) else { return }

        Task { @MainActor in
            let engine: LocalModelEngine
            do {
                engine = try await Task.detached(priority: .userInitiated) {
                    try ModelFolderValidator.detectEngine(in: modelURL)
                }.value
            } catch {
                await models.registerModelFolder(modelURL)
                return
            }

            var tokenizerURL: URL?
            if engine == .whisperKit,
               ModelFolderValidator.hasWhisperTokenizer(in: modelURL) == false {
                tokenizerURL = chooseFolder(
                    message: "Choose the matching Whisper tokenizer folder containing tokenizer.json and tokenizer_config.json."
                )
                guard tokenizerURL != nil else { return }
            }
            await models.registerModelFolder(modelURL, tokenizerFolder: tokenizerURL)
        }
    }

    private func startDownload(_ model: ModelDescriptor) {
        Task {
            await models.download(model)
        }
    }

    private func chooseFolder(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func relocateRegisteredModel(_ id: UUID) {
        guard let registration = models.registeredModel(id),
              let modelURL = chooseFolder(
                message: "Choose the replacement \(registration.engine.displayName) folder."
              ) else { return }

        var tokenizerURL: URL?
        if registration.engine == .whisperKit,
           ModelFolderValidator.hasWhisperTokenizer(in: modelURL) == false {
            tokenizerURL = chooseFolder(
                message: "Choose the matching Whisper tokenizer folder."
            )
            guard tokenizerURL != nil else { return }
        }
        Task {
            await models.relocateRegisteredModel(
                id,
                modelFolder: modelURL,
                tokenizerFolder: tokenizerURL
            )
        }
    }
}

private struct ModelCard: View {
    let model: ModelDescriptor
    let installation: ModelInstallation
    let registeredPath: String?
    let canDeleteFiles: Bool
    let isActive: Bool
    let onActivate: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onReveal: (() -> Void)?
    let onRelocate: (() -> Void)?

    var body: some View {
        HStack(spacing: YPMetrics.standardSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: YPMetrics.compactSpacing) {
                    Text(model.displayName)
                        .font(YPTypography.controlLabel)
                        .foregroundStyle(YPPalette.ink)
                    if model.isSystemManaged {
                        Badge(text: "Built in", tint: YPPalette.accent)
                    } else if installation == .bundled {
                        Badge(text: "Included", tint: YPPalette.accent)
                    } else if model.isRegistered {
                        Badge(text: "Used in place", tint: YPPalette.importedModel)
                    }
                }
                Text("\(installation == .bundled ? "Included" : model.formattedSize) · \(model.languageSummary)")
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.inkSoft)
                if let registeredPath {
                    Text(registeredPath)
                        .font(YPTypography.metadata)
                        .foregroundStyle(YPPalette.inkSoft)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(registeredPath)
                }
            }

            Spacer(minLength: 0)
            control
        }
        .padding(.horizontal, YPMetrics.standardSpacing)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var control: some View {
        switch installation {
        case .downloading(let fraction):
            HStack(spacing: YPMetrics.compactSpacing) {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(width: 90)
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(YPTypography.metadata)
                    .foregroundStyle(YPPalette.inkMuted)
            }

        case .notDownloaded:
            Button("Download", action: onDownload)
                .buttonStyle(.bordered)

        case .installed, .systemManaged, .bundled, .registered:
            HStack(spacing: YPMetrics.compactSpacing) {
                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(YPTypography.supporting)
                        .foregroundStyle(YPPalette.accent)
                } else {
                    Button("Activate", action: onActivate)
                        .buttonStyle(.bordered)
                }

                if installation == .registered, isActive == false {
                    if let onReveal {
                        Button("Reveal", systemImage: "folder", action: onReveal)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .foregroundStyle(YPPalette.inkSoft)
                            .help("Reveal this model folder in Finder")
                    }
                    Button("Forget", systemImage: "minus.circle", action: onDelete)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(YPPalette.inkSoft)
                        .help("Forget this folder without deleting its files")
                } else if case .installed = installation,
                          isActive == false,
                          canDeleteFiles {
                    Button("Delete", systemImage: "trash", action: onDelete)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(YPPalette.inkSoft)
                        .help("Delete this model from disk")
                }
            }

        case .unavailable(let reason):
            VStack(alignment: .trailing, spacing: YPMetrics.compactSpacing) {
                Text(reason)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.warning)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                HStack {
                    if let onRelocate {
                        Button("Locate…", action: onRelocate)
                    }
                    Button("Forget", role: .destructive, action: onDelete)
                }
            }

        case .downloadFailed(let reason):
            VStack(alignment: .trailing, spacing: YPMetrics.compactSpacing) {
                Text(reason)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.critical)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                Button("Retry", action: onDownload)
            }
        }
    }
}

struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(YPTypography.metadata)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: .rect(cornerRadius: 4))
    }
}
