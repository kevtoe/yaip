import AppKit
import ApplicationServices
// IsSecureEventInputEnabled lives in HIToolbox, not ApplicationServices.
import Carbon.HIToolbox
import IOKit.hid

/// The two separate permissions a hold-to-talk hotkey needs.
///
/// These are genuinely distinct and fail differently: without Accessibility we
/// cannot post the synthetic paste, and without Input Monitoring the event tap
/// never receives the key. Checking only one produces a hotkey that silently
/// does nothing.
@MainActor
enum InputPermissions {

    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    static var hasInputMonitoring: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static var allGranted: Bool {
        hasAccessibility && hasInputMonitoring
    }

    /// Shows the system prompt. Only ever call this from an explicit user
    /// action: macOS shows the dialog once per app version, so spending it on
    /// a background check leaves the user with no way back.
    @discardableResult
    static func requestAccessibility() -> Bool {
        // The literal rather than `kAXTrustedCheckOptionPrompt`, which is an
        // imported global var and therefore not concurrency-safe to touch.
        let options = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openAccessibilitySettings() {
        open("com.apple.preference.security?Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        open("com.apple.preference.security?Privacy_ListenEvent")
    }

    /// True when any process has enabled Secure Event Input. This is global,
    /// not proof that the captured target is itself a password field.
    static var isSecureInputActive: Bool {
        IsSecureEventInputEnabled()
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: "x-apple.systempreferences:\(urlString)") else { return }
        NSWorkspace.shared.open(url)
    }
}
