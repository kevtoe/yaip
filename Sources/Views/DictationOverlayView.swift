import SwiftUI

/// The HUD shown just above the caret while dictating.
///
/// Read out of the corner of the eye, mid-sentence, so it answers exactly two
/// questions: is it hearing me, and where did the text go.
struct DictationOverlayView: View {
    @Bindable var dictation: DictationController

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(phase: dictation.phase)

            switch dictation.phase {
            case .listening:
                Text("Listening")
                    .font(YPTypography.controlLabel)
                    .foregroundStyle(YPPalette.ink)
                WaveformBars(levels: dictation.levels)
                    .frame(maxWidth: .infinity, maxHeight: 20)
                Text(dictation.elapsed.minuteSecondLabel)
                    .font(YPTypography.overlayTimer)
                    .foregroundStyle(YPPalette.ink)
                    .monospacedDigit()

            case .transcribing:
                Text("Transcribing…")
                    .font(YPTypography.controlLabel)
                    .foregroundStyle(YPPalette.ink)
                Spacer(minLength: 0)
                ProgressView()
                    .controlSize(.small)
                    .tint(YPPalette.accent)

            case .delivered(let text, _):
                Text(text)
                    .font(YPTypography.controlLabel)
                    .foregroundStyle(YPPalette.ink)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .foregroundStyle(YPPalette.accent)
                    .accessibilityHidden(true)

            case .failed(let message):
                Text(message)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.critical)
                    .lineLimit(2)
                Spacer(minLength: 0)

            case .idle:
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: YPMetrics.overlayWidth, height: YPMetrics.overlayHeight)
        // The HUD floats over arbitrary apps, so an adaptive material cannot
        // guarantee contrast. A fixed surface keeps every state legible over
        // light documents, photos and Reduce Transparency alike.
        .background(
            YPPalette.surface,
            in: .rect(cornerRadius: YPMetrics.overlayCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: YPMetrics.overlayCornerRadius)
                .strokeBorder(YPPalette.inkSoft, lineWidth: 1)
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch dictation.phase {
        case .idle:                          ""
        case .listening:                     "Listening"
        case .transcribing:                  "Transcribing"
        case .delivered(let text, let where_): "Dictated \(text). \(where_)"
        case .failed(let message):           message
        }
    }
}
