import Foundation
import XCTest
@testable import Yaip

final class RunnerRegistryTests: XCTestCase {

    func testConcurrentRequestsShareOnePreparation() async throws {
        let counter = PreparationCounter()
        let registry = RunnerRegistry { _ in FakeRunner(counter: counter) }
        let config = RunnerConfig(engine: .whisperKit(model: WhisperModel.tiny.rawValue))

        async let first = registry.prepared(for: config)
        async let second = registry.prepared(for: config)
        _ = try await (first, second)

        let preparationCount = await counter.value
        XCTAssertEqual(preparationCount, 1)
    }
}

private actor PreparationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private actor FakeRunner: TranscriptionRunner {
    nonisolated static let identifier = "fake"
    nonisolated let capabilities = RunnerCapabilities(
        isLocal: true,
        supportsWordTimestamps: false,
        supportsTranslateToEnglish: false,
        supportsVocabularyPrompt: false,
        supportsLanguageDetection: false,
        languageSupport: .all,
        maximumDuration: nil
    )

    private let counter: PreparationCounter

    init(counter: PreparationCounter) {
        self.counter = counter
    }

    func prepare(onProgress: @Sendable @escaping (Double) -> Void) async throws {
        await counter.increment()
        try await Task.sleep(for: .milliseconds(50))
        onProgress(1)
    }

    func transcribe(
        _ audio: AudioBuffer,
        options: TranscriptionOptions,
        onProgress: @Sendable @escaping (RunnerProgress) -> Void
    ) async throws -> TranscriptionResult {
        TranscriptionResult(
            segments: [],
            detectedLanguage: nil,
            engineIdentifier: Self.identifier,
            modelIdentifier: "fake",
            elapsed: .zero
        )
    }

    func teardown() async {}
}
