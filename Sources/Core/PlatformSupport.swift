import Foundation

/// The compatibility contract advertised by distributable Yaip builds.
enum PlatformSupport {
    static let minimumMacOS = "14.0"

    static var architecture: String {
        #if arch(arm64)
        "Apple Silicon"
        #elseif arch(x86_64)
        "Intel"
        #else
        "Unknown"
        #endif
    }

    static var supportsParakeet: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }

    static var supportsAppleSpeech: Bool {
        if #available(macOS 26, *) { true } else { false }
    }
}
