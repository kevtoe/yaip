import Foundation
import NaturalLanguage
import OSLog
@preconcurrency import WhisperKit

/// Whisper via WhisperKit (Argmax OSS SDK, MIT), running CoreML on the Neural
/// Engine.
///
/// The multilingual workhorse: 99 languages, and the only local path that
/// handles Vietnamese. Slower than Parakeet, so it is the batch default rather
/// than the dictation default.
actor WhisperKitRunner: TranscriptionRunner {
    nonisolated static let identifier = "whisperkit"

    nonisolated let capabilities = RunnerCapabilities(
        isLocal: true,
        supportsWordTimestamps: true,
        supportsTranslateToEnglish: true,
        supportsVocabularyPrompt: true,
        supportsLanguageDetection: true,
        languageSupport: .all,
        maximumDuration: nil
    )

    private let log = Logger(subsystem: "app.yaip.v1", category: "WhisperKit")
    private let model: String
    private let registered: ResolvedRegisteredModel?
    private var pipe: WhisperKit?

    init(model: String) {
        self.model = model
        registered = nil
    }

    init(registered: ResolvedRegisteredModel) {
        self.registered = registered
        model = registered.registration.selection.modelIdentifier
    }

    func prepare(onProgress: @Sendable @escaping (Double) -> Void) async throws {
        guard pipe == nil else { return }   // idempotent
        log.info("Loading \(self.model, privacy: .public)")

        do {
            if let registered {
                pipe = try await loadRegistered(registered)
            } else if let modelURL = ModelStorage.bundledWhisperModel(model),
                      let tokenizerURL = ModelStorage.bundledWhisperTokenizer(model) {
                pipe = try await loadLocal(
                    modelURL: modelURL,
                    tokenizerURL: tokenizerURL
                )
            } else if let tokenizerURL = ModelStorage.whisperKitTokenizer(model) {
                let modelURL = ModelStorage.whisperKitModel(model)
                try ModelFolderValidator.validate(
                    modelFolder: modelURL,
                    engine: .whisperKit,
                    tokenizerFolder: tokenizerURL
                )
                pipe = try await loadLocal(
                    modelURL: modelURL,
                    tokenizerURL: tokenizerURL
                )
            } else {
                throw RunnerError.engineFailure("Download this Whisper model from Local Models first.")
            }
            onProgress(1)
        } catch {
            if registered != nil {
                throw RunnerError.engineFailure(
                    "Could not load the local Whisper model: \(error.localizedDescription)"
                )
            }
            throw RunnerError.engineFailure(
                "Could not load the Whisper model: \(error.localizedDescription)"
            )
        }
    }

    func transcribe(
        _ audio: AudioBuffer,
        options: TranscriptionOptions,
        onProgress: @Sendable @escaping (RunnerProgress) -> Void
    ) async throws -> TranscriptionResult {
        guard let pipe else { throw RunnerError.modelNotPrepared }

        let started = ContinuousClock.now
        let results = try await pipe.transcribe(
            audioArray: audio.samples,
            decodeOptions: decodingOptions(for: options, using: pipe),
            callback: { progress in
                onProgress(RunnerProgress(fraction: nil, partialText: progress.text))
                return true   // keep going
            }
        )
        try Task.checkCancellation()

        let detectedCode = results.first?.language
        return TranscriptionResult(
            segments: results.flatMap(\.segments).map(Self.segment(from:)),
            detectedLanguage: detectedCode.map { Locale.Language(identifier: $0) },
            engineIdentifier: Self.identifier,
            modelIdentifier: model,
            elapsed: ContinuousClock.now - started
        )
    }

    func teardown() async {
        pipe = nil
    }

    // MARK: Private

    private func loadRegistered(
        _ registered: ResolvedRegisteredModel
    ) async throws -> WhisperKit {
        let modelURL = registered.modelFolder.url
        let tokenizerURL = registered.tokenizerFolder?.url ?? modelURL
        return try await loadLocal(modelURL: modelURL, tokenizerURL: tokenizerURL)
    }

    private func loadLocal(
        modelURL: URL,
        tokenizerURL: URL
    ) async throws -> WhisperKit {

        // Parse locally before constructing WhisperKit. A malformed tokenizer
        // must fail here rather than falling through to a network download.
        let tokenizer = try await AutoTokenizerWrapper.from(
            modelFolder: tokenizerURL,
            hubApi: HubApiWrapper(downloadBase: ModelStorage.whisperKitBase),
            strict: true
        )

        let pipe = try await WhisperKit(
            WhisperKitConfig(
                modelFolder: modelURL.path,
                tokenizerFolder: tokenizerURL,
                computeOptions: Self.computeOptions,
                load: false,
                download: false
            )
        )
        pipe.tokenizer = LocalWhisperTokenizer(tokenizer)
        try await pipe.loadModels()
        return pipe
    }

    private static var computeOptions: ModelComputeOptions {
        #if arch(x86_64)
        ModelComputeOptions(
            melCompute: .cpuOnly,
            audioEncoderCompute: .cpuOnly,
            textDecoderCompute: .cpuOnly
        )
        #else
        ModelComputeOptions()
        #endif
    }

    private func decodingOptions(
        for options: TranscriptionOptions,
        using pipe: WhisperKit
    ) -> DecodingOptions {
        DecodingOptions(
            task: options.translateToEnglish ? .translate : .transcribe,
            language: options.language,
            temperature: 0,
            usePrefillPrompt: true,
            detectLanguage: options.language == nil,
            wordTimestamps: options.wordTimestamps,
            promptTokens: promptTokens(for: options.vocabulary, using: pipe),
            chunkingStrategy: .vad
        )
    }

    /// Whisper biases decoding toward an initial prompt, so feeding the custom
    /// vocabulary in as prompt text is the standard trick for names and jargon.
    private func promptTokens(for vocabulary: [String], using pipe: WhisperKit) -> [Int]? {
        guard vocabulary.isEmpty == false, let tokenizer = pipe.tokenizer else { return nil }
        return tokenizer.encode(text: " " + vocabulary.joined(separator: ", "))
    }

    private static func segment(from segment: TranscriptionSegment) -> Segment {
        Segment(
            text: segment.text.trimmingCharacters(in: .whitespaces),
            startMS: Int(segment.start * 1000),
            endMS: Int(segment.end * 1000),
            words: (segment.words ?? []).map(Self.word(from:)),
            confidence: normalisedConfidence(from: Double(segment.avgLogprob))
        )
    }

    private static func word(from timing: WordTiming) -> Word {
        Word(
            text: timing.word,
            startMS: Int(timing.start * 1000),
            endMS: Int(timing.end * 1000),
            confidence: Double(timing.probability)
        )
    }

    /// Average log-probability sits in roughly -1...0 in practice. Map it to
    /// 0...1 so confidence means the same thing across every engine.
    private static func normalisedConfidence(from avgLogprob: Double) -> Double {
        min(1, max(0, 1 + avgLogprob))
    }
}

