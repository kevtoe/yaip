import Foundation

/// Settings destinations, kept short so every page is useful.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case dictation
    case microphone
    case localModels
    case advanced
    case about

    var id: Self { self }

    var label: String {
        switch self {
        case .general:      "General"
        case .dictation:    "Dictation"
        case .microphone:   "Microphone"
        case .localModels:  "Local Models"
        case .advanced:     "Advanced"
        case .about:        "About Yaip"
        }
    }

    var symbol: String {
        switch self {
        case .general:      "gearshape"
        case .dictation:    "mic"
        case .microphone:   "waveform"
        case .localModels:  "internaldrive"
        case .advanced:     "wrench.and.screwdriver"
        case .about:        "info.circle"
        }
    }

    var group: String {
        switch self {
        case .general, .advanced:            "General"
        case .dictation, .microphone:        "Audio"
        case .localModels:                   "Transcription"
        case .about:                         "Yaip"
        }
    }

    static let groupOrder = ["General", "Audio", "Transcription", "Yaip"]
}
