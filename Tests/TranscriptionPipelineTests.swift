import XCTest
@testable import Yaip

/// End-to-end proof that audio decoding, the runner protocol, the registry and
/// a real engine actually work together.
///
/// Opt-in because it downloads a model on first run. Enable with:
/// `YAIP_INTEGRATION=1 YAIP_SAMPLE_AUDIO=/path/to/file xcodebuild test ...`
final class TranscriptionPipelineTests: XCTestCase {

    private var sampleURL: URL? {
        guard ProcessInfo.processInfo.environment["YAIP_INTEGRATION"] == "1",
              let path = ProcessInfo.processInfo.environment["YAIP_SAMPLE_AUDIO"]
        else { return nil }
        return URL(filePath: path)
    }

    func testAudioLoaderProducesSixteenKilohertzMono() async throws {
        guard let sampleURL else {
            throw XCTSkip("Set YAIP_INTEGRATION=1 and YAIP_SAMPLE_AUDIO to run.")
        }

        let audio = try await AudioLoader.load(url: sampleURL)

        XCTAssertFalse(audio.samples.isEmpty, "Decoding produced no samples.")
        // `say` gives us roughly five seconds; allow a wide band so the test
        // does not break if the fixture is regenerated.
        XCTAssertGreaterThan(audio.duration.seconds, 1)
        XCTAssertLessThan(audio.duration.seconds, 60)
        // Sample count must agree with the declared rate, which is the whole
        // point of normalising at the boundary.
        let impliedSeconds = Double(audio.samples.count) / AudioBuffer.sampleRate
        XCTAssertEqual(impliedSeconds, audio.duration.seconds, accuracy: 0.01)
    }

    func testWhisperTinyTranscribesKnownPhrase() async throws {
        guard let sampleURL else {
            throw XCTSkip("Set YAIP_INTEGRATION=1 and YAIP_SAMPLE_AUDIO to run.")
        }
        guard ProcessInfo.processInfo.environment["YAIP_MANAGED_DOWNLOAD_INTEGRATION"] == "1" else {
            throw XCTSkip(
                "Set YAIP_MANAGED_DOWNLOAD_INTEGRATION=1 to test the live model server."
            )
        }

        let audio = try await AudioLoader.load(url: sampleURL)
        // Tiny keeps the download to about 77 MB so the smoke test stays quick.
        let config = RunnerConfig(
            engine: .whisperKit(model: WhisperModel.tiny.rawValue),
            language: .fixed("en")
        )

        let (runner, selection) = try await RunnerRegistry.shared.prepared(for: config)
        XCTAssertEqual(selection, config.engine, "English must not be rerouted.")

        let result = try await runner.transcribe(
            audio,
            options: TranscriptionOptions(from: config),
            onProgress: { _ in }
        )

        XCTAssertFalse(result.segments.isEmpty, "No segments returned.")
        XCTAssertTrue(
            result.text.localizedStandardContains("quick brown fox"),
            "Expected the known phrase, got: \(result.text)"
        )
        XCTAssertGreaterThan(result.elapsed.seconds, 0)
    }

    func testAppleSpeechRunnerCanTranscribeFiveTimesAfterOnePrepare() async throws {
        guard #available(macOS 26, *) else {
            throw XCTSkip("Apple Speech needs macOS 26.")
        }
        guard let sampleURL else {
            throw XCTSkip("Set YAIP_INTEGRATION=1 and YAIP_SAMPLE_AUDIO to run.")
        }

        let audio = try await AudioLoader.load(url: sampleURL)
        let runner = AppleSpeechRunner(localeIdentifier: "en-AU")
        try await runner.prepare(onProgress: { _ in })