/// Public WhisperKit exposes its tokenizer protocol but not the wrapper's
/// initializer. This adapter keeps imported tokenizers entirely local.
private struct LocalWhisperTokenizer: WhisperTokenizer {
    let tokenizer: TokenizerWrapper
    let specialTokens: SpecialTokens
    let allLanguageTokens: Set<Int>

    init(_ tokenizer: TokenizerWrapper) {
        self.tokenizer = tokenizer
        specialTokens = SpecialTokens(
            endToken: tokenizer.convertTokenToId("<|endoftext|>") ?? 50257,
            englishToken: tokenizer.convertTokenToId("<|en|>") ?? 50259,
            noSpeechToken: tokenizer.convertTokenToId("<|nospeech|>") ?? 50362,
            noTimestampsToken: tokenizer.convertTokenToId("<|notimestamps|>") ?? 50363,
            specialTokenBegin: tokenizer.convertTokenToId("<|endoftext|>") ?? 50257,
            startOfPreviousToken: tokenizer.convertTokenToId("<|startofprev|>") ?? 50361,
            startOfTranscriptToken: tokenizer.convertTokenToId("<|startoftranscript|>") ?? 50258,
            timeTokenBegin: tokenizer.convertTokenToId("<|0.00|>") ?? 50364,
            transcribeToken: tokenizer.convertTokenToId("<|transcribe|>") ?? 50359,
            translateToken: tokenizer.convertTokenToId("<|translate|>") ?? 50358,
            whitespaceToken: tokenizer.convertTokenToId(" ") ?? 220
        )
        let specialTokenBegin = specialTokens.specialTokenBegin
        allLanguageTokens = Set(
            Constants.languages.values
                .compactMap { tokenizer.convertTokenToId("<|\($0)|>") }
                .filter { $0 > specialTokenBegin }
        )
    }

    func encode(text: String) -> [Int] { tokenizer.encode(text: text) }
    func decode(tokens: [Int]) -> String { tokenizer.decode(tokens: tokens) }
    func convertTokenToId(_ token: String) -> Int? { tokenizer.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { tokenizer.convertIdToToken(id) }

    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        let decoded = tokenizer.decode(
            tokens: tokenIds.filter { $0 < specialTokens.specialTokenBegin }
        )
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(decoded)
        let code = recognizer.dominantLanguage.flatMap {
            Locale(identifier: $0.rawValue).language.languageCode?.identifier
        }
        if ["zh", "ja", "th", "lo", "my", "yue"].contains(code) {
            return splitOnUnicode(tokenIds)
        }
        return splitOnSpaces(tokenIds)
    }

    private func splitOnUnicode(_ tokens: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        let replacement = "\u{fffd}"
        var words = [String]()
        var wordTokens = [[Int]]()
        var pending = [Int]()

        for token in tokens {
            pending.append(token)
            let decoded = tokenizer.decode(tokens: pending)
            if decoded.contains(replacement) == false {
                words.append(decoded)
                wordTokens.append(pending)
                pending.removeAll(keepingCapacity: true)
            }
        }
        if pending.isEmpty == false {
            words.append(tokenizer.decode(tokens: pending))
            wordTokens.append(pending)
        }
        return (words, wordTokens)
    }

    private func splitOnSpaces(_ tokens: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        let parts = splitOnUnicode(tokens)
        var words = [String]()
        var wordTokens = [[Int]]()

        for (part, tokens) in zip(parts.words, parts.wordTokens) {
            let special = tokens.first.map { $0 >= specialTokens.specialTokenBegin } ?? false
            let punctuation = part.trimmingCharacters(in: .whitespaces)
                .unicodeScalars
                .allSatisfy(CharacterSet.punctuationCharacters.contains)
            if special || part.hasPrefix(" ") || punctuation || words.isEmpty {
                words.append(part)
                wordTokens.append(tokens)
            } else {
                words[words.count - 1] += part
                wordTokens[wordTokens.count - 1].append(contentsOf: tokens)
            }
        }
        return (words, wordTokens)
    }
}
