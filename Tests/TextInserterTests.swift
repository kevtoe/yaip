import XCTest
@testable import Yaip

@MainActor
final class TextInserterTests: XCTestCase {

    func testGlobalSecureInputDoesNotBlockACapturedNonSecureTarget() {
        XCTAssertFalse(
            TextInserter.shouldCopyOnlyForSecureInput(
                targetPID: 123,
                secureInputActive: true,
                targetIsSecureTextField: false
            )
        )
    }

    func testSecureTextFieldAlwaysUsesCopyOnly() {
        XCTAssertTrue(
            TextInserter.shouldCopyOnlyForSecureInput(
                targetPID: 123,
                secureInputActive: true,
                targetIsSecureTextField: true
            )
        )
    }

    func testSecureInputWithoutACapturedTargetUsesCopyOnly() {
        XCTAssertTrue(
            TextInserter.shouldCopyOnlyForSecureInput(
                targetPID: nil,
                secureInputActive: true,
                targetIsSecureTextField: false
            )
        )
    }
}
