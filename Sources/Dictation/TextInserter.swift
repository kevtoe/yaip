import AppKit
import ApplicationServices
import OSLog

/// Puts dictated text into whatever the user is typing in.
///
/// **Clipboard paste is the primary path, deliberately.**
///
/// Accessibility insertion is tidier in principle: it writes straight into the
/// focused element and never touches the clipboard. In practice, Electron and
/// web-backed apps accept an `AXSelectedText` write, return `.success`, and
/// insert nothing. That is not a rare edge case, it is Slack, Claude, VS Code,
/// Notion and most of what anyone actually dictates into. Because the API
/// reports success, a fallback chain that tries Accessibility first never
/// falls back at all: dictation silently goes nowhere while the history
/// cheerfully records "inserted".
///
/// So paste first, and keep Accessibility as an opt-in for people who would
/// rather not have the clipboard borrowed.
@MainActor
enum TextInserter {

    enum Outcome: Equatable {
        /// Written directly into the focused element.
        case inserted
        /// Delivered through the clipboard.
        case pasted
        /// Could not be delivered; left on the clipboard.
        case copiedOnly(reason: String)
    }

    enum Method: String, CaseIterable, Codable, Sendable {
        case paste
        case accessibility

        var displayName: String {
            switch self {
            case .paste:         "Paste (recommended)"
            case .accessibility: "Accessibility"
            }
        }

        var explanation: String {
            switch self {
            case .paste:
                "Works nearly everywhere, including Electron apps. Borrows the "
                    + "clipboard for a moment and puts it back."
            case .accessibility:
                "Leaves the clipboard untouched, but silently does nothing in "
                    + "Electron and web-based apps."
            }
        }
    }

    private static let log = Logger(subsystem: "app.yaip.v1", category: "Insert")

    static var method: Method = .paste

    /// How long to wait before handing the clipboard back. Slower apps read the
    /// pasteboard well after the paste keystroke lands, so restoring
    /// immediately produces an empty paste. Configurable because the right
    /// value is app-dependent.
    static var restoreDelay = Duration.milliseconds(500)

    private static let commitTimeout = Duration.milliseconds(150)
    private static let commitPollInterval = Duration.milliseconds(5)

    static func insert(_ text: String, targetPID: pid_t?) async -> Outcome {
        guard text.isEmpty == false else { return .inserted }

        guard InputPermissions.hasAccessibility else {
            copy(text)
            return .copiedOnly(reason: "Accessibility permission is not granted")
        }

        let secureInputActive = InputPermissions.isSecureInputActive
        let targetIsSecureTextField = targetPID.map(isSecureTextField(in:)) ?? false
        if shouldCopyOnlyForSecureInput(
            targetPID: targetPID,
            secureInputActive: secureInputActive,
            targetIsSecureTextField: targetIsSecureTextField
        ) {
            copy(text)
            let reason = targetIsSecureTextField
                ? "a password field is active"
                : "secure input is active and the target app is unavailable"
            log.notice("Secure target; copied instead")
            return .copiedOnly(reason: reason)
        }

        if secureInputActive, let targetPID {
            // Secure Event Input is global: another process can leave it on
            // while Terminal remains the intended target. Post directly to the
            // captured process instead of dropping the dictation before
            // Terminal or its TUI has a chance to accept it.
            log.notice("Secure input active; targeting pid \(targetPID, privacy: .public)")
        }

        if method == .accessibility, insertViaAccessibility(text) {
            log.debug("Inserted via accessibility")
            return .inserted
        }

        await pasteViaClipboard(text, targetPID: targetPID)
        log.debug("Inserted via clipboard paste")
        return .pasted
    }

    static func shouldCopyOnlyForSecureInput(
        targetPID: pid_t?,
        secureInputActive: Bool,
        targetIsSecureTextField: Bool
    ) -> Bool {
        targetIsSecureTextField || (secureInputActive && targetPID == nil)
    }

    // MARK: Accessibility path

    /// Writes into the focused element's selection.
    ///
    /// Returning true does NOT guarantee the text appeared: see the note on
    /// the type. Only reachable when the user has explicitly chosen this
    /// method.
    private static func insertViaAccessibility(_ text: String) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success else { return false }

        guard let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return false
        }
        let focusedElement = unsafeDowncast(element, to: AXUIElement.self)

        var selectedRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange
        ) == .success else { return false }

        return AXUIElementSetAttributeValue(
            focusedElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef
        ) == .success
    }

    // MARK: Clipboard path

    private static func pasteViaClipboard(_ text: String, targetPID: pid_t?) async {
        // The dictation key is usually a modifier, and releasing it is what
        // triggered this paste. If its flag has not yet cleared system-wide,
        // the synthetic Cmd-V arrives as Fn-Cmd-V (or similar) and does
        // nothing. A brief settle is cheaper than an unexplained no-op.
        try? await Task.sleep(for: .milliseconds(40))

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(reading: pasteboard)

        let target = write(text, to: pasteboard)
        await waitForCommit(target, on: pasteboard)
        sendCommandV(to: targetPID)

        // Restore on a delay, so the target app has had a chance to read.
        try? await Task.sleep(for: restoreDelay)
        snapshot.restore(to: pasteboard)
    }

    private static func write(_ text: String, to pasteboard: NSPasteboard) -> Int {
        let before = pasteboard.changeCount
        pasteboard.clearContents()
        // Marks the write transient so clipboard managers ignore it.
        pasteboard.setString("", forType: .init("org.nspasteboard.ConcealedType"))
        pasteboard.setString(text, forType: .string)
        let after = pasteboard.changeCount
        // The system coalesces writes occasionally; never return a target that
        // has already passed, or the wait below spins to its timeout.
        return after == before ? after + 1 : after
    }

    /// The pasteboard write is not synchronous. Pasting before it commits
    /// pastes whatever was there before, which reads as "dictation pasted the
    /// wrong thing" and is maddening to reproduce.
    private static func waitForCommit(_ target: Int, on pasteboard: NSPasteboard) async {
        guard target > pasteboard.changeCount else { return }
        let deadline = ContinuousClock.now + commitTimeout
        while ContinuousClock.now < deadline {
            if pasteboard.changeCount >= target { return }
            try? await Task.sleep(for: commitPollInterval)
        }
    }

    private static func sendCommandV(to targetPID: pid_t?) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9   // kVK_ANSI_V

        // Clear any modifiers the user is still holding. The dictation key is
        // often a modifier, and releasing it is what triggered this paste, so
        // a stale flag can turn Cmd-V into Cmd-Opt-V and do nothing.
        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        post(down, to: targetPID)

        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand
        post(up, to: targetPID)
    }

    private static func post(_ event: CGEvent?, to targetPID: pid_t?) {
        guard let event else { return }
        if let targetPID {
            event.postToPid(targetPID)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }

    private static func isSecureTextField(in pid: pid_t) -> Bool {
        let application = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success,
        let focused,
        CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return false
        }

        let element = unsafeDowncast(focused, to: AXUIElement.self)
        var subrole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSubroleAttribute as CFString, &subrole
        ) == .success else {
            return false
        }

        return subrole as? String == kAXSecureTextFieldSubrole as String
    }

    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
