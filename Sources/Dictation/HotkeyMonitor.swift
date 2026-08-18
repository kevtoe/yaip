import AppKit
import CoreGraphics
import OSLog

/// Watches for the dictation shortcut anywhere in macOS.
///
/// The tap is installed on the main run loop so the callback is already on the
/// main actor, which avoids hopping threads on every keystroke the user types.
@MainActor
final class HotkeyMonitor {
    private let log = Logger(subsystem: "app.yaip.v1", category: "Hotkey")

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcut: DictationShortcut = .default
    private var isHeld = false
    /// Suspended while the user is recording a new shortcut, so pressing keys
    /// in the recorder does not also start dictating.
    private var isSuspended = false

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    var isRunning: Bool { tap != nil }

    // MARK: Lifecycle

    func start(shortcut: DictationShortcut) throws {
        stop()
        self.shortcut = shortcut

        guard InputPermissions.hasAccessibility else {
            throw DictationError.accessibilityDenied
        }

        // flagsChanged carries modifier presses; keyDown/keyUp carry
        // combinations. Both are needed because a shortcut can be either.
        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            // Listen only: the shortcut keeps its normal behaviour and we never
            // risk swallowing a keystroke the user needed.
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
                // The tap runs on the main run loop, so this is already the
                // main actor; assumeIsolated avoids a hop per key event.
                MainActor.assumeIsolated {
                    monitor.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw DictationError.inputMonitoringDenied
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        runLoopSource = source
        log.notice("Hotkey monitor started on \(shortcut.displayString, privacy: .public)")
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isHeld = false
    }

    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        if suspended, isHeld {
            isHeld = false
            onRelease?()
        }
    }

    // MARK: Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS disables a tap that takes too long, or on certain user input.
        // Without re-enabling, the shortcut dies silently and never recovers,
        // which is the most common failure in this kind of app.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            log.error("Event tap disabled (\(type.rawValue)); re-enabling.")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard isSuspended == false else { return }

        switch shortcut {
        case .modifier(let key):
            handleModifier(key, type: type, event: event)
        case .combination(let keyCode, let modifiers):
            handleCombination(keyCode: keyCode, modifiers: modifiers, type: type, event: event)
        }
    }

    private func handleModifier(_ key: ModifierKey, type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged,
              Int(event.getIntegerValueField(.keyboardEventKeycode)) == key.keyCode
        else { return }

        setHeld(event.flags.contains(key.flag))
    }

    private func handleCombination(
        keyCode: Int,
        modifiers: ModifierFlags,
        type: CGEventType,
        event: CGEvent
    ) {
        guard type == .keyDown || type == .keyUp,
              Int(event.getIntegerValueField(.keyboardEventKeycode)) == keyCode
        else { return }

        // Holding a combination repeats; only the first press should start.
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }

        if type == .keyDown {
            // Compare only the modifiers we care about, so Caps Lock or a
            // numeric-keypad flag does not stop the shortcut matching.
            let pressed = ModifierFlags(eventFlags: event.flags)
            guard pressed == modifiers else { return }
            setHeld(true)
        } else {
            setHeld(false)
        }
    }

    private func setHeld(_ held: Bool) {
        guard held != isHeld else { return }   // ignore repeats
        isHeld = held
        if held { onPress?() } else { onRelease?() }
    }

    // No deinit: a nonisolated deinit cannot touch the main-actor-isolated,
    // non-Sendable CFMachPort. `stop()` is the teardown path, and the run loop
    // releases the port when the source goes away.
}
