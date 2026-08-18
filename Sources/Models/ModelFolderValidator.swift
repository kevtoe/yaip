import Foundation

/// Recognises the exact Core ML layouts supported by Yaip's current runners.
enum ModelFolderValidator {
    private static let whisperComponents = [
        "MelSpectrogram", "AudioEncoder", "TextDecoder",
    ]
    private static let parakeetComponents = [
        "Preprocessor.mlmodelc",
        "Encoder.mlmodelc",
        "Decoder.mlmodelc",
        "JointDecisionv3.mlmodelc",
    ]

    enum ValidationError: LocalizedError, Equatable {
        case folderMissing(String)
        case unsupportedLayout
        case missingFiles([String])
        case tokenizerRequired
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .folderMissing(let path):
                "The selected folder is no longer available: \(path)"
            case .unsupportedLayout:
                "Choose a WhisperKit Core ML folder or a Parakeet TDT v3 Core ML folder. GGUF, PyTorch, safetensors and ONNX models are not compatible."
            case .missingFiles(let names):
                "This folder is incomplete. Missing: \(names.joined(separator: ", "))."
            case .tokenizerRequired:
                "This Whisper model needs its tokenizer folder. Choose the folder containing tokenizer.json and tokenizer_config.json."
            case .invalidJSON(let name):
                "\(name) is not valid JSON."
            }
        }
    }

    static func detectEngine(in folder: URL) throws -> LocalModelEngine {
        guard folderExists(folder) else {
            throw ValidationError.folderMissing(folder.path)
        }
        if missingWhisperComponents(in: folder).isEmpty {
            return .whisperKit
        }
        if missingParakeetFiles(in: folder).isEmpty {
            return .parakeetV3
        }
        throw ValidationError.unsupportedLayout
    }

    static func validate(
        modelFolder: URL,
        engine: LocalModelEngine,
        tokenizerFolder: URL? = nil
    ) throws {
        guard folderExists(modelFolder) else {
            throw ValidationError.folderMissing(modelFolder.path)
        }

        switch engine {
        case .whisperKit:
            let missingModels = missingWhisperComponents(in: modelFolder)
            guard missingModels.isEmpty else {
                throw ValidationError.missingFiles(missingModels)
            }
            let tokenizer = tokenizerFolder ?? modelFolder
            guard hasWhisperTokenizer(in: tokenizer) else {
                throw ValidationError.tokenizerRequired
            }
            try validateJSON(tokenizer.appending(path: "tokenizer.json"))
            try validateJSON(tokenizer.appending(path: "tokenizer_config.json"))

        case .parakeetV3:
            let missing = missingParakeetFiles(in: modelFolder)
            guard missing.isEmpty else {
                throw ValidationError.missingFiles(missing)
            }
            try validateJSON(modelFolder.appending(path: "parakeet_vocab.json"))
        }
    }

    static func hasWhisperTokenizer(in folder: URL) -> Bool {
        ["tokenizer.json", "tokenizer_config.json"].allSatisfy {
            FileManager.default.fileExists(atPath: folder.appending(path: $0).path)
        }
    }

    private static func missingWhisperComponents(in folder: URL) -> [String] {
        whisperComponents.compactMap { name in
            let compiled = folder.appending(path: "\(name).mlmodelc")
            let package = folder.appending(path: "\(name).mlpackage")
            if validCompiledModel(at: compiled) || folderExists(package) {
                return nil
            }
            return "\(name).mlmodelc or \(name).mlpackage"
        }
    }

    private static func missingParakeetFiles(in folder: URL) -> [String] {
        let models = parakeetComponents.filter {
            validCompiledModel(at: folder.appending(path: $0)) == false
        }
        let vocabulary = folder.appending(path: "parakeet_vocab.json")
        return FileManager.default.fileExists(atPath: vocabulary.path)
            ? models
            : models + ["parakeet_vocab.json"]
    }

    private static func validCompiledModel(at url: URL) -> Bool {
        guard folderExists(url),
              FileManager.default.fileExists(
                atPath: url.appending(path: "coremldata.bin").path
              ) else { return false }

        let mil = url.appending(path: "model.mil")
        guard let contents = try? String(contentsOf: mil, encoding: .utf8) else {
            return true
        }
        let marker = "@model_path/"
        var remainder = contents[contents.startIndex...]
        var referenced = Set<String>()
        while let range = remainder.range(of: marker) {
            let start = range.upperBound
            let suffix = remainder[start...]
            guard let quote = suffix.firstIndex(of: "\"") else { break }
            referenced.insert(String(suffix[..<quote]))
            remainder = suffix[quote...]
        }
        return referenced.allSatisfy {
            FileManager.default.fileExists(atPath: url.appending(path: $0).path)
        }
    }

    private static func folderExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func validateJSON(_ url: URL) throws {
        do {
            let data = try Data(contentsOf: url)
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ValidationError.invalidJSON(url.lastPathComponent)
        }
    }
}
