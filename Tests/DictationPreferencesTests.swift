import XCTest
@testable import Yaip

/// These exist because of a real defect: the dictation key and model were
/// plain properties, so changing them appeared to work and then reverted on
/// the next launch.
final class DictationPreferencesTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "app.yaip.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    @MainActor func testDefaultsUseTheSafePlatformDefault() {
        let preferences = DictationPreferences(defaults: defaults)

        XCTAssertEqual(preferences.shortcut, .modifier(.fn))
        XCTAssertEqual(preferences.activationMode, .pushToTalk)
        XCTAssertEqual(preferences.engine, ModelDescriptor.defaultDictationSelection)
    }

    @MainActor func testModifierShortcutSurvivesRelaunch() {
        DictationPreferences(defaults: defaults).shortcut = .modifier(.rightOption)

        // A second instance stands in for the next launch.
        XCTAssertEqual(
            DictationPreferences(defaults: defaults).shortcut,
            .modifier(.rightOption)
        )
    }

    @MainActor func testCombinationShortcutSurvivesRelaunch() {
        let combination = DictationShortcut.combination(
            keyCode: 2,                       // D
            modifiers: [.command, .shift]
        )
        DictationPreferences(defaults: defaults).shortcut = combination

        XCTAssertEqual(DictationPreferences(defaults: defaults).shortcut, combination)
    }

    @MainActor func testEveryPreferenceSurvivesRelaunch() {
        let first = DictationPreferences(defaults: defaults)
        first.shortcut = .modifier(.rightCommand)
        first.activationMode = .toggle
        first.overlayNearCaret = false
        first.soundCuesEnabled = false
        first.pasteRestoreDelayMS = 1200
        first.engine = .whisperKit(model: WhisperModel.largeV3Turbo.rawValue)
        first.insertionMethod = .accessibility

        let second = DictationPreferences(defaults: defaults)
        XCTAssertEqual(second.shortcut, .modifier(.rightCommand))
        XCTAssertEqual(second.activationMode, .toggle)
        XCTAssertFalse(second.overlayNearCaret)
        XCTAssertFalse(second.soundCuesEnabled)
        XCTAssertEqual(second.pasteRestoreDelayMS, 1200)
        XCTAssertEqual(second.engine, .whisperKit(model: WhisperModel.largeV3Turbo.rawValue))
        XCTAssertEqual(second.insertionMethod, .accessibility)
    }

    @MainActor func testRegisteredModelSelectionSurvivesRelaunch() {
        let selection = EngineSelection.registeredLocal(
            id: UUID(), engine: .whisperKit, displayName: "Studio Whisper"
        )
        DictationPreferences(defaults: defaults).engine = selection

        XCTAssertEqual(DictationPreferences(defaults: defaults).engine, selection)
    }

    @MainActor func testCorruptStoredValuesFallBackRatherThanCrashing() {
        defaults.set(Data("not json".utf8), forKey: "dictation.engine")
        defaults.set(Data("not json".utf8), forKey: "dictation.shortcut")

        let preferences = DictationPreferences(defaults: defaults)
        XCTAssertEqual(preferences.shortcut, .default)
        XCTAssertEqual(preferences.engine, ModelDescriptor.defaultDictationSelection)
    }
}
