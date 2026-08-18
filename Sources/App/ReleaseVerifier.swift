import AppKit
import Darwin
import Foundation

/// Command-line smoke test used by the distribution pipeline on every slice.
@MainActor
enum ReleaseVerifier {
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--verify-model-download"),
           arguments.indices.contains(index + 2) {
            NSApp.setActivationPolicy(.prohibited)
            let modelID = arguments[index + 1]
            let sample = URL(filePath: arguments[index + 2])
            Task {
                do {
                    guard let descriptor = ModelDescriptor.builtIns.first(where: { $0.id == modelID }) else {
                        throw RunnerError.engineFailure("Unknown model \(modelID).")
                    }
                    let progress = VerificationProgressPrinter()
                    let downloadConfiguration = ModelDownloadConfiguration.standard()
                    try await ModelRepositoryDownloader.download(
                        descriptor,
                        configuration: downloadConfiguration,
                        onProgress: { fraction in
                            progress.report(fraction)
                        }
                    )
                    await RunnerRegistry.shared.evictAll()
                    let (runner, _) = try await RunnerRegistry.shared.prepared(
                        for: RunnerConfig(engine: descriptor.selection)
                    )
                    let audio = try await AudioLoader.load(url: sample)
                    let result = try await runner.transcribe(
                        audio,
                        options: TranscriptionOptions(
                            from: RunnerConfig(
                                engine: descriptor.selection,
                                language: .fixed("en")
                            )
                        ),
                        onProgress: { _ in }
                    )
                    guard result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                        throw RunnerError.engineFailure("Downloaded model returned no text.")
                    }
                    print("YAIP_MODEL_DOWNLOAD_VERIFY_OK \(modelID) \(result.text.count)")
                    fflush(stdout)
                    exit(EXIT_SUCCESS)
                } catch {
                    fputs("YAIP_MODEL_DOWNLOAD_VERIFY_FAILED \(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
            return true
        }

        guard let flag = arguments.firstIndex(of: "--verify-bundled-model"),
              arguments.indices.contains(flag + 1) else { return false }

        NSApp.setActivationPolicy(.prohibited)
        let sample = URL(filePath: arguments[flag + 1])
        Task {
            do {
                guard ModelStorage.hasBundledWhisper(WhisperModel.tiny.rawValue) else {
                    throw RunnerError.engineFailure("Bundled Whisper Tiny assets are missing.")
                }
                let audio = try await AudioLoader.load(url: sample)
                let runner = WhisperKitRunner(model: WhisperModel.tiny.rawValue)
                try await runner.prepare(onProgress: { _ in })
                let config = RunnerConfig(
                    engine: .whisperKit(model: WhisperModel.tiny.rawValue),
                    language: .fixed("en")
                )
                let result = try await runner.transcribe(
                    audio,
                    options: TranscriptionOptions(from: config),
                    onProgress: { _ in }
                )
                guard result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw RunnerError.engineFailure("Bundled Whisper Tiny returned no text.")
                }
                print("YAIP_RELEASE_VERIFY_OK \(PlatformSupport.architecture) \(result.text.count)")
                fflush(stdout)
                exit(EXIT_SUCCESS)
            } catch {
                fputs("YAIP_RELEASE_VERIFY_FAILED \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }
        return true
    }

}

private final class VerificationProgressPrinter: @unchecked Sendable {
    private let lock = NSLock()
    private var lastBucket = -1

    func report(_ fraction: Double) {
        let bucket = min(10, max(0, Int(fraction * 10)))
        let shouldPrint = lock.withLock { () -> Bool in
            guard bucket > lastBucket else { return false }
            lastBucket = bucket
            return true
        }
        if shouldPrint {
            fputs("YAIP_MODEL_DOWNLOAD_PROGRESS \(bucket * 10)\n", stderr)
        }
    }
}
