import SwiftUI

/// Yaip's dark interface palette. Neutrals are tinted toward the accent hue
/// rather than being pure black or grey, and the accent occupies well under
/// ten per cent of the surface.
enum YPPalette {
    static let canvas        = Color(red: 0.073, green: 0.094, blue: 0.082)
    static let surface       = Color(red: 0.102, green: 0.125, blue: 0.109)
    static let surfaceRaised = Color(red: 0.137, green: 0.165, blue: 0.145)
    static let surfaceHover  = Color(red: 0.171, green: 0.204, blue: 0.180)
    static let ink           = Color(red: 0.925, green: 0.941, blue: 0.929)
    static let inkMuted      = Color(red: 0.659, green: 0.706, blue: 0.671)
    static let inkSoft       = Color(red: 0.510, green: 0.557, blue: 0.522)
    static let line          = Color(red: 0.220, green: 0.259, blue: 0.231)
    static let accent        = Color(red: 0.486, green: 0.788, blue: 0.514)
    static let accentStrong  = Color(red: 0.396, green: 0.698, blue: 0.431)
    static let onAccent      = Color(red: 0.059, green: 0.082, blue: 0.067)
    static let warning       = Color(red: 0.918, green: 0.678, blue: 0.286)
    static let critical      = Color(red: 0.941, green: 0.392, blue: 0.384)

    // MARK: Yaip additions

    /// Waveform below the speech threshold.
    static let waveformIdle = line
    /// Waveform above threshold. Live feedback that the mic is hearing you.
    static let waveformActive = accent
    /// Recording indicator. The only red in the app that is not an error.
    static let recording = critical
    /// Marks a model that is used from an imported folder.
    static let importedModel = Color(red: 0.478, green: 0.667, blue: 0.867)
    /// A segment with no speaker assigned.
    static let speakerUnknown = inkSoft

    /// Speaker hues for diarized transcripts.
    ///
    /// Held at roughly `inkMuted` lightness so no speaker outshouts the accent.
    /// Always paired with the speaker name in the UI, so colour is never the
    /// only channel carrying the distinction.
    static let speakerColours: [Color] = [
        Color(red: 0.486, green: 0.788, blue: 0.514),  // accent green
        Color(red: 0.478, green: 0.667, blue: 0.867),  // blue
        Color(red: 0.851, green: 0.663, blue: 0.396),  // amber
        Color(red: 0.780, green: 0.573, blue: 0.812),  // violet
        Color(red: 0.443, green: 0.780, blue: 0.749),  // teal
        Color(red: 0.898, green: 0.588, blue: 0.545),  // coral
        Color(red: 0.667, green: 0.741, blue: 0.435),  // olive
        Color(red: 0.667, green: 0.643, blue: 0.855),  // periwinkle
    ]

    static func speakerColour(_ index: Int) -> Color {
        speakerColours[index % speakerColours.count]
    }
}
