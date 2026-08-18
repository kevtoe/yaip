import SwiftUI

/// The menu bar indicator.
///
/// Takes the controller and reads its state inside `body`, never as values
/// computed by the caller. Reading `@Observable` properties in an `App`'s
/// scene body makes the scene graph invalidate and re-enter itself while it is
/// still building `MenuBarExtra`, which hangs the app before any window
/// appears: no crash, no log, just a running process with no interface.
struct MenuBarIcon: View {
    @Bindable var dictation: DictationController

    var body: some View {
        Image(systemName: symbol)
            .accessibilityLabel(label)
    }

    private var symbol: String {
        guard dictation.isEnabled else { return "waveform.slash" }
        return switch dictation.phase {
        case .listening:    "waveform.circle.fill"
        case .transcribing: "waveform.circle"
        case .failed:       "exclamationmark.triangle"
        case .delivered:    "checkmark.circle"
        case .idle:         "waveform"
        }
    }

    private var label: String {
        guard dictation.isEnabled else { return "Yaip: dictation unavailable" }
        return switch dictation.phase {
        case .listening:    "Yaip: listening"
        case .transcribing: "Yaip: transcribing"
        case .failed:       "Yaip: dictation failed"
        case .delivered:    "Yaip: text inserted"
        case .idle:         "Yaip: ready"
        }
    }
}
