import AppKit
import Foundation
import Observation
import OSLog

/// Hold the key, speak, release, text appears wherever you were typing.
///
/// This is the whole point of the app. The workbench shares its engine layer,
/// but this is the loop that runs all day.
@MainActor
@Observable
final class DictationController {
    private let log = Logger(subsystem: "app.yaip.v1", category: "Dictation")

    private let hotkeyMonitor = HotkeyMonitor()
    private let recorder = MicrophoneRecorder()

    /// Every dictation is recorded here, so nothing said is unrecoverable when
    /// an app refuses the paste.
    let history: DictationHistory
    /// Settings that survive relaunch.
    let preferences: DictationPreferences
    private let presentationMode: Bool

    init(
        history: DictationHistory = DictationHistory(),
        preferences: DictationPreferences = DictationPreferences(),
        presentationMode: Bool = false
    ) {
        self.history = history
        self.preferences = preferences
        self.presentationMode = presentationMode
    }

    /// Fired on every phase change.
    ///
    /// A plain callback rather than `withObservationTracking`: that API fires
    /// once and must re-register itself, and any change landing in the gap is
    /// lost. Dictation moves idle → listening → transcribing → delivered in
    /// well under a second, so those gaps swallowed the overlay entirely.
    @ObservationIgnored var onPhaseChange: ((DictationPhase) -> Void)?

    private(set) var phase: DictationPhase = .idle {
        didSet {
            guard phase != oldValue else { return }
            onPhaseChange?(phase)
        }
    }
    /// Recent microphone levels, newest last, for the scrolling waveform.
    private(set) var levels = [Float](repeating: 0, count: DictationController.levelHistoryCount)
    private(set) var elapsed: Duration = .zero
    var permissionProblem: DictationError? {
        if presentationMode { return nil }
        if MicrophoneRecorder.hasMicrophoneAccess == false { return .microphoneDenied }
        if InputPermissions.hasAccessibility == false { return .accessibilityDenied }
        if InputPermissions.hasInputMonitoring == false { return .inputMonitoringDenied }
        return storedPermissionProblem
    }
    private var storedPermissionProblem: DictationError?

    /// How many bars the overlay shows. At the 50 ms tick below this is about
    /// 1.6 seconds of history, which is enough to see a sentence's shape.
    static let levelHistoryCount = 32

    /// Reads through to persisted preferences, so a change made in Settings or
    /// the menu bar is still in effect after a relaunch.
    var config: RunnerConfig {
        get { preferences.runnerConfig }
        set { preferences.engine = newValue.engine }
    }

    var shortcut: DictationShortcut {
        get { preferences.shortcut }
        set {
            guard newValue != preferences.shortcut else { return }
            preferences.shortcut = newValue
            // Rebind immediately: a shortcut change that only takes effect
            // next launch reads as the setting being broken.
            enable()
        }
    }

    /// Suspends the global tap while the user records a new shortcut, so the
    /// keys being recorded do not also start a dictation.
    func setRecording(_ isRecording: Bool) {
        hotkeyMonitor.setSuspended(isRecording)
    }

    var activationMode: DictationActivationMode {
        get { preferences.activationMode }
        set { preferences.activationMode = newValue }
    }

    /// Where the text is going. Captured on key-down, because showing the
    /// overlay can change what is frontmost.
    private var targetApp: NSRunningApplication?
    private var startedAt: ContinuousClock.Instant?
    private var tickTask: Task<Void, Never>?
    private var dictationTask: Task<Void, Never>?

    var isEnabled: Bool { presentationMode || hotkeyMonitor.isRunning }

    // MARK: Lifecycle

    /// Asks for everything dictation needs, in the order the prompts make
    /// sense, then arms the hotkey.
    ///
    /// Launching the app is the explicit user action that justifies prompting.
    /// Without this the hotkey simply never fires and there is nothing on
    /// screen explaining why, which is the single worst first-run experience
    /// this kind of app can have.
    func requestPermissionsAndEnable() async {
        if await MicrophoneRecorder.requestAccess() == false {
            storedPermissionProblem = .microphoneDenied
            log.error("Microphone access denied")
        }

        if InputPermissions.hasAccessibility == false {
            // Shows the system dialog with its "Open System Settings" button.
            InputPermissions.requestAccessibility()
        }

        // Creating the event tap is itself what triggers the Input Monitoring
        // prompt, so there is nothing separate to request first.
        enable()
    }

    func enable() {
        do {
            try hotkeyMonitor.start(shortcut: preferences.shortcut)
            hotkeyMonitor.onPress = { [weak self] in self?.handleKeyDown() }
            hotkeyMonitor.onRelease = { [weak self] in self?.handleKeyUp() }
            storedPermissionProblem = nil
            log.notice("Dictation armed on \(self.preferences.shortcut.displayString, privacy: .public)")
        } catch let error as DictationError {
            storedPermissionProblem = error
            log.error("Cannot enable: \(error.localizedDescription, privacy: .public)")
        } catch {
            storedPermissionProblem = .recordingFailed(error.localizedDescription)
        }
    }

    func disable() {
        hotkeyMonitor.stop()
        cancelInFlight()
    }

    /// Warms the model so the first dictation of the session is not the slow
    /// one. Safe to call repeatedly.
    func preloadModel() async {
        _ = try? await RunnerRegistry.shared.prepared(for: config)
    }

