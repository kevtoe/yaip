import Foundation

/// One word with its timing, where the engine reports word-level detail.
struct Word: Hashable, Sendable, Codable {
    var text: String
    var startMS: Int
    var endMS: Int
    var confidence: Double?
}
