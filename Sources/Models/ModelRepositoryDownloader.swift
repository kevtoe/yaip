import CryptoKit
import Foundation

/// Yaip-owned Hugging Face transport for model downloads.
///
/// This layer rejects HTML interstitials, verifies LFS SHA-256 values and only
/// exposes a complete local folder to the runners.
enum ModelRepositoryDownloader {
    typealias Progress = @Sendable (Double) -> Void

    struct LFSMetadata: Decodable, Sendable {
        let oid: String
        let size: Int64
    }

    struct TreeItem: Decodable, Sendable {
        let type: String
        let path: String
        let size: Int64?
        let lfs: LFSMetadata?
    }

    private struct RemoteFile: Sendable {
        let repository: String
        let path: String
        let relativeDestination: String
        let size: Int64
        let sha256: String?
    }

    static func download(
        _ model: ModelDescriptor,
        configuration: URLSessionConfiguration,
        onProgress: @escaping Progress
    ) async throws {
        switch model.selection {
        case .whisperKit(let name):
            try await downloadWhisper(
                name: name,
                configuration: configuration,
                onProgress: onProgress
            )
        case .fluidParakeet(let name):
            guard name == ParakeetModel.v3.rawValue else {
                throw ModelRepositoryError.unsupportedModel(name)
            }
            try await downloadParakeet(
                name: name,
                configuration: configuration,
                onProgress: onProgress
            )
        case .appleSpeech, .registeredLocal:
            throw ModelRepositoryError.unsupportedModel(model.id)
        }
    }

    static func testRegistry(configuration: URLSessionConfiguration) async throws -> String {
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let url = try treeURL(repository: "argmaxinc/whisperkit-coreml", path: "")
        let (_, response) = try await fetchTreePage(url: url, session: session)
        return "Connected directly to \(response.url?.host ?? "huggingface.co") (HTTP \(response.statusCode), \(response.value(forHTTPHeaderField: "Content-Type") ?? "unknown"))."
    }

    private static func downloadWhisper(
        name: String,
        configuration: URLSessionConfiguration,
        onProgress: @escaping Progress
    ) async throws {
        guard let model = WhisperModel(rawValue: name),
              let tokenizerTarget = ModelStorage.whisperKitTokenizer(name) else {
            throw ModelRepositoryError.unsupportedModel(name)
        }

        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let modelItems = try await listTree(
            repository: "argmaxinc/whisperkit-coreml",
            path: name,
            session: session,
            recurse: { _ in true },
            include: { _ in true }
        )
        let modelFiles = modelItems.map { item in
            remoteFile(
                item,
                repository: "argmaxinc/whisperkit-coreml",
                destination: removingPrefix("\(name)/", from: item.path)
            )
        }

        let tokenizerRepository = tokenizerRepository(for: model)
        let tokenizerNames: Set<String> = ["config.json", "tokenizer.json", "tokenizer_config.json"]
        let tokenizerItems = try await listTree(
            repository: tokenizerRepository,
            path: "",
            session: session,
            recurse: { _ in false },
            include: { tokenizerNames.contains($0) }
        )
        let tokenizerFiles = tokenizerItems.map {
            remoteFile($0, repository: tokenizerRepository, destination: $0.path)
        }

        guard modelFiles.isEmpty == false,
              Set(tokenizerFiles.map(\.relativeDestination)) == tokenizerNames else {
            throw ModelRepositoryError.incompleteListing(name)
        }

        try await stageAndInstall(
            groups: [
                (files: modelFiles, target: ModelStorage.whisperKitModel(name)),
                (files: tokenizerFiles, target: tokenizerTarget),
            ],
            configuration: configuration,
            onProgress: onProgress
        ) { staged in
            try ModelFolderValidator.validate(
                modelFolder: staged[0],
                engine: .whisperKit,
                tokenizerFolder: staged[1]
            )
        }
    }

    private static func downloadParakeet(
        name: String,
        configuration: URLSessionConfiguration,
        onProgress: @escaping Progress
    ) async throws {
        let repository = "FluidInference/parakeet-tdt-0.6b-v3-coreml"
        let directories = [
            "Preprocessor.mlmodelc",
            "Encoder.mlmodelc",
            "Decoder.mlmodelc",
            "JointDecisionv3.mlmodelc",
        ]
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let items = try await listTree(
            repository: repository,
            path: "",
            session: session,
            recurse: { path in
                directories.contains(path)
                    || directories.contains { path.hasPrefix("\($0)/") }
            },
            include: { path in
                path == "parakeet_vocab.json"
                    || directories.contains { path.hasPrefix("\($0)/") }
            }
        )
        let files = items.map { remoteFile($0, repository: repository, destination: $0.path) }
        guard files.isEmpty == false else { throw ModelRepositoryError.incompleteListing(name) }

        try await stageAndInstall(
            groups: [(files: files, target: ModelStorage.parakeetDownloadTarget(name))],
            configuration: configuration,
            onProgress: onProgress
        ) { staged in
            try ModelFolderValidator.validate(modelFolder: staged[0], engine: .parakeetV3)
        }
    }

