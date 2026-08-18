import AVFoundation
import SwiftUI

/// Explains each macOS permission before asking for it.
struct FirstRunSetupView: View {
    let dictation: DictationController
    let onComplete: () -> Void

    @State private var microphoneGranted = MicrophoneRecorder.hasMicrophoneAccess
    @State private var accessibilityGranted = InputPermissions.hasAccessibility
    @State private var inputMonitoringGranted = InputPermissions.hasInputMonitoring
    @State private var isRequestingMicrophone = false

    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: YPMetrics.compactSpacing) {
                Text("Set Up Yaip")
                    .font(YPTypography.windowTitle)
                    .foregroundStyle(YPPalette.ink)
                Text("Yaip includes an offline model. Allow these three macOS permissions to dictate into any app.")
                    .font(YPTypography.body)
                    .foregroundStyle(YPPalette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                PermissionStep(
                    title: "Microphone",
                    detail: "Records only while you hold or toggle the dictation shortcut.",
                    symbol: "mic",
                    isGranted: microphoneGranted,
                    actionTitle: microphoneGranted ? "Granted" : "Allow"
                ) {
                    if MicrophoneRecorder.authorizationStatus == .denied {
                        MicrophoneRecorder.openMicrophoneSettings()
                    } else {
                        isRequestingMicrophone = true
                        Task {
                            microphoneGranted = await MicrophoneRecorder.requestAccess()
                            isRequestingMicrophone = false
                        }
                    }
                }
                Divider().overlay(YPPalette.line)
                PermissionStep(
                    title: "Accessibility",
                    detail: "Returns focus and inserts the finished text into the target app.",
                    symbol: "accessibility",
                    isGranted: accessibilityGranted,
                    actionTitle: accessibilityGranted ? "Granted" : "Open Settings"
                ) {
                    if InputPermissions.hasAccessibility {
                        accessibilityGranted = true
                    } else {
                        InputPermissions.requestAccessibility()
                        InputPermissions.openAccessibilitySettings()
                    }
                }
                Divider().overlay(YPPalette.line)
                PermissionStep(
                    title: "Input Monitoring",
                    detail: "Detects your chosen dictation shortcut while another app is active.",
                    symbol: "keyboard",
                    isGranted: inputMonitoringGranted,
                    actionTitle: inputMonitoringGranted ? "Granted" : "Open Settings"
                ) {
                    if InputPermissions.hasInputMonitoring {
                        inputMonitoringGranted = true
                    } else {
                        InputPermissions.requestInputMonitoring()
                        InputPermissions.openInputMonitoringSettings()
                    }
                }
            }
            .background(YPPalette.surface, in: .rect(cornerRadius: YPMetrics.selectedRowRadius))

            HStack {
                Label("Offline model included", systemImage: "checkmark.seal.fill")
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.accent)
                Spacer()
                Button("Check Again") { refresh() }
                Button("Finish Setup") {
                    FirstRunState.hasCompletedSetup = true
                    Task { await dictation.requestPermissionsAndEnable() }
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .disabled(allGranted == false || isRequestingMicrophone)
            }
        }
        .padding(32)
        .frame(width: 620)
        .onAppear(perform: refresh)
        .task {
            while Task.isCancelled == false && allGranted == false {
                try? await Task.sleep(for: .seconds(1))
                refresh()
            }
        }
    }

    private var allGranted: Bool {
        microphoneGranted && accessibilityGranted && inputMonitoringGranted
    }

    private func refresh() {
        microphoneGranted = MicrophoneRecorder.hasMicrophoneAccess
        accessibilityGranted = InputPermissions.hasAccessibility
        inputMonitoringGranted = InputPermissions.hasInputMonitoring
    }
}

private struct PermissionStep: View {
    let title: String
    let detail: String
    let symbol: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: YPMetrics.standardSpacing) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(isGranted ? YPPalette.accent : YPPalette.inkMuted)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(YPTypography.controlLabel)
                    .foregroundStyle(YPPalette.ink)
                Text(detail)
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.inkMuted)
            }
            Spacer(minLength: YPMetrics.standardSpacing)
            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(YPTypography.supporting)
                    .foregroundStyle(YPPalette.accent)
            } else {
                Button(actionTitle, action: action)
            }
        }
        .padding(YPMetrics.standardSpacing)
    }
}
