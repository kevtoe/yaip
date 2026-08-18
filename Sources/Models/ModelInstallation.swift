import Foundation

/// Whether a local model is on disk.
enum ModelInstallation: Equatable, Sendable {
    /// Managed by the system, nothing for us to download.
    case systemManaged
    /// Shipped inside the application bundle, available without a download.
    case bundled
    case notDownloaded
    case downloading(fraction: Double)
    case installed(bytes: Int64)
    case registered
    case unavailable(reason: String)
    case downloadFailed(reason: String)

    var isInstalled: Bool {
        switch self {
        case .installed, .systemManaged, .bundled, .registered: true
        case .notDownloaded, .downloading, .unavailable, .downloadFailed: false
        }
    }

    var isDownloading: Bool {
        if case .downloading = self { true } else { false }
    }
}
