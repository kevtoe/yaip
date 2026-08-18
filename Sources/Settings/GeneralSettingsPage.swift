import ServiceManagement
import SwiftUI

struct GeneralSettingsPage: View {
    @Bindable var dictation: DictationController
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: YPMetrics.sectionSpacing) {
            SettingsGroup {
                SettingsRow(
                    title: "Launch at Login",
                    detail: "Dictation only works while Yaip is running."
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
                }
            }

        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert the toggle rather than leaving the UI claiming something
            // that did not happen.
            launchAtLogin = !enabled
        }
    }
}

enum AppVersion {
    static var displayString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}
