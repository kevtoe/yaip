import Foundation
import XCTest
@testable import Yaip

@MainActor
final class ModelManagerTests: XCTestCase {

    func testRegisteredModelPersistsAndForgetDoesNotDeleteFolder() async throws {
        let suite = "app.yaip.models.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let folder = try makeWhisperFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let first = ModelManager(defaults: defaults)
        await first.registerModelFolder(folder)
        XCTAssertNil(first.importError)
        let registration = try XCTUnwrap(first.registeredModels.first)

        let second = ModelManager(defaults: defaults)
        XCTAssertEqual(second.registeredModels.first?.id, registration.id)
        XCTAssertTrue(second.catalog.contains { $0.registeredID == registration.id })

        second.forgetRegisteredModel(registration.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(second.registeredModels.isEmpty)
    }

    func testDuplicateFolderIsRejected() async throws {
        let suite = "app.yaip.models.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let folder = try makeWhisperFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let manager = ModelManager(defaults: defaults)
        await manager.registerModelFolder(folder)
        await manager.registerModelFolder(folder)

        XCTAssertEqual(manager.registeredModels.count, 1)
        XCTAssertEqual(manager.importError, "That model folder is already registered.")
    }

    private func makeWhisperFolder() throws -> URL {
        let root = URL.temporaryDirectory.appending(path: "yaip-manager-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["MelSpectrogram", "AudioEncoder", "TextDecoder"] {
            let model = root.appending(path: "\(name).mlmodelc")
            try FileManager.default.createDirectory(at: model, withIntermediateDirectories: true)
            try Data([0]).write(to: model.appending(path: "coremldata.bin"))
        }
        try Data("{}".utf8).write(to: root.appending(path: "tokenizer.json"))
        try Data("{}".utf8).write(to: root.appending(path: "tokenizer_config.json"))
        return root
    }
}
