import AppKit
import XCTest
@testable import Yaip

/// The clipboard is the user's, not ours. Dictation borrows it for a few
/// hundred milliseconds, so restoring it exactly is not optional.
final class PasteboardSnapshotTests: XCTestCase {

    /// A private pasteboard, so running tests never disturbs the real one.
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: .init("app.yaip.tests.\(UUID().uuidString)"))
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        super.tearDown()
    }

    @MainActor func testRestoresPlainText() {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let snapshot = PasteboardSnapshot(reading: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("dictated text", forType: .string)
        snapshot.restore(to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    @MainActor func testRestoresEveryRepresentationNotJustTheString() {
        // The failure this guards against: saving only `.string` and silently
        // destroying the rich or binary representations alongside it.
        let rtf = Data("{\\rtf1\\ansi rich}".utf8)
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString("plain", forType: .string)
        item.setData(rtf, forType: .rtf)
        pasteboard.writeObjects([item])

        let snapshot = PasteboardSnapshot(reading: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("dictated text", forType: .string)
        snapshot.restore(to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "plain")
        XCTAssertEqual(pasteboard.data(forType: .rtf), rtf, "Rich text was lost.")
    }

    @MainActor func testRestoringAnEmptyPasteboardLeavesItEmpty() {
        pasteboard.clearContents()
        let snapshot = PasteboardSnapshot(reading: pasteboard)

        pasteboard.setString("dictated text", forType: .string)
        snapshot.restore(to: pasteboard)

        XCTAssertNil(pasteboard.string(forType: .string))
    }

    @MainActor func testMultipleItemsSurvive() {
        pasteboard.clearContents()
        let first = NSPasteboardItem()
        first.setString("one", forType: .string)
        let second = NSPasteboardItem()
        second.setString("two", forType: .string)
        pasteboard.writeObjects([first, second])

        let snapshot = PasteboardSnapshot(reading: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("dictated text", forType: .string)
        snapshot.restore(to: pasteboard)

        XCTAssertEqual(pasteboard.pasteboardItems?.count, 2)
    }
}
