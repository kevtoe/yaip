import XCTest
@testable import Yaip

/// The router is the piece that stops Parakeet being handed a language it was
/// never trained on, so it carries the tests.
final class LanguageRouterTests: XCTestCase {

    private let router = LanguageRouter()

    func testParakeetKeptForSupportedLanguage() {
        let config = RunnerConfig(
            engine: .fluidParakeet(model: ParakeetModel.v3.rawValue),
            language: .fixed("en")
        )
        let decision = router.route(config: config, detectedLanguage: nil)

        XCTAssertEqual(decision.selection, config.engine)
        XCTAssertNil(decision.substitutionReason, "A supported language must not be rerouted.")
    }

    func testVietnameseRoutesAwayFromParakeet() {
        let config = RunnerConfig(
            engine: .fluidParakeet(model: ParakeetModel.v3.rawValue),
            language: .fixed("vi")
        )
        let decision = router.route(config: config, detectedLanguage: nil)

        guard case .whisperKit = decision.selection else {
            return XCTFail("Vietnamese must fall back to Whisper, got \(decision.selection).")
        }
        XCTAssertNotNil(
            decision.substitutionReason,
            "A substitution must be reported so it is never silent."
        )
    }

    func testDetectedLanguageDrivesRoutingWhenModeIsAuto() {
        let config = RunnerConfig(
            engine: .fluidParakeet(model: ParakeetModel.v3.rawValue),
            language: .auto
        )
        let decision = router.route(config: config, detectedLanguage: "vi")

        guard case .whisperKit = decision.selection else {
            return XCTFail("Detected Vietnamese must reroute, got \(decision.selection).")
        }
    }

    func testUnknownLanguageLeavesChoiceAlone() {
        let config = RunnerConfig(
            engine: .fluidParakeet(model: ParakeetModel.v3.rawValue),
            language: .auto
        )
        let decision = router.route(config: config, detectedLanguage: nil)

        XCTAssertEqual(decision.selection, config.engine)
        XCTAssertNil(decision.substitutionReason)
    }

    func testWhisperIsNeverRerouted() {
        for code in ["vi", "th", "en", "zh", "ar"] {
            let config = RunnerConfig(
                engine: .whisperKit(model: WhisperModel.largeV3Turbo.rawValue),
                language: .fixed(code)
            )
            let decision = router.route(config: config, detectedLanguage: nil)
            XCTAssertNil(decision.substitutionReason, "Whisper handles \(code) directly.")
        }
    }

    func testRegionalCodeMatchesPrimarySubtag() {
        let config = RunnerConfig(
            engine: .fluidParakeet(model: ParakeetModel.v3.rawValue),
            language: .fixed("en-AU")
        )
        let decision = router.route(config: config, detectedLanguage: nil)

        XCTAssertEqual(decision.selection, config.engine, "en-AU must satisfy en.")
    }

    func testRegisteredWhisperIsUniversal() {
        let selection = EngineSelection.registeredLocal(
            id: UUID(), engine: .whisperKit, displayName: "My Whisper"
        )
        let decision = router.route(
            config: RunnerConfig(engine: selection, language: .fixed("vi")),
            detectedLanguage: nil
        )

        XCTAssertEqual(decision.selection, selection)
    }

    func testRegisteredParakeetStillRoutesUnsupportedLanguages() {
        let selection = EngineSelection.registeredLocal(
            id: UUID(), engine: .parakeetV3, displayName: "My Parakeet"
        )
        let decision = router.route(
            config: RunnerConfig(engine: selection, language: .fixed("vi")),
            detectedLanguage: nil
        )

        guard case .whisperKit = decision.selection else {
            return XCTFail("Registered Parakeet must retain its language limits.")
        }
    }
}
