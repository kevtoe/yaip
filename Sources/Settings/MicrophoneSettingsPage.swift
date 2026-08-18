import AVFoundation
import SwiftUI

/// Shows which microphone dictation will actually use.
struct MicrophoneSettingsPage: View {
    @State private var devices = [AVCaptureDevice]()

    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
            SettingsGroup(
                title: "Input",
                footnote: """
                    Yaip records from the system default input. Change it in System Settings › \
                    Sound, or in the menu bar volume control.
                    """
            ) {
                SettingsRow(title: "Current Input") {
                    Text(AVCaptureDevice.default(for: .audio)?.localizedName ?? "None")
                        .font(YPTypography.supporting)
                        .foregroundStyle(YPPalette.inkMuted)
                }
                Divider().overlay(YPPalette.line)
                SettingsRow(title: "Microphone Access") {
                    Text(accessLabel)
                        .font(YPTypography.supporting)
                        .foregroundStyle(accessTint)
                }
            }

            if devices.isEmpty == false {
                SettingsGroup(title: "Available Inputs") {
                    ForEach(devices, id: \.uniqueID) { device in
                        SettingsRow(title: device.localizedName) {
                            if device.uniqueID == AVCaptureDevice.default(for: .audio)?.uniqueID {
                                Text("Default")
                                    .font(YPTypography.metadata)
                                    .foregroundStyle(YPPalette.accent)
                            }
                        }
                        if device.uniqueID != devices.last?.uniqueID {
                            Divider().overlay(YPPalette.line)
                        }
                    }
                }
            }
        }
        .task { refresh() }
    }

    private var accessLabel: String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:    "Granted"
        case .denied:        "Denied"
        case .restricted:    "Restricted"
        case .notDetermined: "Not requested"
        @unknown default:    "Unknown"
        }
    }

    private var accessTint: Color {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            ? YPPalette.accent
            : YPPalette.warning
    }

    private func refresh() {
        devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }
}
