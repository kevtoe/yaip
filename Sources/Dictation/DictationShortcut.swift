import Carbon.HIToolbox
import CoreGraphics

/// The shortcut that starts dictation.
///
/// Two shapes, because hold-to-talk and toggle want different things. Holding
/// a single modifier is comfortable for push-to-talk and impossible to type by
/// accident; a full combination is what you want for a toggle you press once
/// and forget.
enum DictationShortcut: Codable, Hashable, Sendable {
    /// Hold one modifier, e.g. Fn or Right Option.
    case modifier(ModifierKey)
    /// A key plus modifiers, e.g. ⌘⇧D.
    case combination(keyCode: Int, modifiers: ModifierFlags)

    static let `default` = DictationShortcut.modifier(.fn)

    var displayString: String {
        switch self {
        // Name only. The symbol would just repeat it ("fn  Fn") and the name
        // is the clearer half for a single key.
        case .modifier(let key):
            key.displayName
        case .combination(let keyCode, let modifiers):
            modifiers.symbols + KeyCodeNames.name(for: keyCode)
        }
    }

    /// True when the shortcut is a bare modifier, which is the only shape that
    /// makes sense for hold-to-talk.
    var isModifierOnly: Bool {
        if case .modifier = self { true } else { false }
    }

    /// Flags this shortcut requires, for matching against an event.
    var requiredFlags: CGEventFlags {
        switch self {
        case .modifier(let key):            key.flag
        case .combination(_, let modifiers): modifiers.eventFlags
        }
    }

    var keyCode: Int {
        switch self {
        case .modifier(let key):        key.keyCode
        case .combination(let code, _): code
        }
    }

    /// Warns where macOS or common apps already claim the shortcut.
    var conflictWarning: String? {
        switch self {
        case .modifier(.fn):
            "macOS may also use Fn for its own dictation or the emoji picker. "
                + "Set “Press 🌐 key to” to “Do Nothing” in Keyboard settings."
        case .modifier(.leftOption):
            "Left Option types accented characters. Right Option is usually safer."
        case .modifier(.leftCommand), .modifier(.leftControl), .modifier(.leftShift):
            "Left-side modifiers are used constantly while typing. "
                + "A right-side key is usually a better choice."
        case .modifier:
            nil
        case .combination(_, let modifiers):
            modifiers.isEmpty
                ? "A shortcut with no modifiers will fire whenever you type that key."
                : nil
        }
    }
}

/// Modifier flags, stored in a form that round-trips through JSON.
struct ModifierFlags: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let command = ModifierFlags(rawValue: 1 << 0)
    static let option  = ModifierFlags(rawValue: 1 << 1)
    static let control = ModifierFlags(rawValue: 1 << 2)
    static let shift   = ModifierFlags(rawValue: 1 << 3)
    static let fn      = ModifierFlags(rawValue: 1 << 4)

    init(rawValue: Int) { self.rawValue = rawValue }

    init(eventFlags: CGEventFlags) {
        var flags = ModifierFlags()
        if eventFlags.contains(.maskCommand)     { flags.insert(.command) }
        if eventFlags.contains(.maskAlternate)   { flags.insert(.option) }
        if eventFlags.contains(.maskControl)     { flags.insert(.control) }
        if eventFlags.contains(.maskShift)       { flags.insert(.shift) }
        if eventFlags.contains(.maskSecondaryFn) { flags.insert(.fn) }
        self = flags
    }

    var eventFlags: CGEventFlags {
        var flags = CGEventFlags()
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option)  { flags.insert(.maskAlternate) }
        if contains(.shift)   { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.fn)      { flags.insert(.maskSecondaryFn) }
        return flags
    }

    /// In the order macOS displays them.
    var symbols: String {
        var out = ""
        if contains(.control) { out += "⌃" }
        if contains(.option)  { out += "⌥" }
        if contains(.shift)   { out += "⇧" }
        if contains(.command) { out += "⌘" }
        if contains(.fn)      { out += "fn" }
        return out
    }
}
