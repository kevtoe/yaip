import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press the keys you want. Captures whatever you pressed.
///
/// Records both shapes: releasing bare modifiers gives a hold-to-talk key,
/// while pressing a key with modifiers gives a combination. The global
/// dictation tap is suspended while recording, or the keys being recorded
/// would also start a dictation.
struct ShortcutRecorder: View {
    @Binding var shortcut: DictationShortcut
    /// Suspends and resumes the live hotkey while recording.
    let setMonitorSuspended: (Bool) -> Void

    @State private var isRecording = false
    @State private var pressedModifiers = ModifierFlags()
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(label)
                .font(YPTypography.controlLabel)
                .monospacedDigit()
                .foregroundStyle(isRecording ? YPPalette.onAccent : YPPalette.ink)
                .frame(minWidth: 180)
                .padding(.horizontal, YPMetrics.controlHorizontalPadding)
                .frame(height: YPMetrics.controlHeight)
                .background(
                    isRecording ? YPPalette.accent : YPPalette.surfaceRaised,
                    in: .rect(cornerRadius: YPMetrics.controlRadius)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Press the keys you want, or Escape to cancel" : "Click to record a shortcut")
        .accessibilityLabel("Dictation shortcut")
        .accessibilityValue(shortcut.displayString)
        .accessibilityHint("Activate, then press the keys you want to use")
        .onDisappear { stopRecording() }
    }

    private var label: String {
        isRecording
            ? (pressedModifiers.isEmpty ? "Press keys…" : pressedModifiers.symbols)
            : shortcut.displayString
    }

    // MARK: Recording

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        pressedModifiers = []
        setMonitorSuspended(true)

        // Local monitor: only fires while a Yaip window is key, which is
        // exactly the scope wanted. Returning nil swallows the event so the
        // keystroke does not also reach the app underneath.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        pressedModifiers = []
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        setMonitorSuspended(false)
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return
            }
            // A key with its modifiers: a combination.
            shortcut = .combination(
                keyCode: Int(event.keyCode),
                modifiers: ModifierFlags(eventFlags: event.cgEvent?.flags ?? [])
            )
            stopRecording()

        case .flagsChanged:
            let flags = ModifierFlags(eventFlags: event.cgEvent?.flags ?? [])
            if flags.isEmpty {
                // Everything released. If exactly one modifier was held, that
                // is the hold-to-talk key the user meant.
                if let key = ModifierKey.from(keyCode: Int(event.keyCode)),
                   pressedModifiers.isEmpty == false {
                    shortcut = .modifier(key)
                    stopRecording()
                } else {
                    pressedModifiers = []
                }
            } else {
                pressedModifiers = flags
            }

        default:
            break
        }
    }
}
