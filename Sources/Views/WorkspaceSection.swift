import Foundation

/// Sidebar destinations.
///
/// Kept deliberately short so every destination is useful.
enum WorkspaceSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case dictations
    case transcripts

    var id: Self { self }

    var label: String {
        switch self {
        case .home:        "Home"
        case .dictations:  "Dictations"
        case .transcripts: "Transcriptions"
        }
    }

    var symbol: String {
        switch self {
        case .home:        "house"
        case .dictations:  "mic"
        case .transcripts: "text.alignleft"
        }
    }

    /// Sidebar grouping for saved output.
    var group: String? {
        switch self {
        case .home:                    nil
        case .dictations, .transcripts: "History"
        }
    }
}
