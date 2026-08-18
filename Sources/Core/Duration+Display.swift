import Foundation

extension Duration {
    /// "2:05" for list subtitles and headers.
    var minuteSecondLabel: String {
        formatted(.time(pattern: .minuteSecond))
    }

    /// "02:05" for the transcript gutter, where a fixed width keeps the
    /// timecode column from shifting as the recording passes ten minutes.
    var paddedTimecode: String {
        formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }

    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }

    init(seconds: Double) {
        self = .seconds(seconds)
    }
}
