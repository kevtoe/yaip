import AppKit
import ApplicationServices

/// Works out where on screen the user is actually typing, so the overlay can
/// appear next to the text rather than parked at the bottom of the display.
///
/// Four levels of fallback, because no single one works everywhere: Electron
/// apps rarely expose a caret rect, some expose the field but not the range,
/// and a few expose nothing at all.
@MainActor
enum CaretLocator {

    /// Screen rectangle to anchor the overlay to, in AppKit coordinates
    /// (bottom-left origin), or nil if nothing could be determined.
    static func anchorRect() -> NSRect? {
        guard InputPermissions.hasAccessibility else { return nil }
        guard let focused = focusedElement() else { return frontmostWindowRect() }

        return caretRect(of: focused)
            ?? elementRect(of: focused)
            ?? frontmostWindowRect()
    }

    // MARK: Levels

    private static func focusedElement() -> AXUIElement? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success,
            let value = focused,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    /// The insertion point itself. Best result when the app provides it.
    private static func caretRect(of element: AXUIElement) -> NSRect? {
        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &range
        ) == .success, let range else { return nil }

        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &bounds
        ) == .success, let bounds else { return nil }

        guard let rect = cgRect(from: bounds), rect.width.isFinite, rect.height > 0 else {
            return nil
        }
        return flipped(rect)
    }

    /// The whole text field. Coarser, but usually still the right region.
    private static func elementRect(of element: AXUIElement) -> NSRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXPositionAttribute as CFString, &positionValue
        ) == .success,
            AXUIElementCopyAttributeValue(
                element, kAXSizeAttribute as CFString, &sizeValue
            ) == .success,
            let positionValue, let sizeValue
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
              size.height > 0
        else { return nil }

        return flipped(CGRect(origin: origin, size: size))
    }

    /// Last resort before giving up: centre on the frontmost window.
    private static func frontmostWindowRect() -> NSRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)

        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXFocusedWindowAttribute as CFString, &window
        ) == .success,
            let window, CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return nil }

        return elementRect(of: unsafeDowncast(window, to: AXUIElement.self))
    }

    // MARK: Coordinate conversion

    private static func cgRect(from value: CFTypeRef) -> CGRect? {
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    /// Accessibility reports top-left origin with Y increasing downward.
    /// AppKit windows use bottom-left origin with Y increasing upward, measured
    /// from the primary screen. Getting this backwards puts the overlay off the
    /// top of the display on a multi-monitor setup.
    private static func flipped(_ rect: CGRect) -> NSRect? {
        guard let primary = NSScreen.screens.first else { return nil }
        return NSRect(
            x: rect.origin.x,
            y: primary.frame.maxY - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