        for attempt in 1...5 {
            let result = try await runner.transcribe(
                audio,
                options: TranscriptionOptions(
                    from: RunnerConfig(
                        engine: .appleSpeech(localeIdentifier: "en-AU"),
                        language: .fixed("en")
                    )
                ),
                onProgress: { _ in }
            )
            XCTAssertFalse(result.text.isEmpty, "Attempt \(attempt) returned no text.")
        }
    }

    func testRegisteredWhisperTranscribesWithoutModifyingItsFolders() async throws {
        guard let sampleURL else {
            throw XCTSkip("Set YAIP_INTEGRATION=1 and YAIP_SAMPLE_AUDIO to run.")
        }
        guard let modelURL = environmentURL("YAIP_LOCAL_WHISPER_MODEL"),
              let tokenizerURL = environmentURL("YAIP_LOCAL_WHISPER_TOKENIZER") else {
            throw XCTSkip("No existing WhisperKit model and tokenizer folders were provided.")
        }

        let beforeModel = try folderFingerprint(modelURL)
        let beforeTokenizer = try folderFingerprint(tokenizerURL)
        let resolved = try registeredModel(
            engine: .whisperKit,
            modelURL: modelURL,
            tokenizerURL: tokenizerURL
        )
        let runner = WhisperKitRunner(registered: resolved)
        try await runner.prepare(onProgress: { _ in })

        let audio = try await AudioLoader.load(url: sampleURL)
        let config = RunnerConfig(
            engine: resolved.registration.selection,
            language: .fixed("en")
        )
        let result = try await runner.transcribe(
            audio,
            options: TranscriptionOptions(from: config),
            onProgress: { _ in }
        )
        await runner.teardown()

        XCTAssertFalse(
            result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Imported Whisper produced no text."
        )
        XCTAssertEqual(try folderFingerprint(modelURL), beforeModel)
        XCTAssertEqual(try folderFingerprint(tokenizerURL), beforeTokenizer)
    }

    func testRegisteredParakeetTranscribesWithoutModifyingItsFolder() async throws {
        guard let sampleURL else {
            throw XCTSkip("Set YAIP_INTEGRATION=1 and YAIP_SAMPLE_AUDIO to run.")
        }
        guard let modelURL = environmentURL("YAIP_LOCAL_PARAKEET_MODEL") else {
            throw XCTSkip("No existing Parakeet model folder was provided.")
        }

        let before = try folderFingerprint(modelURL)
        let resolved = try registeredModel(engine: .parakeetV3, modelURL: modelURL)
        let runner = FluidParakeetRunner(registered: resolved)
        try await runner.prepare(onProgress: { _ in })

        let audio = try await AudioLoader.load(url: sampleURL)
        let config = RunnerConfig(
            engine: resolved.registration.selection,
            language: .fixed("en")
        )
        let result = try await runner.transcribe(
            audio,
            options: TranscriptionOptions(from: config),
            onProgress: { _ in }
        )
        await runner.teardown()

        XCTAssertFalse(result.text.isEmpty)
        XCTAssertEqual(try folderFingerprint(modelURL), before)
    }

    private func environmentURL(_ key: String) -> URL? {
        guard let path = ProcessInfo.processInfo.environment[key],
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(filePath: path)
    }

    private func registeredModel(
        engine: LocalModelEngine,
        modelURL: URL,
        tokenizerURL: URL? = nil
    ) throws -> ResolvedRegisteredModel {
        let registration = RegisteredLocalModel(
            id: UUID(),
            displayName: "Integration model",
            engine: engine,
            modelFolder: try FolderBookmark(url: modelURL),
            tokenizerFolder: try tokenizerURL.map(FolderBookmark.init(url:)),
            addedAt: .now
        )
        return ResolvedRegisteredModel(
            registration: registration,
            modelFolder: SecurityScopedFolder(url: modelURL),
            tokenizerFolder: tokenizerURL.map(SecurityScopedFolder.init(url:))
        )
    }

    private func folderFingerprint(_ folder: URL) throws -> [String] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result = [String]()
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            let relative = url.path.replacingOccurrences(of: folder.path + "/", with: "")
            result.append(
                "\(relative)|\(values.fileSize ?? -1)|\(values.contentModificationDate?.timeIntervalSince1970 ?? -1)"
            )
        }
        return result.sorted()
    }
}
