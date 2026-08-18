import Foundation

enum AudioLoaderError: LocalizedError {
    case noAudioTrack(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack(let filename):
            "\(filename) has no audio track."
        case .readFailed(let detail):
            "Could not read the audio: \(detail)"
        }
    }
}
