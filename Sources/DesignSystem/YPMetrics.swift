import Foundation

/// Shared layout and sizing values.
enum YPMetrics {
    static let minimumWindowWidth = 860.0
    static let minimumWindowHeight = 620.0
    static let defaultWindowWidth = 1_100.0
    static let defaultWindowHeight = 740.0
    static let toolbarHeight = 64.0
    static let minimumTarget = 44.0
    static let rowHeight = 76.0
    static let controlRadius = 12.0
    static let selectedRowRadius = 14.0
    static let primaryButtonHeight = 52.0

    // MARK: Control system
    //
    // `controlHeight` is also the 44pt accessibility target, so the
    // visible control and its hit area are the same rectangle rather than a
    // small control centred inside a larger invisible one.

    static let controlHeight = 44.0
    static let iconButtonSize = 44.0
    static let controlMinWidth = 80.0
    static let filterControlWidth = 180.0
    static let segmentHeight = 40.0
    static let controlHorizontalPadding = 14.0
    static let iconButtonRadius = 10.0
    static let statusDotSize = 8.0
    static let activityHeight = 56.0
    static let compactSpacing = 8.0
    static let standardSpacing = 16.0
    static let sectionSpacing = 24.0

    // MARK: Yaip additions

    /// Timecode column in the transcript.
    static let transcriptGutterWidth = 68.0
    static let segmentVerticalPadding = 10.0
    static let waveformHeight = 56.0

    /// Dictation HUD. A floating panel over other apps, so unlike RL's
    /// in-window chrome it carries real elevation and a softer radius.
    ///
    /// Deliberately small: it sits just above the caret, inside someone else's
    /// window, so it has to read as a hint rather than a dialog.
    static let overlayWidth = 268.0
    static let overlayHeight = 56.0
    static let overlayCornerRadius = 14.0

    /// Settings keeps one fixed page header and a readable content rail rather
    /// than stretching rows across an arbitrarily wide window.
    static let settingsHeaderHeight = 64.0
    static let settingsContentMaxWidth = 720.0
}
