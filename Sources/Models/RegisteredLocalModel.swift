import Foundation

/// A model family Yaip can load from a user-selected folder without copying it.
enum LocalModelEngine: String, Codable, Hashable, Sendable {
    case whisperKit
    case parakeetV3

    var displayName: String {
        switch self {
        case .whisperKit: "WhisperKit Core ML"
        case .parakeetV3: "Parakeet TDT v3 Core ML"
        }
    }

    var languageSupport: LanguageSupport {
        switch self {
        case .whisperKit: .all
        case .parakeetV3: .only(ParakeetModel.v3Languages)
        }
    }
}

/// A durable reference to a folder chosen through NSOpenPanel.
struct FolderBookmark: Codable, Hashable, Sendable {
    var data: Data
    var lastKnownPath: String

    init(url: URL) throws {
        data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: [.fileResourceIdentifierKey],
            relativeTo: nil
        )
        lastKnownPath = url.path
    }

    func resolve() throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }
}

/// Registration metadata only. The model weights remain in the selected folder.
struct RegisteredLocalModel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    let engine: LocalModelEngine
    var modelFolder: FolderBookmark
    var tokenizerFolder: FolderBookmark?
    let addedAt: Date

    var selection: EngineSelection {
        .registeredLocal(id: id, engine: engine, displayName: displayName)
    }
}

/// Keeps security-scoped access alive for as long as a resident runner needs it.
final class SecurityScopedFolder: @unchecked Sendable {
    let url: URL
    private let didStartAccess: Bool

    init(url: URL) {
        self.url = url
        didStartAccess = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if didStartAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

/// A registration resolved to live URLs for runner construction.
struct ResolvedRegisteredModel: @unchecked Sendable {
    let registration: RegisteredLocalModel
    let modelFolder: SecurityScopedFolder
    let tokenizerFolder: SecurityScopedFolder?
}
