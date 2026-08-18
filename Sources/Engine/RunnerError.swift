import Foundation

enum RunnerError: LocalizedError {
    case modelNotPrepared
    case modelDownloadFailed(underlying: String)
    case unsupportedLanguage(code: String, engine: String)
    case audioTooLong(limit: Duration)
    case engineUnavailable(String)
    case engineFailure(String)

    var errorDescription: String? {
        switch self {
        case .modelNotPrepared:
            "The model has not finished loading."
        case .modelDownloadFailed(let underlying):
            // Keep the real cause. A generic "Download failed" is what turns a
            // TLS interception or 403 into an hour of guesswork.
            "Could not download the model: \(underlying)"
        case .unsupportedLanguage(let code, let engine):
            "\(engine) does not support \(Locale.current.localizedString(forLanguageCode: code) ?? code)."
        case .audioTooLong(let limit):
            "This recording is longer than the \(limit.minuteSecondLabel) limit for this engine."
        case .engineUnavailable(let name):
            "\(name) is not available in this build yet."
        case .engineFailure(let detail):
            detail
        }
    }
}
