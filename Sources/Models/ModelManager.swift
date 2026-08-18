import AppKit
import Foundation
import Observation
import OSLog

/// Knows which local models are on disk, downloads them, and deletes them.
///
/// Both SDKs fetch models silently on first use, which means a user's first
/// dictation stalls for minutes with no explanation and no way to see what is
/// stored. This makes the state visible and the storage reclaimable.
@MainActor
@Observable
final class ModelManager {
    private let log = Logger(subsystem: "app.yaip.v1", category: "Models")
    private let defaults: UserDefaults

    private(set) var installations = [String: ModelInstallation]()
    private(set) var registeredModels = [RegisteredLocalModel]()
    private(set) var importError: String?
    private(set) var totalBytesOnDisk: Int64 = 0
    /// Set when weights are found in WhisperKit's legacy Documents location.
    private(set) var strayModelBytes: Int64 = 0

    /// Deliberately does no filesystem work. `refresh()` is async and must be
    /// awaited from a task, never run during init: scanning happens on a
    /// background thread because a cloud-synced folder can block a stat call
    /// indefinitely while the provider materialises files, and doing that on
    /// the main thread at launch hangs the app before any window appears.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadRegisteredModels()
    }

    private func loadRegisteredModels() {
        registeredModels = defaults.data(forKey: Key.registeredModels.rawValue)
            .flatMap { try? JSONDecoder().decode([RegisteredLocalModel].self, from: $0) }
            ?? []
    }

    var catalog: [ModelDescriptor] {
        ModelDescriptor.builtIns + registeredModels.map(ModelDescriptor.registered)
    }

    func installation(for model: ModelDescriptor) -> ModelInstallation {
        installations[model.id] ?? .notDownloaded
    }

    func canDeleteManagedFiles(for model: ModelDescriptor) -> Bool {
        guard model.isRegistered == false,
              let directory = Self.directory(for: model) else { return false }
        return directory.standardizedFileURL.path.hasPrefix(
            ModelStorage.root.standardizedFileURL.path + "/"
        )
    }

    func refresh() async {
        let models = ModelDescriptor.builtIns.filter {
            installations[$0.id]?.isDownloading != true
        }

        let scanned = await Self.scan(models)
        for (id, installation) in scanned {
            installations[id] = installation
        }
        totalBytesOnDisk = await Self.totalManagedBytes()
        await refreshRegisteredModels()
    }

    /// Looks for weights left in WhisperKit's legacy Documents location.
    ///
    /// Explicitly user-triggered, never automatic: reading Documents can make
    /// macOS prompt for access, so Yaip only checks when asked.
    func checkForStrayModels() async {
        strayModelBytes = await Self.strayBytes()
        if strayModelBytes > 0 {
            log.warning("Found \(self.strayModelBytes) bytes of models in the Documents folder")
        }
    }

    // MARK: Download

    func download(_ model: ModelDescriptor) async {
        await download(model, configuration: ModelDownloadConfiguration.standard())
    }

    private func download(
        _ model: ModelDescriptor,
        configuration: URLSessionConfiguration
    ) async {
        guard installations[model.id]?.isDownloading != true else { return }
        installations[model.id] = .downloading(fraction: 0)
        log.notice("Downloading \(model.id, privacy: .public)")

        do {
            try await ModelRepositoryDownloader.download(
                model,
                configuration: configuration,
                onProgress: { [weak self] fraction in
                    Task { @MainActor in
                        self?.installations[model.id] = .downloading(fraction: fraction)
                    }
                }
            )
            await RunnerRegistry.shared.evictAll()
            _ = try await prepare(model)
            await refresh()
            log.notice("Downloaded \(model.id, privacy: .public)")
        } catch {
            installations[model.id] = .downloadFailed(reason: error.localizedDescription)
            log.error("Download failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func prepare(_ model: ModelDescriptor) async throws -> (any TranscriptionRunner, EngineSelection) {
        try await RunnerRegistry.shared.prepared(
            for: RunnerConfig(engine: model.selection)
        )
    }

    // MARK: Delete

    func delete(_ model: ModelDescriptor) {
        if let id = model.registeredID {
            forgetRegisteredModel(id)
            return
        }
        guard canDeleteManagedFiles(for: model),
              let directory = Self.directory(for: model) else {
            log.error("Refused to delete model outside Yaip's managed storage")
            return
        }
        do {
            try FileManager.default.removeItem(at: directory)
            installations[model.id] = .notDownloaded
            log.notice("Deleted \(model.id, privacy: .public)")
            Task { await refresh() }
        } catch {
            log.error("Delete failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Existing folders

    func registerModelFolder(_ modelFolder: URL, tokenizerFolder: URL? = nil) async {
        importError = nil
        do {
            let engine = try await Task.detached(priority: .userInitiated) {
                try ModelFolderValidator.detectEngine(in: modelFolder)
            }.value

            let resolvedTokenizer = tokenizerFolder
            if engine == .whisperKit,
               ModelFolderValidator.hasWhisperTokenizer(in: modelFolder) == false,
               resolvedTokenizer == nil {
                throw ModelFolderValidator.ValidationError.tokenizerRequired
            }

            try await Task.detached(priority: .userInitiated) {
                try ModelFolderValidator.validate(
                    modelFolder: modelFolder,
                    engine: engine,
                    tokenizerFolder: resolvedTokenizer
                )
            }.value

            if registeredModels.contains(where: {
                (try? $0.modelFolder.resolve().url.standardizedFileURL)
                    == modelFolder.standardizedFileURL
            }) {
                throw RegistrationError.alreadyRegistered
            }

            let registration = try RegisteredLocalModel(
                id: UUID(),
                displayName: suggestedName(for: modelFolder, engine: engine),
                engine: engine,
                modelFolder: FolderBookmark(url: modelFolder),
                tokenizerFolder: try resolvedTokenizer.map(FolderBookmark.init(url:)),
                addedAt: .now
            )
            registeredModels.append(registration)
            persistRegisteredModels()
            installations[ModelDescriptor.registered(registration).id] = .registered
            log.notice("Registered local model \(registration.id.uuidString, privacy: .public)")
        } catch {
            importError = error.localizedDescription
            log.error("Registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func forgetRegisteredModel(_ id: UUID) {
        registeredModels.removeAll { $0.id == id }
        installations.removeValue(forKey: "registered-\(id.uuidString)")
        persistRegisteredModels()
        Task { await RunnerRegistry.shared.evict(selectionID: id) }
    }

    func clearImportError() {
        importError = nil
    }

    func registeredModel(_ id: UUID) -> RegisteredLocalModel? {
        registeredModels.first { $0.id == id }
    }

    func isRegistered(_ id: UUID) -> Bool {
        registeredModels.contains { $0.id == id }
    }

    func relocateRegisteredModel(
        _ id: UUID,
        modelFolder: URL,
        tokenizerFolder: URL? = nil
    ) async {
        importError = nil
        guard let index = registeredModels.firstIndex(where: { $0.id == id }) else { return }

        do {
            let registration = registeredModels[index]
            let detected = try await Task.detached(priority: .userInitiated) {
                try ModelFolderValidator.detectEngine(in: modelFolder)
            }.value
            guard detected == registration.engine else {
                throw RegistrationError.wrongEngine(expected: registration.engine)
            }
            try await Task.detached(priority: .userInitiated) {
                try ModelFolderValidator.validate(
                    modelFolder: modelFolder,
                    engine: registration.engine,
                    tokenizerFolder: tokenizerFolder
                )
            }.value

            registeredModels[index].modelFolder = try FolderBookmark(url: modelFolder)
            registeredModels[index].tokenizerFolder = try tokenizerFolder.map(FolderBookmark.init(url:))
            persistRegisteredModels()
            installations["registered-\(id.uuidString)"] = .registered
            await RunnerRegistry.shared.evict(selectionID: id)
        } catch {
            importError = error.localizedDescription
        }
    }

    func revealRegisteredModel(_ id: UUID) {
        guard let model = registeredModel(id),
              let url = try? model.modelFolder.resolve().url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func resolveRegisteredModel(_ id: UUID) async -> ResolvedRegisteredModel? {
        guard let index = registeredModels.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        do {
            var registration = registeredModels[index]
            let snapshot = registration
            let resolved = try await Task.detached(priority: .utility) { @Sendable in
                let modelResolution = try snapshot.modelFolder.resolve()
                let modelScope = SecurityScopedFolder(url: modelResolution.url)

                var tokenizerResolution: (url: URL, isStale: Bool)?
                var tokenizerScope: SecurityScopedFolder?
                if let bookmark = snapshot.tokenizerFolder {
                    tokenizerResolution = try bookmark.resolve()
                    tokenizerScope = SecurityScopedFolder(url: tokenizerResolution!.url)
                }

                try ModelFolderValidator.validate(
                    modelFolder: modelScope.url,
                    engine: snapshot.engine,
                    tokenizerFolder: tokenizerScope?.url
                )
                return (modelResolution, modelScope, tokenizerResolution, tokenizerScope)
            }.value

            if resolved.0.isStale {
                registration.modelFolder = try FolderBookmark(url: resolved.0.url)
            }
            if let tokenizerResolution = resolved.2, tokenizerResolution.isStale {
                registration.tokenizerFolder = try FolderBookmark(url: tokenizerResolution.url)
            }

            if registration != registeredModels[index] {
                registeredModels[index] = registration
                persistRegisteredModels()
            }

            return ResolvedRegisteredModel(
                registration: registration,
                modelFolder: resolved.1,
                tokenizerFolder: resolved.3
            )
        } catch {
            installations["registered-\(id.uuidString)"] = .unavailable(
                reason: error.localizedDescription
            )
            return nil
        }
    }

    /// Opens the legacy cache so the user can decide what owns it. It may be
    /// shared with another transcription app, so Yaip must not delete it.
    func revealStrayModels() {
        let location = ModelStorage.legacyDocumentsLocation
        NSWorkspace.shared.activateFileViewerSelecting([location])
    }

    func revealManagedModels() {
        NSWorkspace.shared.activateFileViewerSelecting([ModelStorage.root])
    }

    // MARK: Scanning, off the main thread

    private static func scan(
        _ models: [ModelDescriptor]
    ) async -> [String: ModelInstallation] {
        await Task.detached(priority: .utility) {
            var result = [String: ModelInstallation]()
            for model in models {
                switch model.selection {
                case .appleSpeech:
                    result[model.id] = .systemManaged
                case .whisperKit, .fluidParakeet:
                    if case .whisperKit(let name) = model.selection,
                       ModelStorage.hasBundledWhisper(name) {
                        result[model.id] = .bundled
                        continue
                    }
                    guard let directory = directory(for: model) else {
                        result[model.id] = .notDownloaded
                        continue
                    }
                    let valid: Bool
                    switch model.selection {
                    case .whisperKit(let name):
                        valid = (try? ModelFolderValidator.validate(
                            modelFolder: directory,
                            engine: .whisperKit,
                            tokenizerFolder: ModelStorage.whisperKitTokenizer(name)
                        )) != nil
                    case .fluidParakeet:
                        valid = (try? ModelFolderValidator.validate(
                            modelFolder: directory,
                            engine: .parakeetV3
                        )) != nil
                    default:
                        valid = false
                    }
                    result[model.id] = valid
                        ? .installed(bytes: managedSize(for: model))
                        : .notDownloaded
                case .registeredLocal:
                    break
                }
            }
            return result
        }.value
    }

    private static func strayBytes() async -> Int64 {
        let location = ModelStorage.legacyDocumentsLocation
        return await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: location.path) else { return 0 }
            return size(of: location)
        }.value
    }

    private static func totalManagedBytes() async -> Int64 {
        await Task.detached(priority: .utility) {
            var total = size(of: ModelStorage.root)
            for model in ParakeetModel.allCases {
                let managed = ModelStorage.parakeetDownloadTarget(model.rawValue)
                let legacy = ModelStorage.legacyFluidAudioModel(model.rawValue)
                if FileManager.default.fileExists(atPath: managed.path) == false,
                   FileManager.default.fileExists(atPath: legacy.path) {
                    total += size(of: legacy)
                }
            }
            return total
        }.value
    }

    private nonisolated static func directory(for model: ModelDescriptor) -> URL? {
        switch model.selection {
        case .fluidParakeet(let name): ModelStorage.parakeetModel(name)
        case .whisperKit(let name):    ModelStorage.whisperKitModel(name)
        case .appleSpeech, .registeredLocal: nil
        }
    }

    private nonisolated static func size(of directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            total += Int64(size ?? 0)
        }
        return total
    }

    private nonisolated static func managedSize(for model: ModelDescriptor) -> Int64 {
        guard let modelDirectory = directory(for: model) else { return 0 }
        var total = size(of: modelDirectory)
        if case .whisperKit(let name) = model.selection,
           let tokenizer = ModelStorage.whisperKitTokenizer(name) {
            total += size(of: tokenizer)
        }
        return total
    }

    private func refreshRegisteredModels() async {
        for model in registeredModels {
            let descriptor = ModelDescriptor.registered(model)
            installations[descriptor.id] = await resolveRegisteredModel(model.id) == nil
                ? installations[descriptor.id] ?? .unavailable(reason: "The folder is unavailable.")
                : .registered
        }
    }

    private func persistRegisteredModels() {
        guard let data = try? JSONEncoder().encode(registeredModels) else { return }
        defaults.set(data, forKey: Key.registeredModels.rawValue)
    }

    private func suggestedName(for folder: URL, engine: LocalModelEngine) -> String {
        let raw = folder.lastPathComponent
            .replacingOccurrences(of: "-coreml", with: "")
            .replacingOccurrences(of: "_", with: " ")
        return raw.isEmpty ? engine.displayName : raw
    }

    private enum Key: String {
        case registeredModels = "models.registered.v1"
    }

    private enum RegistrationError: LocalizedError {
        case alreadyRegistered
        case wrongEngine(expected: LocalModelEngine)

        var errorDescription: String? {
            switch self {
            case .alreadyRegistered:
                "That model folder is already registered."
            case .wrongEngine(let expected):
                "Choose another \(expected.displayName) folder for this registration."
            }
        }
    }
}
