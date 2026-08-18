import XCTest
@testable import Yaip

final class DistributionTests: XCTestCase {
    func testPublicIdentityAndCredit() {
        XCTAssertEqual(AppIdentity.name, "Yaip")
        XCTAssertEqual(AppIdentity.tagline, "Yap, don't type.")
        XCTAssertEqual(AppIdentity.creatorName, "KTO")
        XCTAssertEqual(AppIdentity.creatorURL.absoluteString, "https://github.com/kevtoe")
    }

    func testAcknowledgementResourcesAreBundled() {
        let required = [
            "ArgmaxOSS-MIT.txt",
            "ArgmaxOSS-NOTICES.txt",
            "FluidAudio-Apache-2.0.txt",
            "WhisperTiny-Model-Notice.txt",
            "OpenAI-Whisper-MIT.txt",
            "Apache-2.0.txt",
            "Parakeet-TDT-v3-Notice.txt",
            "Urbanist-OFL.txt",
        ]

        for name in required {
            let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
            XCTAssertNotNil(
                Bundle.main.url(forResource: parts[0], withExtension: parts[1]),
                "Missing acknowledgement resource: \(name)"
            )
        }
    }

    func testCompatibilityContractStartsAtMacOS14() {
        XCTAssertEqual(PlatformSupport.minimumMacOS, "14.0")
    }

    func testParakeetIsOnlyAdvertisedWhereSupported() {
        let hasParakeet = ModelDescriptor.builtIns.contains {
            if case .fluidParakeet = $0.selection { return true }
            return false
        }
        XCTAssertEqual(hasParakeet, PlatformSupport.supportsParakeet)
    }

    func testOlderMacOSFallbackIsWhisperWhenBundledModelExists() {
        guard PlatformSupport.supportsAppleSpeech == false,
              ModelStorage.hasBundledWhisper(WhisperModel.tiny.rawValue) else { return }
        XCTAssertEqual(
            ModelDescriptor.defaultDictationSelection,
            .whisperKit(model: WhisperModel.tiny.rawValue)
        )
    }
}

final class FirstRunStateTests: XCTestCase {

    func testSetupCompletionPersists() {
        let original = FirstRunState.hasCompletedSetup
        defer { FirstRunState.hasCompletedSetup = original }

        FirstRunState.hasCompletedSetup = false
        XCTAssertFalse(FirstRunState.hasCompletedSetup)
        FirstRunState.hasCompletedSetup = true
        XCTAssertTrue(FirstRunState.hasCompletedSetup)
    }
}
