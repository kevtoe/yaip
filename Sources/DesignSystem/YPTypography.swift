import SwiftUI

/// Urbanist 600 for names, labels and actions; Urbanist 400 for body; native
/// SF Mono only for genuinely technical metadata (timecodes, model IDs).
enum YPTypography {
    static let windowTitle = Font.custom("Urbanist", size: 26, relativeTo: .title)
        .weight(.semibold)
    static let sectionTitle = Font.custom("Urbanist", size: 15, relativeTo: .headline)
        .weight(.semibold)
    static let controlLabel = Font.custom("Urbanist", size: 14, relativeTo: .body)
        .weight(.semibold)
    /// Button text sits one step above `controlLabel` so actions read clearly
    /// against surrounding status copy.
    static let buttonLabel = Font.custom("Urbanist", size: 15, relativeTo: .body)
        .weight(.semibold)
    static let body = Font.custom("Urbanist", size: 14, relativeTo: .body)
    static let supporting = Font.custom("Urbanist", size: 13, relativeTo: .callout)
    static let metadata = Font.system(.caption, design: .monospaced, weight: .medium)

    // MARK: Yaip additions

    /// Transcript body. 16pt because this is read for minutes, not glanced at.
    static let transcript = Font.custom("Urbanist", size: 16, relativeTo: .body)
    /// Timecodes in the transcript gutter.
    static let timecode = Font.system(.caption, design: .monospaced, weight: .medium)
    /// The dictation overlay's live text: large, high contrast, glanceable.
    static let overlayText = Font.custom("Urbanist", size: 18, relativeTo: .title3)
        .weight(.medium)
    /// Recording duration has to remain readable over another app at a glance.
    static let overlayTimer = Font.system(size: 12, weight: .semibold, design: .monospaced)

    /// Leading for `transcript`. RL never specified this because it had no
    /// long-form reading surface.
    static let transcriptLineSpacing: CGFloat = 16 * 0.55
}
