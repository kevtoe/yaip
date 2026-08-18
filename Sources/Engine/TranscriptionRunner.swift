import Foundation

/// The one abstraction every engine implements.
///
/// Runners are actors because model state is mutable, expensive, and must not
/// be touched concurrently. `prepare` must be idempotent: the registry may call
/// it on an instance that is already loaded.
protocol TranscriptionRunner: Actor {
    nonisolated static var identifier: String { get }
    nonisolated var capabilities: RunnerCapabilities { get }

    /// Load models into memory. Idempotent and cancellable.
    func prepare(onProgress: @Sendable @escaping (Double) -> Void) async throws

    func transcribe(
        _ audio: AudioBuffer,
        options: TranscriptionOptions,
        onProgress: @Sendable @escaping (RunnerProgress) -> Void
    ) async throws -> TranscriptionResult

    /// Release model memory. Called on idle timeout or engine switch.
    func teardown() async
}

extension TranscriptionRunner {
    nonisolated var identifier: String { Self.identifier }
}
