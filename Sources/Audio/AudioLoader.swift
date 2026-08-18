import AVFoundation
import Foundation

/// Decodes anything AVFoundation understands into an `AudioBuffer`.
///
/// Uses `AVAssetReader` rather than `AVAudioFile` so video containers (mp4,
/// mov) need no separate code path, and asks the reader for the target format
/// directly so there is never a second conversion pass.
enum AudioLoader {

    static func load(url: URL) async throws -> AudioBuffer {
        let asset = AVURLAsset(url: url)

        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioLoaderError.noAudioTrack(url.lastPathComponent)
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            throw AudioLoaderError.readFailed(reader.error?.localizedDescription ?? "unknown")
        }

        var samples = [Float]()
        // Pre-size from the track duration so a long recording does not
        // repeatedly reallocate a multi-million element array.
        let assetDuration = try await asset.load(.duration).seconds
        if assetDuration.isFinite, assetDuration > 0 {
            samples.reserveCapacity(Int(assetDuration * AudioBuffer.sampleRate))
        }

        while let sampleBuffer = output.copyNextSampleBuffer() {
            defer { CMSampleBufferInvalidate(sampleBuffer) }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let byteCount = CMBlockBufferGetDataLength(blockBuffer)
            var bytes = [UInt8](repeating: 0, count: byteCount)
            CMBlockBufferCopyDataBytes(
                blockBuffer, atOffset: 0, dataLength: byteCount, destination: &bytes
            )
            bytes.withUnsafeBytes { raw in
                samples.append(contentsOf: raw.bindMemory(to: Float.self))
            }

            try Task.checkCancellation()
        }

        if reader.status == .failed {
            throw AudioLoaderError.readFailed(reader.error?.localizedDescription ?? "unknown")
        }

        return AudioBuffer(samples: samples)
    }

    /// Exactly what every engine wants, so the reader does the conversion.
    ///
    /// Computed rather than stored: `[String: Any]` is not `Sendable`, so a
    /// static constant would be shared mutable state under strict concurrency.
    private static var outputSettings: [String: Any] {[
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: AudioBuffer.sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]}
}
