import Foundation
import OSLog

/// Owns runner instances and hands out prepared ones.
///
/// Only one runner stays resident: models are large, and holding two Whisper
/// Large variants in memory is how you get a 6 GB resident set.
actor RunnerRegistry {
    static let shared = RunnerRegistry()

    typealias RunnerFactory = @Sendable (EngineSelection) async throws -> any TranscriptionRunner

    private let log = Logger(subsystem: "app.yaip.v1", category: "RunnerRegistry")
    private let router = LanguageRouter()
    private let runnerFactory: RunnerFactory?

    private var resident: (selection: EngineSelection, runner: any TranscriptionRunner)?
    private var preparation: (
        selection: EngineSelection,
        task: Task<any TranscriptionRunner, Error>
    )?

    init(runnerFactory: RunnerFactory? = nil) {
        self.runnerFactory = runnerFactory
    }

    var residentEngineIdentifier: String? {
        resident?.selection.engineIdentifier
    }

    /// Resolve a config to a prepared runner, applying language routing.
    ///
    /// `onSubstitution` fires when the router overrode the requested engine so
    /// the caller can surface it. The substitution is never silent.
    func prepared(
        for config: RunnerConfig,
        detectedLanguage: String? = nil,
        onSubstitution: @Sendable (String) -> Void = { _ in },
        onLoadProgress: @Sendable @escaping (Double) -> Void = { _ in }
    ) async throws -> (runner: any TranscriptionRunner, selection: EngineSelection) {

        let decision = router.route(config: config, detectedLanguage: detectedLanguage)

        if let reason = decision.substitutionReason {
            log.notice("Engine substituted: \(reason, privacy: .public)")
            onSubstitution(reason)
        }

        let runner = try await runner(for: decision.selection, onLoadProgress: onLoadProgress)
        return (runner, decision.selection)
    }

    /// Free model memory. Called on idle timeout.
    func evictAll() async {
        preparation?.task.cancel()
        preparation = nil
        await resident?.runner.teardown()
        resident = nil
    }

    func evict(selectionID: UUID) async {
        if let preparation,
           case .registeredLocal(let id, _, _) = preparation.selection,
           id == selectionID {
            preparation.task.cancel()
            self.preparation = nil
        }
        guard let resident,
              case .registeredLocal(let id, _, _) = resident.selection,
              id == selectionID else { return }
        await resident.runner.teardown()
        self.resident = nil
    }

    // MARK: Private

    private func runner(
        for selection: EngineSelection,
        onLoadProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> any TranscriptionRunner {
        if let resident, resident.selection == selection {
            return resident.runner
        }

        if let preparation {
            if preparation.selection == selection {
                return try await complete(preparation)
            }

            // The one-resident invariant also applies while loading. Let the
            // current preparation finish before replacing it, rather than
            // briefly holding two large Core ML graphs at once.
            _ = try? await complete(preparation)
        }

        if let existing = resident {
            log.info("Evicting \(existing.selection.engineIdentifier, privacy: .public)")
            await existing.runner.teardown()
            resident = nil
        }

        let task = Task<any TranscriptionRunner, Error> {
            let created: any TranscriptionRunner
            if let runnerFactory {
                created = try await runnerFactory(selection)
            } else {
                created = try await make(selection)
            }
            try await created.prepare(onProgress: onLoadProgress)
            return created
        }
        let pending = (selection: selection, task: task)
        preparation = pending
        return try await complete(pending)
    }

    private func complete(
        _ pending: (selection: EngineSelection, task: Task<any TranscriptionRunner, Error>)
    ) async throws -> any TranscriptionRunner {
        do {
            let runner = try await pending.task.value
            if preparation?.selection == pending.selection {
                resident = (pending.selection, runner)
                preparation = nil
            }
            return runner
        } catch {
            if preparation?.selection == pending.selection {
                preparation = nil
            }
            throw error
        }
    }

    private var localModelResolver: (@Sendable (UUID) async -> ResolvedRegisteredModel?)?

    func setLocalModelResolver(
        _ resolver: @escaping @Sendable (UUID) async -> ResolvedRegisteredModel?
    ) {
        localModelResolver = resolver
    }

    nonisolated func setLocalModelResolverFromMainActor(
        _ resolver: @escaping @MainActor @Sendable (UUID) async -> ResolvedRegisteredModel?
    ) {
        Task {
            await setLocalModelResolver { id in await resolver(id) }
        }
    }

    private func make(_ selection: EngineSelection) async throws -> any TranscriptionRunner {
        switch selection {
        case .whisperKit(let model):
            return WhisperKitRunner(model: model)

        case .fluidParakeet(let model):
            guard PlatformSupport.supportsParakeet else {
                throw RunnerError.engineUnavailable("Parakeet (needs Apple Silicon)")
            }
            return FluidParakeetRunner(model: model)

        case .appleSpeech(let localeIdentifier):
            guard #available(macOS 26, *) else {
                throw RunnerError.engineUnavailable("Apple Speech (needs macOS 26)")
            }
            return AppleSpeechRunner(localeIdentifier: localeIdentifier)

        case .registeredLocal(let id, let engine, _):
            guard let resolved = await localModelResolver?(id) else {
                throw RunnerError.engineFailure(
                    "That local model folder is unavailable. Locate it again under Local Models."
                )
            }
            switch engine {
            case .whisperKit:
                return WhisperKitRunner(registered: resolved)
            case .parakeetV3:
                return FluidParakeetRunner(registered: resolved)
            }
        }
    }
}
