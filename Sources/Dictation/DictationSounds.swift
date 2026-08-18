import AppKit

/// Short audio cues so you know dictation started and finished without
/// looking away from what you are writing.
///
/// System sounds rather than bundled files: they already respect the user's
/// alert volume and their choice of alert sound device, and they add nothing
/// to the app's download size.
@MainActor
enum DictationSounds {
    /// Turned off entirely by the user in the menu.
    static var isEnabled = true

    /// Rising, short. Confirms the key registered and the mic is live.
    static func start() { play("Tink") }

    /// Softer than the start cue: it confirms capture stopped, and should not
    /// sound like an alert when it fires dozens of times a day.
    static func stop() { play("Pop") }

    /// Distinct from both, because the failure cases (nothing heard, no
    /// permission, secure input) are the ones you must not miss.
    static func failure() { play("Basso") }

    private static func play(_ name: String) {
        guard isEnabled, let sound = NSSound(named: name) else { return }
        // Restart rather than ignore: holding the key twice quickly should
        // give two cues, not one.
        sound.stop()
        sound.play()
    }
}
