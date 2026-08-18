import CoreGraphics
import XCTest

final class OverlayContrastTests: XCTestCase {

    func testOverlayTextAndStateColoursMeetContrastTargets() {
        let surface = RGB(0.102, 0.125, 0.109)

        XCTAssertGreaterThanOrEqual(contrast(RGB(0.925, 0.941, 0.929), surface), 7)
        XCTAssertGreaterThanOrEqual(contrast(RGB(0.659, 0.706, 0.671), surface), 7)
        XCTAssertGreaterThanOrEqual(contrast(RGB(0.486, 0.788, 0.514), surface), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(RGB(0.941, 0.392, 0.384), surface), 4.5)
    }

    private func contrast(_ lhs: RGB, _ rhs: RGB) -> Double {
        let values = [lhs.luminance, rhs.luminance].sorted(by: >)
        return (values[0] + 0.05) / (values[1] + 0.05)
    }
}

private struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var luminance: Double {
        0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func linear(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}
