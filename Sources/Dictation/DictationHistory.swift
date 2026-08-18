import Foundation
import Observation
import OSLog

/// Everything dictated, newest first, surviving relaunch.
///
/// Deliberately a plain JSON file rather than the GRDB schema in the spec: the
/// value here is not losing words, and that should not wait on the persistence
/// layer landing. Migrating this into `dictationEvent` later is a small job.
@MainActor
@Observable
final class DictationHistory {
    private let log = Logger(subsystem: "app.yaip.v1", category: "History")

    private(set) var records = [DictationRecord]()
    private let persistsChanges: Bool

    /// Keeps the file bounded. Dictation is high frequency and the tail has
    /// little value once the text has been used.
    private static let limit = 500

    private static var fileURL: URL {
        let directory = URL.applicationSupportDirectory.appending(path: "Yaip")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "dictation-history.json")
    }

    init(records: [DictationRecord] = [], persistsChanges: Bool = true) {
        self.records = records
        self.persistsChanges = persistsChanges
        if persistsChanges { load() }
    }

    func add(_ record: DictationRecord) {
        records.insert(record, at: 0)
        if records.count > Self.limit {
            records.removeLast(records.count - Self.limit)
        }
        save()
    }

    func remove(_ record: DictationRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    func matching(_ query: String) -> [DictationRecord] {
        guard query.isEmpty == false else { return records }
        return records.filter {
            $0.text.localizedStandardContains(query)
                || ($0.targetAppName?.localizedStandardContains(query) ?? false)
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        do {
            records = try JSONDecoder().decode([DictationRecord].self, from: data)
        } catch {
            // A corrupt file must not take the app down or wipe itself
            // silently; leave it on disk so it can be inspected.
            log.error("Could not read history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        guard persistsChanges else { return }
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            log.error("Could not write history: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func screenshotDemo() -> DictationHistory {
        let now = Date()
        return DictationHistory(
            records: [
                DictationRecord(
                    date: now.addingTimeInterval(-240),
                    text: "Turn the rough notes into three clear actions, then send the summary before lunch.",
                    targetAppName: "Notes",
                    targetBundleID: "com.apple.Notes",
                    delivery: .inserted,
                    engineIdentifier: "whisperkit",
                    modelIdentifier: WhisperModel.tiny.rawValue,
                    spokenSeconds: 6.8
                ),
                DictationRecord(
                    date: now.addingTimeInterval(-780),
                    text: "Thanks for the update. Thursday afternoon works well for me.",
                    targetAppName: "Mail",
                    targetBundleID: "com.apple.mail",
                    delivery: .pasted,
                    engineIdentifier: "apple-speech",
                    modelIdentifier: "en-AU",
                    spokenSeconds: 4.4
                ),
                DictationRecord(
                    date: now.addingTimeInterval(-1_440),
                    text: "Search for a quiet keyboard that does not sound like a tiny construction site.",
                    targetAppName: "Safari",
                    targetBundleID: "com.apple.Safari",
                    delivery: .inserted,
                    engineIdentifier: "fluid-parakeet",
                    modelIdentifier: ParakeetModel.allCases[0].rawValue,
                    spokenSeconds: 5.9
                ),
            ],
            persistsChanges: false
        )
    }
}
