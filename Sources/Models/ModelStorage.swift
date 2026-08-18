import Foundation

/// Where model weights live.
///
/// Yaip keeps its downloads in Application Support instead of Documents. This
/// avoids clutter and leaves user-owned model folders untouched.
enum ModelStorage {
    private static let bundledWhisperTinyDirectory = "Models/WhisperTiny"

    /// Root for everything Yaip downloads.
    static var root: URL {
        let url = URL.applicationSupportDirectory.appending(path: "Yaip/Models")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// What WhisperKit is given as its `downloadBase`. It appends its own
    /// `models/<repo>/<variant>` beneath this.
    static var whisperKitBase: URL {
        root.appending(path: "WhisperKit")
    }

    static func whisperKitModel(_ name: String) -> URL {
        whisperKitBase.appending(path: "models/argmaxinc/whisperkit-coreml/\(name)")
    }

    static func bundledWhisperModel(_ name: String) -> URL? {
        guard name == WhisperModel.tiny.rawValue,
              let resources = Bundle.main.resourceURL else { return nil }
        let url = resources.appending(path: "\(bundledWhisperTinyDirectory)/Model")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func bundledWhisperTokenizer(_ name: String) -> URL? {
        guard name == WhisperModel.tiny.rawValue,
              let resources = Bundle.main.resourceURL else { return nil }
        let url = resources.appending(path: "\(bundledWhisperTinyDirectory)/Tokenizer")
        return ModelFolderValidator.hasWhisperTokenizer(in: url) ? url : nil
    }

    static func hasBundledWhisper(_ name: String) -> Bool {
        guard let model = bundledWhisperModel(name),
              let tokenizer = bundledWhisperTokenizer(name) else { return false }
        return (try? ModelFolderValidator.validate(
            modelFolder: model,
            engine: .whisperKit,
            tokenizerFolder: tokenizer
        )) != nil
    }

    /// Yaip-managed Parakeet downloads live beside WhisperKit rather than in
    /// FluidAudio's shared cache, so every model Yaip owns has one predictable
    /// home and can be managed without touching another app's files.
    static func parakeetModel(_ name: String) -> URL {
        let managed = parakeetDownloadTarget(name)
        if FileManager.default.fileExists(atPath: managed.path) { return managed }

        // Older Yaip builds used FluidAudio's shared cache. Continue to detect
        // it so an upgrade never turns a working 494 MB model into a redownload.
        let legacy = legacyFluidAudioModel(name)
        return FileManager.default.fileExists(atPath: legacy.path) ? legacy : managed
    }

    static func parakeetDownloadTarget(_ name: String) -> URL {
        root.appending(path: "Parakeet/\(name)")
    }

    static func legacyFluidAudioModel(_ name: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "FluidAudio/Models/\(name)")
    }

    static func whisperKitTokenizer(_ name: String) -> URL? {
        guard let model = WhisperModel(rawValue: name) else { return nil }
        let tokenizerName: String
        switch model {
        case .tiny: tokenizerName = "whisper-tiny"
        case .base: tokenizerName = "whisper-base"
        case .small: tokenizerName = "whisper-small"
        case .largeV3Turbo, .largeV3: tokenizerName = "whisper-large-v3"
        }
        return whisperKitBase.appending(path: "models/openai/\(tokenizerName)")
    }

    /// WhisperKit's historical default. Yaip only reports files found here.
    static var legacyDocumentsLocation: URL {
        URL.homeDirectory.appending(path: "Documents/huggingface")
    }
}
