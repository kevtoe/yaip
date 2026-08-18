import Foundation

/// Audio normalised to the one format every engine wants: 16 kHz, mono,
/// Float32.
///
/// Normalising once at the boundary means no runner does its own conversion,
/// which is where subtle resampling differences between engines would creep in.
struct AudioBuffer: Sendable {
    static let sampleRate: Double = 16_000

    var samples: [Float]

    var duration: Duration {
        .seconds(Double(samples.count) / Self.sampleRate)
    }
}
