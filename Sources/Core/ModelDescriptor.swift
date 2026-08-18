import Foundation

/// One row in the model picker.
///
/// The catalogue is static so the app can start without a network request.
struct ModelDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let approximateBytes: Int64
    let languageSupport: LanguageSupport
    let selection: EngineSelection

    /// True when macOS owns the model and there is nothing to download.
    var isSystemManaged: Bool {
        if case .appleSpeech = selection { true } else { false }
    }

    static var builtIns: [ModelDescriptor] {
        let parakeet = PlatformSupport.supportsParakeet
            ? ParakeetModel.allCases.map { model in
            ModelDescriptor(
                id: model.rawValue,
                displayName: model.displayName,
                approximateBytes: model.approximateBytes,
                languageSupport: model.languageSupport,
                selection: .fluidParakeet(model: model.rawValue)
            )
        }
            : []
        let downloadable = parakeet + WhisperModel.allCases.map { model in
            ModelDescriptor(
                id: model.rawValue,
                displayName: model.displayName,
                approximateBytes: model.approximateBytes,
                languageSupport: model.languageSupport,
                selection: .whisperKit(model: model.rawValue)
            )
        }
        if #available(macOS 26, *) {
            return [appleSpeech] + downloadable
        }
        return downloadable
    }

    static var defaultDictationSelection: EngineSelection {
        if PlatformSupport.supportsAppleSpeech {
            return appleSpeech.selection
        }
        if ModelStorage.hasBundledWhisper(WhisperModel.tiny.rawValue) {
            return .whisperKit(model: WhisperModel.tiny.rawValue)
        }
        if PlatformSupport.supportsParakeet {
            return .fluidParakeet(model: ParakeetModel.v3.rawValue)
        }
        return .whisperKit(model: WhisperModel.tiny.rawValue)
    }

    /// The zero-download default, so a fresh install can dictate immediately
    /// rather than waiting on a half-gigabyte fetch.
    static let appleSpeech = ModelDescriptor(
        id: "apple-speech",
        displayName: "Apple Speech",
        approximateBytes: 0,
        languageSupport: .all,
        selection: .appleSpeech(localeIdentifier: Locale.current.identifier)
    )

    static func registered(_ model: RegisteredLocalModel) -> ModelDescriptor {
        ModelDescriptor(
            id: "registered-\(model.id.uuidString)",
            displayName: model.displayName,
            approximateBytes: 0,
            languageSupport: model.engine.languageSupport,
            selection: model.selection
        )
    }

    var registeredID: UUID? {
        guard case .registeredLocal(let id, _, _) = selection else { return nil }
        return id
    }

    var isRegistered: Bool { registeredID != nil }

    var formattedSize: String {
        if isSystemManaged { return "Built in" }
        if isRegistered { return "Used in place" }
        return approximateBytes.formatted(.byteCount(style: .file))
    }

    /// Shown next to the model name so the Vietnamese-style gap is visible
    /// before the user picks, not after the transcript comes back wrong.
    var languageSummary: String {
        switch languageSupport {
        case .all:            "All languages"
        case .only(let set):  "\(set.count) languages"
        }
    }
}
