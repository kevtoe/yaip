import SwiftUI

struct DictationRow: View {
    let record: DictationRecord
    let onDelete: () -> Void

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.compactSpacing) {
            HStack(spacing: YPMetrics.compactSpacing) {
                TargetAppIcon(bundleID: record.targetBundleID)
                DeliveryBadge(record: record)

                Text(record.targetAppName ?? "Unknown app")
                    .font(YPTypography.controlLabel)
                    .foregroundStyle(YPPalette.ink)

                Text(record.date, format: .dateTime.hour().minute())
                    .font(YPTypography.metadata)
                    .foregroundStyle(YPPalette.inkSoft)

                Spacer(minLength: 0)

                Button("Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc", action: copy)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(didCopy ? YPPalette.accent : YPPalette.inkMuted)
                    .help("Copy this text")

                Button("Delete", systemImage: "trash", action: onDelete)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(YPPalette.inkSoft)
                    .help("Remove from history")
            }

            Text(record.text)
                .font(YPTypography.transcript)
                .lineSpacing(YPTypography.transcriptLineSpacing)
                .foregroundStyle(YPPalette.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let reason = record.failureReason {
                // The whole reason history exists: say why it did not land, so
                // the words can be recovered rather than retyped.
                Text("Not inserted because \(reason). The text is above and can be copied.")
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.warning)
            }

            // Built inline rather than from a `String`: automatic grammar
            // agreement only resolves in a literal `Text`, so composing the
            // markup into a String first renders it verbatim on screen.
            Text("^[\(record.wordCount) word](inflect: true) · \(spokenLabel) · \(record.modelDisplayName)")
                .font(YPTypography.metadata)
                .foregroundStyle(YPPalette.inkSoft)
        }
        .padding(YPMetrics.standardSpacing)
        .background(YPPalette.surface, in: .rect(cornerRadius: YPMetrics.selectedRowRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dictation into \(record.targetAppName ?? "unknown app"), \(record.delivery.label)")
    }

    private var spokenLabel: String {
        Duration.seconds(record.spokenSeconds).minuteSecondLabel
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
    }
}

private extension DictationRecord {
    var modelDisplayName: String {
        switch engineIdentifier {
        case "apple-speech":
            return "Apple Speech"
        case "whisperkit":
            return WhisperModel(rawValue: modelIdentifier)?.displayName ?? "Whisper"
        case "fluid-parakeet":
            return ParakeetModel(rawValue: modelIdentifier)?.displayName ?? "Parakeet"
        default:
            return "Local model"
        }
    }
}

private struct DeliveryBadge: View {
    let record: DictationRecord

    var body: some View {
        Circle()
            .fill(record.delivery.didReachTheApp ? YPPalette.accent : YPPalette.warning)
            .frame(width: YPMetrics.statusDotSize, height: YPMetrics.statusDotSize)
            .accessibilityHidden(true)
    }
}
