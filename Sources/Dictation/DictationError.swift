import Foundation

enum DictationError: LocalizedError {
    case accessibilityDenied
    case inputMonitoringDenied
    case microphoneDenied
    case recordingFailed(String)
    case nothingHeard
    case secureInputActive

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            "Yaip needs Accessibility permission to paste into other apps."
        case .inputMonitoringDenied:
            "Yaip needs Input Monitoring permission to see the dictation key."
        case .microphoneDenied:
            "Yaip needs microphone access to hear you."
        case .recordingFailed(let detail):
            "Recording failed: \(detail)"
        case .nothingHeard:
            "Nothing was said."
        case .secureInputActive:
            "A password field is active, so text cannot be inserted. Copied to the clipboard instead."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessibilityDenied:
            "Open System Settings › Privacy & Security › Accessibility and enable Yaip."
        case .inputMonitoringDenied:
            "Open System Settings › Privacy & Security › Input Monitoring and enable Yaip."
        case .microphoneDenied:
            "Open System Settings › Privacy & Security › Microphone and enable Yaip."
        default:
            nil
        }
    }
}
