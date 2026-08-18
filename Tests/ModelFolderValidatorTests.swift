import Foundation
import XCTest
@testable import Yaip

final class ModelFolderValidatorTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = URL.temporaryDirectory.appending(path: "yaip-model-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        root = nil
        super.tearDown()
    }

    func testDetectsCompleteWhisperKitFolder() throws {
        try makeWhisperFolder(at: root, includeTokenizer: true)

        XCTAssertEqual(try ModelFolderValidator.detectEngine(in: root), .whisperKit)
        XCTAssertNoThrow(
            try ModelFolderValidator.validate(modelFolder: root, engine: .whisperKit)
        )
    }

    func testWhisperRequiresTokenizerWithoutDownloadingOne() throws {
        try makeWhisperFolder(at: root, includeTokenizer: false)

        XCTAssertThrowsError(
            try ModelFolderValidator.validate(modelFolder: root, engine: .whisperKit)
        ) { error in
            XCTAssertEqual(error as? ModelFolderValidator.ValidationError, .tokenizerRequired)
        }
    }

    func testWhisperAcceptsASeparateTokenizerFolder() throws {
        try makeWhisperFolder(at: root, includeTokenizer: false)
        let tokenizer = root.appending(path: "tokenizer")
        try makeTokenizer(at: tokenizer)

        XCTAssertNoThrow(
            try ModelFolderValidator.validate(
                modelFolder: root,
                engine: .whisperKit,
                tokenizerFolder: tokenizer
            )
        )
    }

    func testRejectsACompiledModelMissingItsPayload() throws {
        try makeWhisperFolder(at: root, includeTokenizer: true)
        try FileManager.default.removeItem(
            at: root.appending(path: "AudioEncoder.mlmodelc/coremldata.bin")
        )

        XCTAssertThrowsError(
            try ModelFolderValidator.validate(modelFolder: root, engine: .whisperKit)
        )
    }

    func testDetectsParakeetAndValidatesVocabulary() throws {
        try makeParakeetFolder(at: root)

        XCTAssertEqual(try ModelFolderValidator.detectEngine(in: root), .parakeetV3)
        XCTAssertNoThrow(
            try ModelFolderValidator.validate(modelFolder: root, engine: .parakeetV3)
        )
    }

    func testRejectsUnsupportedModelFormats() throws {
        try Data().write(to: root.appending(path: "model.gguf"))

        XCTAssertThrowsError(try ModelFolderValidator.detectEngine(in: root)) { error in
            XCTAssertEqual(error as? ModelFolderValidator.ValidationError, .unsupportedLayout)
        }
    }

    func testRejectsInvalidParakeetVocabulary() throws {
        try makeParakeetFolder(at: root)
        try Data("not json".utf8).write(to: root.appending(path: "parakeet_vocab.json"))

        XCTAssertThrowsError(
            try ModelFolderValidator.validate(modelFolder: root, engine: .parakeetV3)
        ) { error in
            XCTAssertEqual(
                error as? ModelFolderValidator.ValidationError,
                .invalidJSON("parakeet_vocab.json")
            )
        }
    }

    func testRejectsCompiledModelWithMissingReferencedBlob() throws {
        try makeWhisperFolder(at: root, includeTokenizer: true)
        let model = root.appending(path: "AudioEncoder.mlmodelc")
        try Data("BLOBFILE(path = tensor<string, []>(\"@model_path/weights/weight.bin\"))".utf8)
            .write(to: model.appending(path: "model.mil"))

        XCTAssertThrowsError(
            try ModelFolderValidator.validate(modelFolder: root, engine: .whisperKit)
        )
    }

    private func makeWhisperFolder(at folder: URL, includeTokenizer: Bool) throws {
        for name in ["MelSpectrogram", "AudioEncoder", "TextDecoder"] {
            try makeCompiledModel(folder.appending(path: "\(name).mlmodelc"))
        }
        if includeTokenizer { try makeTokenizer(at: folder) }
    }

    private func makeTokenizer(at folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: folder.appending(path: "tokenizer.json"))
        try Data("{}".utf8).write(to: folder.appending(path: "tokenizer_config.json"))
    }

    private func makeParakeetFolder(at folder: URL) throws {
        for name in ["Preprocessor", "Encoder", "Decoder", "JointDecisionv3"] {
            try makeCompiledModel(folder.appending(path: "\(name).mlmodelc"))
        }
        try Data("{\"0\":\"a\"}".utf8)
            .write(to: folder.appending(path: "parakeet_vocab.json"))
    }

    private func makeCompiledModel(_ folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data([0]).write(to: folder.appending(path: "coremldata.bin"))
    }

}
