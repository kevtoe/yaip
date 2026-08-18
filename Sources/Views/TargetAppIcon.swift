import AppKit
import SwiftUI

/// The icon of the app a dictation went into.
///
/// Reading a row is faster with the real icon than with the app's name alone.
struct TargetAppIcon: View {
    let bundleID: String?

    private static let size: CGFloat = 16

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .foregroundStyle(YPPalette.inkSoft)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }

    private var icon: NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
