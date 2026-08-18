import FluidAudio
import Foundation
@preconcurrency import CoreML
import OSLog

/// FluidAudio's script-hint enum. Aliased because the bare name reads
/// ambiguously next to `Locale.Language`, and it cannot be module-qualified:
/// the package vends a `FluidAudio` struct that shadows its own module name.
private typealias ParakeetLanguageHint = Language

/// Parakeet TDT v3 via FluidAudio (Apache-2.0), running CoreML on the Neural
/// Engine.
///
/// Roughly 120x real time on Apple Silicon, which is what makes it the right
/// dictation engine. It covers 25 European languages plus Japanese and nothing
/// else, so `LanguageRouter` sends anything outside that set to Whisper.
actor FluidParakeetRunner: TranscriptionRunner {
    nonisolated static let identifier = "fluid-parakeet"

    nonisolated let capabilities = RunnerCapabilities(
        isLocal: true,
        // Parakeet returns token timings, which we fold up into words.
        supportsWordTimestamps: true,
        supportsTranslateToEnglish: false,
        supportsVocabularyPrompt: false,
        supportsLanguageDetection: false,
        languageSupport: .only(ParakeetModel.v3Languages),
        maximumDuration: nil
    )

    /// A pause longer than this reads as a new thought even without
    /// punctuation, which matters because Parakeet punctuates lightly.
    private static let pauseThreshold: TimeInterval = 0.6
    private static let maximumWordsPerSegment = 42

    private let log = Logger(subsystem: "app.yaip.v1", category: "Parakeet")
    private let model: String
    private let registered: ResolvedRegisteredModel?
    private var manager: AsrManager?
    private var decoderLayerCount = 2

    init(model: String) {
        self.model = model
        registered = nil
    }

    init(registered: ResolvedRegisteredModel) {
        self.registered = registered
        model = registered.registration.selection.modelIdentifier
    }

    func prepare(onProgress: @Sendable @escaping (Double) -> Void) async throws {
        guard manager == nil else { return }   // idempotent
        log.info("Loading \(self.model, privacy: .public)")

        do {
            let models: AsrModels
            if let registered {
                models = try Self.loadRegistered(from: registered.modelFolder.url)
            } else {
                let existing = ModelStorage.parakeetModel(model)
                if (try? ModelFolderValidator.validate(
                    modelFolder: existing, engine: .parakeetV3
                )) != nil {
                    models = try Self.loadRegistered(from: existing)
                    onProgress(1)
                } else {
                    throw RunnerError.engineFailure(
                        "Download Parakeet from Local Models first."
                    )
                }
            }
            let manager = AsrManager()
            try await manager.loadModels(models)

            decoderLayerCount = await manager.decoderLayerCount
            self.manager = manager
            onProgress(1)
        } catch {
            if registered != nil {
                throw RunnerError.engineFailure(
                    "Could not load the local Parakeet model: \(error.localizedDescription)"
                )
            }
            throw RunnerError.engineFailure(
                "Could not load the Parakeet model: \(error.localizedDescription)"
            )
        }
    }

    func transcribe(
        _ audio: AudioBuffer,
        options: TranscriptionOptions,
        onProgress: @Sendable @escaping (RunnerProgress) -> Void
    ) async throws -> TranscriptionResult {
        guard let manager else { throw RunnerError.modelNotPrepared }

        let started = ContinuousClock.now
        // Batch-only here, so report indeterminate rather than faking a
        // percentage that never moves.
        onProgress(RunnerProgress(fraction: nil, partialText: nil))

        // The TDT decoder carries LSTM state across chunks. A batch job is one
        // independent utterance, so it starts from a fresh state each time.
        var decoderState = TdtDecoderState.make(decoderLayers: decoderLayerCount)
        let result = try await manager.transcribe(
            audio.samples,
            decoderState: &decoderState,
            language: options.language.flatMap {
                ParakeetLanguageHint(rawValue: String($0.prefix(2)))
            }
        )
        try Task.checkCancellation()

        return TranscriptionResult(
            segments: Self.segments(from: result),
            // Parakeet does not detect language, so only echo what was asked.
            detectedLanguage: options.language.map { Locale.Language(identifier: $0) },
            engineIdentifier: Self.identifier,
            modelIdentifier: model,
            elapsed: ContinuousClock.now - started
        )
    }

    func teardown() async {
        manager = nil
    }

    private static func loadRegistered(from folder: URL) throws -> AsrModels {
        let configuration = AsrModels.defaultConfiguration()
        let preprocessorConfiguration = MLModelConfiguration()
        preprocessorConfiguration.computeUnits = .cpuOnly

        let preprocessor = try MLModel(
            contentsOf: folder.appending(path: "Preprocessor.mlmodelc"),
            configuration: preprocessorConfiguration
        )
        let encoder = try MLModel(
            contentsOf: folder.appending(path: "Encoder.mlmodelc"),
            configuration: configuration
        )
        let decoder = try MLModel(
            contentsOf: folder.appending(path: "Decoder.mlmodelc"),
            configuration: configuration
        )
        let joint = try MLModel(
            contentsOf: folder.appending(path: "JointDecisionv3.mlmodelc"),
            configuration: configuration
        )

        let data = try Data(contentsOf: folder.appending(path: "parakeet_vocab.json"))
        let json = try JSONSerialization.jsonObject(with: data)
        let vocabulary: [Int: String]
        if let array = json as? [String] {
            vocabulary = Dictionary(uniqueKeysWithValues: array.enumerated().map { ($0, $1) })
        } else if let dictionary = json as? [String: String] {
            vocabulary = Dictionary(
                uniqueKeysWithValues: dictionary.compactMap { key, value in
                    Int(key).map { ($0, value) }
                }
            )
        } else {
            throw RunnerError.engineFailure("parakeet_vocab.json has an unsupported format.")
        }

        return AsrModels(
            encoder: encoder,
            preprocessor: preprocessor,
            decoder: decoder,
            joint: joint,
            configuration: configuration,
            vocabulary: vocabulary,
            version: .v3
        )
    }

    // MARK: Segmentation

    /// Parakeet returns one flat string plus token timings where Whisper
    /// returns ready-made segments. Rebuilding comparable segments here is what
    /// lets the rest of the app stay engine-agnostic.
    private static func segments(from result: ASRResult) -> [Segment] {
        guard let timings = result.tokenTimings, timings.isEmpty == false else {
            return wholeAudioSegment(from: result)
        }

        var segments = [Segment]()
        var pending = [WordTiming]()
        let words = buildWordTimings(from: timings)

        for (index, word) in words.enumerated() {
            pending.append(word)

            let endsSentence = word.word.last.map { ".?!".contains($0) } ?? false
            let gapFollows = index + 1 < words.count
                && words[index + 1].startTime - word.endTime > pauseThreshold

            if endsSentence || gapFollows || pending.count >= maximumWordsPerSegment {
                if let segment = segment(from: pending, confidence: result.confidence) {
                    segments.append(segment)
                }
                pending.removeAll(keepingCapacity: true)
            }
        }

        if let segment = segment(from: pending, confidence: result.confidence) {
            segments.append(segment)
        }
        return segments
    }

    private static func segment(from words: [WordTiming], confidence: Float) -> Segment? {
        guard let first = words.first, let last = words.last else { return nil }

        let text = words
            .map(\.word)
            .joined(separator: " ")
            .replacing(" ,", with: ",")
            .replacing(" .", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard text.isEmpty == false else { return nil }

        return Segment(
            text: text,
            startMS: Int(first.startTime * 1000),
            endMS: Int(last.endTime * 1000),
            words: words.map {
                Word(
                    text: $0.word,
                    startMS: Int($0.startTime * 1000),
                    endMS: Int($0.endTime * 1000)
                )
            },
            confidence: Double(confidence)
        )
    }

    /// No timings available: one segment spanning the audio is still honest.
    private static func wholeAudioSegment(from result: ASRResult) -> [Segment] {
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return [] }

        return [
            Segment(
                text: text,
                startMS: 0,
                endMS: Int(result.duration * 1000),
                confidence: Double(result.confidence)
            )
        ]
    }
}
