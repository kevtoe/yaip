import AVFoundation
import Foundation
import OSLog
import Speech

/// Apple's on-device SpeechAnalyzer, new in macOS 26.
///
/// The zero-download default: the system owns the models, so a fresh install
/// can dictate immediately instead of waiting on a 494 MB Parakeet fetch. Its
/// language assets are managed by `AssetInventory` rather than by us.
@available(macOS 26, *)
actor AppleSpeechRunner: TranscriptionRunner {
    nonisolated static let identifier = "apple-speech"

    nonisolated let capabilities = RunnerCapabilities(
        isLocal: true,
        // Timings need a time-indexed preset; the transcription preset used
        // here returns text only.
        supportsWordTimestamps: false,
        supportsTranslateToEnglish: false,
        supportsVocabularyPrompt: false,
        supportsLanguageDetection: false,
        languageSupport: .all,
        maximumDuration: nil
    )

    private let log = Logger(subsystem: "app.yaip.v1", category: "AppleSpeech")
    private let localeIdentifier: String

    /// Only the resolved locale is cached. The transcriber deliberately is
    /// NOT: see `transcribe` below.
    private var resolvedLocale: Locale?

    init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
    }

    func prepare(onProgress: @Sendable @escaping (Double) -> Void) async throws {
        guard resolvedLocale == nil else { return }

        guard SpeechTranscriber.isAvailable else {
            throw RunnerError.engineUnavailable("Apple Speech")
        }
        guard let locale = await SpeechTranscriber.supportedLocale(
            equivalentTo: Locale(identifier: localeIdentifier)
        ) else {
            throw RunnerError.unsupportedLanguage(
                code: localeIdentifier, engine: "Apple Speech"
            )
        }

        // Install language assets once. A throwaway module is fine here: it is
        // only used to describe what needs downloading.
        let probe = SpeechTranscriber(locale: locale, preset: .transcription)
        if await AssetInventory.status(forModules: [probe]) != .installed {
            // The system manages and sizes these, so report indeterminate
            // rather than inventing a percentage.
            if let request = try await AssetInventory.assetInstallationRequest(
                supporting: [probe]
            ) {
                try await request.downloadAndInstall()
            }
        }

        resolvedLocale = locale
        onProgress(1)
    }

    func transcribe(
        _ audio: AudioBuffer,
        options: TranscriptionOptions,
        onProgress: @Sendable @escaping (RunnerProgress) -> Void
    ) async throws -> TranscriptionResult {
        guard let resolvedLocale else { throw RunnerError.modelNotPrepared }

        let started = ContinuousClock.now
        onProgress(RunnerProgress(fraction: nil, partialText: nil))

        // A FRESH transcriber and analyzer for every job.
        //
        // Reusing a `SpeechTranscriber` across analyzer sessions traps inside
        // the framework (`TranscriberCommon.worker.setter`, EXC_BREAKPOINT):
        // the module is still bound to the previous analyzer when the next one
        // tries to claim it. Its `results` sequence is also single-consumption,
        // so a cached instance yields nothing the second time even when it
        // survives. The first dictation of a session works and every one after
        // it crashes, which is exactly how this presented.
        let transcriber = SpeechTranscriber(locale: resolvedLocale, preset: .transcription)

        // SpeechAnalyzer consumes an AVAudioFile, and our pipeline holds raw
        // samples, so stage a temporary file rather than duplicating the
        // conversion logic AudioLoader already owns.
        let fileURL = try Self.writeTemporaryFile(audio)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        async let collected = transcriber.results.reduce(AttributedString()) { partial, result in
            var partial = partial
            partial += result.text
            return partial
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: fileURL)

        do {
            if let lastSample = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            // Leave nothing running behind a thrown error, or the next job
            // inherits a half-finished session.
            await analyzer.cancelAndFinishNow()
            throw RunnerError.engineFailure(error.localizedDescription)
        }

        let text = String(try await collected.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return TranscriptionResult(
            segments: text.isEmpty ? [] : [
                Segment(text: text, startMS: 0, endMS: Int(audio.duration.seconds * 1000))
            ],
            detectedLanguage: Locale.Language(identifier: localeIdentifier),
            engineIdentifier: Self.identifier,
            modelIdentifier: "apple-speech-\(localeIdentifier)",
            elapsed: ContinuousClock.now - started
        )
    }

    func teardown() async {
        resolvedLocale = nil
    }

    private static func writeTemporaryFile(_ audio: AudioBuffer) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "yaip-\(UUID().uuidString).wav")

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioBuffer.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw RunnerError.engineFailure("Could not create the audio format.")
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audio.samples.count)
        ) else {
            throw RunnerError.engineFailure("Could not allocate the audio buffer.")
        }

        buffer.frameLength = AVAudioFrameCount(audio.samples.count)
        audio.samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            buffer.floatChannelData?[0].update(from: base, count: source.count)
        }
        try file.write(from: buffer)
        return url
    }
}
