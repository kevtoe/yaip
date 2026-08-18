import AppKit
import AVFoundation
import Foundation
import OSLog

/// Captures the microphone straight into the 16 kHz mono Float32 format every
/// engine expects.
///
/// The tap callback runs on a realtime audio thread, so it must never allocate
/// unpredictably, await, or touch the main actor. Samples are appended under a
/// plain lock and drained when recording stops.
final class MicrophoneRecorder: @unchecked Sendable {
    private let log = Logger(subsystem: "app.yaip.v1", category: "Microphone")

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples = [Float]()
    private var currentLevel: Float = 0
    private var converter: AVAudioConverter?
    private var isRunning = false

    /// Most recent RMS level, 0...1, for the overlay waveform.
    var level: Float { lock.withLock { currentLevel } }

    private static var targetFormat: AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioBuffer.sampleRate,
            channels: 1,
            interleaved: false
        )
    }

    // MARK: Permission

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:  true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static var hasMicrophoneAccess: Bool {
        authorizationStatus == .authorized
    }

    static func openMicrophoneSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Recording

    func start() throws {
        guard isRunning == false else { return }

        lock.withLock { samples.removeAll(keepingCapacity: true) }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw DictationError.recordingFailed("No input device available.")
        }
        guard let targetFormat = Self.targetFormat,
              let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else {
            throw DictationError.recordingFailed("Cannot convert from the input format.")
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer, using: converter, target: targetFormat)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw DictationError.recordingFailed(error.localizedDescription)
        }
        isRunning = true
    }

    /// Stops capture and returns everything heard.
    @discardableResult
    func stop() -> AudioBuffer {
        guard isRunning else { return AudioBuffer(samples: []) }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        converter = nil

        let captured = lock.withLock {
            let copy = samples
            samples.removeAll(keepingCapacity: false)
            currentLevel = 0
            return copy
        }
        return AudioBuffer(samples: captured)
    }

    // MARK: Level metering

    /// Quietest level treated as speech, and the level treated as full scale.
    ///
    /// Linear RMS is the wrong scale for a meter: normal speech sits around
    /// 0.02 to 0.08, so a linear mapping leaves the bars flat until you shout.
    /// Hearing is logarithmic, so map decibels instead.
    private static let floorDecibels: Float = -52
    private static let ceilingDecibels: Float = -12

    static func normalisedLevel(rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        let normalised = (decibels - floorDecibels) / (ceilingDecibels - floorDecibels)
        // Slight curve so quiet speech still moves the bars noticeably.
        return min(1, max(0, pow(normalised, 0.75)))
    }

    // MARK: Realtime path

    private func append(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        target: AVAudioFormat
    ) {
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            return
        }

        let input = ConverterInput(buffer: buffer)
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            input.next(status: status)
        }

        if let error {
            log.error("Conversion failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let channel = output.floatChannelData?[0], output.frameLength > 0 else { return }

        let frames = Int(output.frameLength)
        let slice = UnsafeBufferPointer(start: channel, count: frames)

        var sumOfSquares: Float = 0
        for sample in slice { sumOfSquares += sample * sample }
        let level = Self.normalisedLevel(rms: (sumOfSquares / Float(frames)).squareRoot())
        lock.withLock {
            currentLevel = level
            samples.append(contentsOf: slice)
        }
    }
}

/// AVAudioConverter's callback is `@Sendable`, while AVAudioPCMBuffer is not.
/// The converter invokes this synchronously and may ask for input more than
/// once, so keep the one-shot state in an explicitly owned reference.
private final class ConverterInput: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private var consumed = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        if consumed {
            status.pointee = .noDataNow
            return nil
        }
        consumed = true
        status.pointee = .haveData
        return buffer
    }
}
