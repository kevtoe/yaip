import SwiftUI

struct TranscriptHeader: View {
    @Bindable var job: TranscriptionJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.title)
                .font(YPTypography.windowTitle)
                .foregroundStyle(YPPalette.ink)

            Text(metadataLine)
                .font(YPTypography.metadata)
                .foregroundStyle(YPPalette.inkSoft)
                .textSelection(.enabled)
        }
        .padding(YPMetrics.sectionSpacing)
    }

    /// Technical provenance, so it uses the monospaced metadata role.
    private var metadataLine: String {
        var parts = [String]()
        if let duration = job.duration {
            parts.append(duration.minuteSecondLabel)
        }
        if let result = job.result {
            parts.append(result.modelIdentifier)
            if let code = result.detectedLanguage?.languageCode?.identifier {
                parts.append(code.uppercased())
            }
            parts.append(result.elapsed.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))))
        }
        return parts.joined(separator: "  ·  ")
    }
}
