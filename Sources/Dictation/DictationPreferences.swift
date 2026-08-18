import Foundation
import Observation

/// Dictation settings that survive relaunch.
///
/// These were previously plain properties on the controller, so changing the
/// key or the model appeared to work and then silently reverted on the next
/// launch. Anything the user can change in Settings has to be written down.
@MainActor
@Observable
final class DictationPreferences {
    private let defaults: UserDefaults

    var shortcut: DictationShortcut {
        didSet { writeJSON(shortcut, .shortcut) }
    }

    var activationMode: DictationActivationMode {
        didSet { write(activationMode.rawValue, .activationMode) }
    }

    var engine: EngineSelection {
        didSet { writeJSON(engine, .engine) }
    }

    var overlayNearCaret: Bool {
        didSet { write(overlayNearCaret, .overlayNearCaret) }
    }

    var soundCuesEnabled: Bool {
        didSet { write(soundCuesEnabled, .soundCues) }
    }

    /// Milliseconds to wait before handing the clipboard back.
    var pasteRestoreDelayMS: Int {
        didSet { write(pasteRestoreDelayMS, .pasteRestoreDelay) }
    }

    /// How text reaches the focused field.
    var insertionMethod: TextInserter.Method {
        didSet { write(insertionMethod.rawValue, .insertionMethod) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        shortcut = defaults.data(forKey: Key.shortcut.rawValue)
            .flatMap { try? JSONDecoder().decode(DictationShortcut.self, from: $0) }
            ?? .default

        activationMode = defaults.string(forKey: Key.activationMode.rawValue)
            .flatMap(DictationActivationMode.init(rawValue:)) ?? .pushToTalk

        let storedEngine = defaults.data(forKey: Key.engine.rawValue)
            .flatMap { try? JSONDecoder().decode(EngineSelection.self, from: $0) }
        if let storedEngine, storedEngine.isSupportedOnCurrentOS {
            engine = storedEngine
        } else {
            engine = ModelDescriptor.defaultDictationSelection
        }

        overlayNearCaret = defaults.object(forKey: Key.overlayNearCaret.rawValue) as? Bool ?? true
        soundCuesEnabled = defaults.object(forKey: Key.soundCues.rawValue) as? Bool ?? true
        pasteRestoreDelayMS = defaults.object(forKey: Key.pasteRestoreDelay.rawValue) as? Int ?? 500

        insertionMethod = defaults.string(forKey: Key.insertionMethod.rawValue)
            .flatMap(TextInserter.Method.init(rawValue:)) ?? .paste
    }

    /// The engine choice as a full runner config.
    var runnerConfig: RunnerConfig {
        RunnerConfig(engine: engine)
    }

    private enum Key: String {
        case shortcut = "dictation.shortcut"
        case activationMode = "dictation.activationMode"
        case engine = "dictation.engine"
        case overlayNearCaret = "dictation.overlayNearCaret"
        case soundCues = "dictation.soundCues"
        case pasteRestoreDelay = "dictation.pasteRestoreDelayMS"
        case insertionMethod = "dictation.insertionMethod"
    }

    private func write(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func writeJSON(_ value: some Encodable, _ key: Key) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }
}
