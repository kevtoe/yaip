import Foundation

/// Where one transcription job has got to.
enum TranscriptionJobState: Equatable, Sendable {
    case queued
    case loadingModel(fraction: Double)
    case transcribing(fraction: Double?, partial: String?)
    case finished
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .queued, .loadingModel, .transcribing: true
        case .finished, .failed:                    false
        }
    }
}
