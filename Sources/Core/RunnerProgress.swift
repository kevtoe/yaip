import Foundation

/// Progress during a transcription run.
struct RunnerProgress: Sendable {
    /// 0...1 where known. Engines that cannot estimate report nil rather than
    /// inventing a number, so the UI can show an indeterminate state honestly.
    var fraction: Double?
    /// Text decoded so far, for live display.
    var partialText: String?
}
