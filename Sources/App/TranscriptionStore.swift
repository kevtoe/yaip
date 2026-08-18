import Foundation
import Observation
import OSLog

/// Drives the workbench: holds jobs, runs transcriptions, reports activity.
@MainActor
@Observable
final class TranscriptionStore {
    private let log = Logger(subsystem: "app.yaip.v1", category: "Store")

    var jobs = [TranscriptionJob]()
    var selectedJobID: TranscriptionJob.ID?
    var searchText = ""
    var config: RunnerConfig = .defaultBatch

    /// The single line in the activity strip. Engine substitutions surface
    /// here, so a routing decision is never silent.
    private(set) var activityMessage = "Idle"

    var selectedJob: TranscriptionJob? {
        jobs.first { $0.id == selectedJobID }
    }

    var filteredJobs: [TranscriptionJob] {
        guard searchText.isEmpty == false else { return jobs }
        return jobs.filter { $0.matches(searchText) }
    }

    /// Toolbar readout, e.g. "Parakeet TDT v3 · Local".
    var engineLabel: String {
        "\(config.engine.displayName) · Local"
    }

    // MARK: Actions

    func add(urls: [URL]) {
        let added = urls.map(TranscriptionJob.init(sourceURL:))
        jobs.insert(contentsOf: added, at: 0)
        selectedJobID = selectedJobID ?? added.first?.id

        for job in added {
            Task { await transcribe(job) }
        }
    }

    func retranscribe(_ job: TranscriptionJob) {
        job.result = nil
        job.state = .queued
        Task { await transcribe(job) }
    }

    func remove(_ job: TranscriptionJob) {
        jobs.removeAll { $0.id == job.id }
        if selectedJobID == job.id {
            selectedJobID = jobs.first?.id
        }
    }

    func transcribe(_ job: TranscriptionJob) async {
        do {
            activityMessage = "Reading \(job.sourceURL.lastPathComponent)…"
            let audio = try await AudioLoader.load(url: job.sourceURL)
            job.duration = audio.duration

            job.state = .loadingModel(fraction: 0)
            activityMessage = "Loading \(config.engine.displayName)…"

            let (runner, selection) = try await RunnerRegistry.shared.prepared(
                for: config,
                onSubstitution: { [weak self] reason in
                    Task { @MainActor in self?.activityMessage = reason }
                },
                onLoadProgress: { fraction in
                    Task { @MainActor in job.state = .loadingModel(fraction: fraction) }
                }
            )

            job.state = .transcribing(fraction: nil, partial: nil)
            activityMessage = "Transcribing \(job.title)…"

            let result = try await runner.transcribe(
                audio,
                options: TranscriptionOptions(from: config)
            ) { progress in
                Task { @MainActor in
                    job.state = .transcribing(
                        fraction: progress.fraction, partial: progress.partialText
                    )
                }
            }

            job.result = result
            job.state = .finished
            activityMessage = completionMessage(for: job, result: result, using: selection)
            log.info("Finished \(job.title, privacy: .public)")

        } catch is CancellationError {
            job.state = .failed("Cancelled")
            activityMessage = "Cancelled"
        } catch {
            job.state = .failed(error.localizedDescription)
            activityMessage = error.localizedDescription
            log.error("Failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Private

    private func completionMessage(
        for job: TranscriptionJob,
        result: TranscriptionResult,
        using selection: EngineSelection
    ) -> String {
        let elapsed = max(result.elapsed.seconds, 0.001)
        let speed = (job.duration?.seconds ?? 0) / elapsed
        let rate = speed.formatted(.number.precision(.fractionLength(0)))
        return "\(job.title) · \(rate)x real time · \(selection.displayName)"
    }
}
