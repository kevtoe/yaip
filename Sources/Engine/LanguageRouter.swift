import Foundation

/// Picks the engine that can actually handle the language in play.
///
/// If an engine cannot handle the selected language, Yaip routes around it and
/// reports the substitution rather than hiding it.
struct LanguageRouter: Sendable {

    /// Fallbacks in preference order. Whisper covers 99 languages, so it is the
    /// universal backstop and must stay last.
    private let fallbackOrder: [EngineSelection] = [
        .whisperKit(model: WhisperModel.tiny.rawValue),
        .whisperKit(model: WhisperModel.largeV3Turbo.rawValue),
        .whisperKit(model: WhisperModel.small.rawValue),
    ]

    func route(config: RunnerConfig, detectedLanguage: String?) -> EngineRoutingDecision {
        guard let code = config.language.explicitCode ?? detectedLanguage else {
            // Nothing known yet. Honour the user's choice; detection runs first
            // and calls back with a code.
            return EngineRoutingDecision(selection: config.engine)
        }

        guard !supports(config.engine, code) else {
            return EngineRoutingDecision(selection: config.engine)
        }

        guard let replacement = fallbackOrder.first(where: { supports($0, code) }) else {
            // Unreachable while Whisper is in the fallback list.
            return EngineRoutingDecision(selection: config.engine)
        }

        let language = Locale.current.localizedString(forLanguageCode: code) ?? code
        return EngineRoutingDecision(
            selection: replacement,
            substitutionReason: """
                \(language): using \(replacement.displayName) because \
                \(config.engine.displayName) does not support this language.
                """
        )
    }

    private func supports(_ selection: EngineSelection, _ code: String) -> Bool {
        switch selection {
        case .whisperKit:
            WhisperModel.largeV3Turbo.languageSupport.supports(code)
        case .fluidParakeet(let model):
            ParakeetModel(rawValue: model)?.languageSupport.supports(code) ?? false
        case .appleSpeech(let localeIdentifier):
            localeIdentifier.hasPrefix(String(code.prefix(2)))
        case .registeredLocal(_, let engine, _):
            engine.languageSupport.supports(code)
        }
    }
}
