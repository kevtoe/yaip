import Foundation

/// The outcome of language routing.
struct EngineRoutingDecision: Sendable, Equatable {
    var selection: EngineSelection
    /// Non-nil when the router overrode the user's engine. Surfaced in the
    /// activity strip so a substitution is never silent.
    var substitutionReason: String?
}