    private static func listTree(
        repository: String,
        path: String,
        session: URLSession,
        recurse: (String) -> Bool,
        include: (String) -> Bool
    ) async throws -> [TreeItem] {
        var files = [TreeItem]()
        var next: URL? = try treeURL(repository: repository, path: path)
        var visited = Set<URL>()
        while let url = next {
            guard visited.insert(url).inserted else { break }
            let (items, response) = try await fetchTreePage(url: url, session: session)
            for item in items {
                if item.type == "directory", recurse(item.path) {
                    files += try await listTree(
                        repository: repository,
                        path: item.path,
                        session: session,
                        recurse: recurse,
                        include: include
                    )
                } else if item.type == "file", include(item.path) {
                    files.append(item)
                }
            }
            next = nextPage(from: response)
        }
        return files
    }

    private static func fetchTreePage(
        url: URL,
        session: URLSession
    ) async throws -> ([TreeItem], HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Yaip/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ModelRepositoryError.invalidResponse
        }
        try validateResponse(data: data, response: response, expectedJSON: true)
        do {
            return (try JSONDecoder().decode([TreeItem].self, from: data), response)
        } catch {
            throw ModelRepositoryError.invalidJSON(response.url?.host ?? "unknown")
        }
    }

    private static func stageAndInstall(
        groups: [(files: [RemoteFile], target: URL)],
        configuration: URLSessionConfiguration,
        onProgress: @escaping Progress,
        validate: ([URL]) throws -> Void
    ) async throws {
        let total = groups.flatMap(\.files).reduce(Int64(0)) { $0 + max(0, $1.size) }
        var completed: Int64 = 0
        var staged = [URL]()
        do {
            for group in groups {
                let stage = group.target.deletingLastPathComponent()
                    .appending(path: ".\(group.target.lastPathComponent).download-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
                staged.append(stage)
                for file in group.files {
                    try Task.checkCancellation()
                    let completedBeforeFile = completed
                    let destination = stage.appending(path: file.relativeDestination)
                    try FileManager.default.createDirectory(
                        at: destination.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try await downloadFile(
                        file,
                        to: destination,
                        configuration: configuration
                    ) { written in
                        guard total > 0 else { return }
                        onProgress(
                            min(
                                0.94,
                                Double(completedBeforeFile + written) / Double(total) * 0.94
                            )
                        )
                    }
                    completed += max(0, file.size)
                }
            }
            try validate(staged)
            try install(staged: staged, targets: groups.map(\.target))
            onProgress(1)
        } catch {
            staged.forEach { try? FileManager.default.removeItem(at: $0) }
            throw error
        }
    }

    private static func downloadFile(
        _ file: RemoteFile,
        to destination: URL,
        configuration: URLSessionConfiguration,
        onProgress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        let remote = try resolveURL(repository: file.repository, path: file.path)
        var request = URLRequest(url: remote)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("Yaip/1", forHTTPHeaderField: "User-Agent")
        let transfer = SingleFileTransfer(
            configuration: configuration,
            request: request,
            destination: destination,
            onProgress: onProgress
        )
        let response = try await transfer.run()
        let prefix = (try? Data(contentsOf: destination, options: .mappedIfSafe).prefix(128)) ?? Data()
        try validateResponse(data: Data(prefix), response: response, expectedJSON: false)
        let actualSize = (try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? -1
        guard file.size < 0 || actualSize == file.size else {
            throw ModelRepositoryError.sizeMismatch(file.path, expected: file.size, actual: actualSize)
        }
        if let expected = file.sha256 {
            let actual = try sha256(of: destination)
            guard actual == expected else {
                throw ModelRepositoryError.hashMismatch(file.path)
            }
        }
    }

    private static func install(staged: [URL], targets: [URL]) throws {
        let token = UUID().uuidString
        var backups = [(target: URL, backup: URL)]()
        do {
            for (stage, target) in zip(staged, targets) {
                try FileManager.default.createDirectory(
                    at: target.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if FileManager.default.fileExists(atPath: target.path) {
                    let backup = target.deletingLastPathComponent()
                        .appending(path: ".\(target.lastPathComponent).backup-\(token)")
                    try FileManager.default.moveItem(at: target, to: backup)
                    backups.append((target, backup))
                }
                try FileManager.default.moveItem(at: stage, to: target)
            }
            backups.forEach { try? FileManager.default.removeItem(at: $0.backup) }
        } catch {
            for (target, backup) in backups.reversed() {
                try? FileManager.default.removeItem(at: target)
                try? FileManager.default.moveItem(at: backup, to: target)
            }
            throw error
        }
    }

    static func validateResponse(
        data: Data,
        response: HTTPURLResponse,
        expectedJSON: Bool
    ) throws {
        guard 200..<300 ~= response.statusCode else {
            throw ModelRepositoryError.httpStatus(response.statusCode, response.url?.host ?? "unknown")
        }
        let type = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let prefix = String(decoding: data.prefix(128), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isHTML = type.contains("text/html")
            || prefix.hasPrefix("<html")
            || prefix.hasPrefix("<!doctype html")
            || prefix.hasPrefix("<?xml")
        guard isHTML == false else {
            throw ModelRepositoryError.htmlResponse(
                status: response.statusCode,
                host: response.url?.host ?? "unknown",
                contentType: type.isEmpty ? "unknown" : type
            )
        }
        if expectedJSON, type.contains("json") == false, prefix.hasPrefix("[") == false,
           prefix.hasPrefix("{") == false {
            throw ModelRepositoryError.unexpectedContent(response.url?.host ?? "unknown")
        }
    }

    private static func remoteFile(
        _ item: TreeItem,
        repository: String,
        destination: String
    ) -> RemoteFile {
        RemoteFile(
            repository: repository,
            path: item.path,
            relativeDestination: destination,
            size: item.lfs?.size ?? item.size ?? -1,
            sha256: item.lfs?.oid
        )
    }

    private static func tokenizerRepository(for model: WhisperModel) -> String {
        switch model {
        case .tiny: "openai/whisper-tiny"
        case .base: "openai/whisper-base"
        case .small: "openai/whisper-small"
        case .largeV3Turbo, .largeV3: "openai/whisper-large-v3"
        }
    }

    private static func removingPrefix(_ prefix: String, from value: String) -> String {
        value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }

    private static func treeURL(repository: String, path: String) throws -> URL {
        let suffix = path.isEmpty ? "" : "/\(encodedPath(path))"
        guard let url = URL(
            string: "https://huggingface.co/api/models/\(repository)/tree/main\(suffix)"
        ) else { throw ModelRepositoryError.invalidURL }
        return url
    }

    private static func resolveURL(repository: String, path: String) throws -> URL {
        guard let url = URL(
            string: "https://huggingface.co/\(repository)/resolve/main/\(encodedPath(path))?download=true"
        ) else { throw ModelRepositoryError.invalidURL }
        return url
    }

    private static func encodedPath(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }

    private static func nextPage(from response: HTTPURLResponse) -> URL? {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return nil }
        for component in link.split(separator: ",") where component.contains("rel=\"next\"") {
            guard let start = component.firstIndex(of: "<"),
                  let end = component.firstIndex(of: ">"), start < end else { continue }
            return URL(string: String(component[component.index(after: start)..<end]))
        }
        return nil
    }

    private static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), data.isEmpty == false {
            hash.update(data: data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

enum ModelRepositoryError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case invalidJSON(String)
    case unsupportedModel(String)
    case incompleteListing(String)
    case httpStatus(Int, String)
    case htmlResponse(status: Int, host: String, contentType: String)
    case unexpectedContent(String)
    case sizeMismatch(String, expected: Int64, actual: Int64)
    case hashMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The model repository URL is invalid."
        case .invalidResponse: "The model repository returned an invalid response."
        case .invalidJSON(let host): "\(host) returned invalid model metadata."
        case .unsupportedModel(let name): "Yaip cannot download the model \(name)."
        case .incompleteListing(let name): "The remote model \(name) is incomplete."
        case .httpStatus(let status, let host): "Model download failed with HTTP \(status) from \(host)."
        case .htmlResponse(let status, let host, let type):
            "The model service returned an HTML caution page instead of model data (HTTP \(status), \(host), \(type)). Enable Direct model connection and try again."
        case .unexpectedContent(let host): "\(host) returned unexpected model metadata."
        case .sizeMismatch(let path, let expected, let actual):
            "Downloaded \(path) has the wrong size (expected \(expected), received \(actual))."
        case .hashMismatch(let path): "Downloaded \(path) failed its SHA-256 integrity check."
        }
    }
}

private final class SingleFileTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let request: URLRequest
    private let destination: URL
    private let onProgress: @Sendable (Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<HTTPURLResponse, Error>?
    private var response: HTTPURLResponse?
    private var fileWritten = false
    private var session: URLSession?

    init(
        configuration: URLSessionConfiguration,
        request: URLRequest,
        destination: URL,
        onProgress: @escaping @Sendable (Int64) -> Void
    ) {
        self.configuration = configuration
        self.request = request
        self.destination = destination
        self.onProgress = onProgress
    }

    func run() async throws -> HTTPURLResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { self.continuation = continuation }
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                session.downloadTask(with: request).resume()
            }
        } onCancel: {
            self.session?.invalidateAndCancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesWritten)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            lock.withLock {
                response = downloadTask.response as? HTTPURLResponse
                fileWritten = true
            }
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(.failure(error))
            return
        }
        let result: Result<HTTPURLResponse, Error> = lock.withLock {
            guard fileWritten, let response else {
                return .failure(ModelRepositoryError.invalidResponse)
            }
            return .success(response)
        }
        finish(result)
    }

    private func finish(_ result: Result<HTTPURLResponse, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<HTTPURLResponse, Error>? in
            defer { self.continuation = nil }
            return self.continuation
        }
        guard let continuation else { return }
        session?.finishTasksAndInvalidate()
        switch result {
        case .success(let response): continuation.resume(returning: response)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }
}
