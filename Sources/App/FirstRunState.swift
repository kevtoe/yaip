import Foundation

enum FirstRunState {
    private static let key = "onboarding.completed.v1"

    static var hasCompletedSetup: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var shouldPresentSetup: Bool {
        CommandLine.arguments.contains("--preview-onboarding") || hasCompletedSetup == false
    }
}
