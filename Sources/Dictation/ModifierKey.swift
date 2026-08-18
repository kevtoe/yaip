import Carbon.HIToolbox
import CoreGraphics

/// A single modifier key, with left and right kept distinct.
///
/// Side matters: binding right Option leaves left Option free for typing
/// accented characters, and the event tap can tell them apart because it
/// matches on key code rather than on the flag alone.
enum ModifierKey: String, CaseIterable, Codable, Sendable {
    case fn
    case leftCommand, rightCommand
    case leftOption, rightOption
    case leftControl, rightControl
    case leftShift, rightShift

    var keyCode: Int {
        switch self {
        case .fn:            kVK_Function
        case .leftCommand:   kVK_Command
        case .rightCommand:  kVK_RightCommand
        case .leftOption:    kVK_Option
        case .rightOption:   kVK_RightOption
        case .leftControl:   kVK_Control
        case .rightControl:  kVK_RightControl
        case .leftShift:     kVK_Shift
        case .rightShift:    kVK_RightShift
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .fn:                            .maskSecondaryFn
        case .leftCommand, .rightCommand:    .maskCommand
        case .leftOption, .rightOption:      .maskAlternate
        case .leftControl, .rightControl:    .maskControl
        case .leftShift, .rightShift:        .maskShift
        }
    }

    var symbol: String {
        switch self {
        case .fn:                            "fn"
        case .leftCommand, .rightCommand:    "⌘"
        case .leftOption, .rightOption:      "⌥"
        case .leftControl, .rightControl:    "⌃"
        case .leftShift, .rightShift:        "⇧"
        }
    }

    var displayName: String {
        switch self {
        case .fn:            "Fn"
        case .leftCommand:   "Left Command"
        case .rightCommand:  "Right Command"
        case .leftOption:    "Left Option"
        case .rightOption:   "Right Option"
        case .leftControl:   "Left Control"
        case .rightControl:  "Right Control"
        case .leftShift:     "Left Shift"
        case .rightShift:    "Right Shift"
        }
    }

    static func from(keyCode: Int) -> ModifierKey? {
        allCases.first { $0.keyCode == keyCode }
    }
}