    #if DEBUG
    /// Deterministic visual-QA state. Never compiled into the installed release.
    func previewListeningOverlay() {
        elapsed = .seconds(12)
        levels = (0..<Self.levelHistoryCount).map { index in
            let position = Float(index) / Float(Self.levelHistoryCount - 1)
            return 0.12 + 0.72 * abs(sin(position * .pi * 3))
        }
        phase = .listening
    }
    #endif

    // MARK: The loop

    /// Push to talk records while held. Toggle starts on the first tap and
    /// stops on the next, so the key-up in between must be ignored.
    private func handleKeyDown() {
        switch preferences.activationMode {
        case .pushToTalk:
            beginListening()
        case .toggle:
            if phase == .listening {
                finishListening()
            } else {
                beginListening()
            }
        }
    }

    private func handleKeyUp() {
        guard preferences.activationMode == .pushToTalk else { return }
        finishListening()
    }

    private func beginListening() {
        guard phase == .idle || phase.isActive == false else { return }

        targetApp = NSWorkspace.shared.frontmostApplication
        do {
            try recorder.start()
        } catch {
            // `show` plays the failure cue, so do not double it here.
            show(.failed(error.localizedDescription))
            return
        }

        startedAt = .now
        elapsed = .zero
        phase = .listening
        // Confirms the key registered and the mic is live, without needing to
        // look away from what you are writing.
        DictationSounds.start()
        startTicking()
    }

    private func finishListening() {
        guard phase == .listening else { return }

        stopTicking()
        let audio = recorder.stop()
        DictationSounds.stop()
        phase = .transcribing

        dictationTask = Task { [weak self] in
            await self?.transcribeAndInsert(audio)
        }
    }

    private func transcribeAndInsert(_ audio: AudioBuffer) async {
        // Under about a third of a second is a key-tap, not speech.
        guard audio.duration > .milliseconds(300) else {
            show(.failed(DictationError.nothingHeard.localizedDescription))
            return
        }

        do {
            let (runner, _) = try await RunnerRegistry.shared.prepared(for: config)
            let result = try await runner.transcribe(
                audio,
                options: TranscriptionOptions(from: config),
                onProgress: { _ in }
            )

            let text = result.text
            guard text.isEmpty == false else {
                show(.failed(DictationError.nothingHeard.localizedDescription))
                return
            }

            await restoreFocusToTarget()
            let outcome = await TextInserter.insert(
                text,
                targetPID: targetApp?.processIdentifier
            )
            record(text, outcome: outcome, result: result, spoken: audio.duration)
            show(.delivered(text: text, outcome: describe(outcome)))
            log.notice("Dictated \(text.count) characters into \(self.targetApp?.localizedName ?? "unknown", privacy: .public)")

        } catch is CancellationError {
            phase = .idle
        } catch {
            show(.failed(error.localizedDescription))
        }
    }

    /// Makes sure the app that was frontmost when recording started is
    /// frontmost again before pasting.
    ///
    /// The overlay is a non-activating panel so focus should never have moved,
    /// and in that case this does nothing. When focus HAS moved, `activate()`
    /// is asynchronous: pasting straight after it races the activation and the
    /// text lands in the wrong app or nowhere at all. So activate, then wait
    /// for it to actually take, with a short ceiling so a stubborn app cannot
    /// hang the dictation.
    private func restoreFocusToTarget() async {
        guard let targetApp, targetApp.isActive == false else { return }

        targetApp.activate()

        let deadline = ContinuousClock.now + .milliseconds(400)
        while ContinuousClock.now < deadline {
            if targetApp.isActive { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
        log.notice("\(targetApp.localizedName ?? "target", privacy: .public) did not come forward in time")
    }

    private func record(
        _ text: String,
        outcome: TextInserter.Outcome,
        result: TranscriptionResult,
        spoken: Duration
    ) {
        let delivery: DictationRecord.Delivery
        var failureReason: String?

        switch outcome {
        case .inserted:              delivery = .inserted
        case .pasted:                delivery = .pasted
        case .copiedOnly(let reason):
            delivery = .copiedOnly
            failureReason = reason
        }

        history.add(
            DictationRecord(
                text: text,
                targetAppName: targetApp?.localizedName,
                targetBundleID: targetApp?.bundleIdentifier,
                delivery: delivery,
                failureReason: failureReason,
                engineIdentifier: result.engineIdentifier,
                modelIdentifier: result.modelIdentifier,
                spokenSeconds: spoken.seconds
            )
        )
    }

    private func describe(_ outcome: TextInserter.Outcome) -> String {
        switch outcome {
        case .inserted, .pasted:
            "Inserted into \(targetApp?.localizedName ?? "the active app")"
        case .copiedOnly(let reason):
            "Copied to the clipboard because \(reason)"
        }
    }

    // MARK: Overlay state

    private func startTicking() {
        levels = [Float](repeating: 0, count: Self.levelHistoryCount)
        tickTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, let startedAt else { return }
                // Scroll left by one and append the newest reading.
                levels.removeFirst()
                levels.append(recorder.level)
                elapsed = .now - startedAt
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
        levels = [Float](repeating: 0, count: Self.levelHistoryCount)
    }

    /// Shows a terminal state briefly, then clears the overlay.
    /// Failures get an audible cue, because they are the ones you must notice.
    private func show(_ terminal: DictationPhase) {
        if case .failed = terminal { DictationSounds.failure() }
        phase = terminal
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            guard let self, phase == terminal else { return }
            phase = .idle
        }
    }

    private func cancelInFlight() {
        dictationTask?.cancel()
        dictationTask = nil
        stopTicking()
        recorder.stop()
        phase = .idle
    }
}
