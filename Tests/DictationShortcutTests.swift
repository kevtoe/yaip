import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import Yaip

final class DictationShortcutTests: XCTestCase {

    /// Key code and flag must agree: the monitor uses the key code to identify
    /// which modifier changed and the flag to tell whether it is now down. A
    /// mismatched pair produces a shortcut that never fires.
    func testModifierKeyCodeAndFlagAgree() {
        XCTAssertEqual(ModifierKey.fn.flag, .maskSecondaryFn)
        XCTAssertEqual(ModifierKey.rightOption.flag, .maskAlternate)
        XCTAssertEqual(ModifierKey.leftOption.flag, .maskAlternate)
        XCTAssertEqual(ModifierKey.rightCommand.flag, .maskCommand)
        XCTAssertEqual(ModifierKey.rightControl.flag, .maskControl)
        XCTAssertEqual(ModifierKey.rightShift.flag, .maskShift)
    }

    /// Left and right must stay distinct, or binding the right key would also
    /// capture the left one and break typing.
    func testEveryModifierHasADistinctKeyCode() {
        let codes = ModifierKey.allCases.map(\.keyCode)
        XCTAssertEqual(Set(codes).count, codes.count)
    }

    func testModifierLookupByKeyCodeRoundTrips() {
        for key in ModifierKey.allCases {
            XCTAssertEqual(ModifierKey.from(keyCode: key.keyCode), key)
        }
    }

    func testModifierFlagsRoundTripThroughEventFlags() {
        let cases: [ModifierFlags] = [
            [], [.command], [.command, .shift], [.control, .option, .shift, .command], [.fn],
        ]
        for flags in cases {
            XCTAssertEqual(ModifierFlags(eventFlags: flags.eventFlags), flags)
        }
    }

    /// Modifiers display in the order macOS uses.
    func testModifierSymbolOrder() {
        let all: ModifierFlags = [.command, .shift, .option, .control]
        XCTAssertEqual(all.symbols, "⌃⌥⇧⌘")
    }

    func testOnlyBareModifiersCountAsModifierOnly() {
        XCTAssertTrue(DictationShortcut.modifier(.fn).isModifierOnly)
        XCTAssertFalse(
            DictationShortcut.combination(keyCode: 2, modifiers: [.command]).isModifierOnly
        )
    }

    func testCombinationDisplaysModifiersThenKey() {
        let shortcut = DictationShortcut.combination(
            keyCode: kVK_Space,
            modifiers: [.command, .shift]
        )
        XCTAssertEqual(shortcut.displayString, "⇧⌘Space")
    }

    func testShortcutRoundTripsThroughCoding() throws {
        let cases: [DictationShortcut] = [
            .modifier(.fn),
            .modifier(.rightOption),
            .combination(keyCode: 2, modifiers: [.command, .shift]),
            .combination(keyCode: kVK_Space, modifiers: []),
        ]
        for shortcut in cases {
            let data = try JSONEncoder().encode(shortcut)
            XCTAssertEqual(try JSONDecoder().decode(DictationShortcut.self, from: data), shortcut)
        }
    }

    func testKeysThatClashWithTypingCarryAWarning() {
        // Fn is claimed by macOS; left-side modifiers are used constantly.
        XCTAssertNotNil(DictationShortcut.modifier(.fn).conflictWarning)
        XCTAssertNotNil(DictationShortcut.modifier(.leftOption).conflictWarning)
        XCTAssertNotNil(DictationShortcut.modifier(.leftCommand).conflictWarning)
        XCTAssertNil(DictationShortcut.modifier(.rightOption).conflictWarning)

        // A bare key with no modifiers would fire while typing.
        XCTAssertNotNil(
            DictationShortcut.combination(keyCode: 2, modifiers: []).conflictWarning
        )
        XCTAssertNil(
            DictationShortcut.combination(keyCode: 2, modifiers: [.command]).conflictWarning
        )
    }
}
