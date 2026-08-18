import AppKit
import UniformTypeIdentifiers

/// Wraps the open panel so the presentation logic stays out of view bodies.
@MainActor
enum MediaFileImporter {
    static let supportedTypes: [UTType] = [.audio, .movie, .mpeg4Audio, .mp3, .wav, .aiff]

    static func chooseFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = supportedTypes
        panel.prompt = "Transcribe"
        panel.message = "Choose audio or video to transcribe"

        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}
