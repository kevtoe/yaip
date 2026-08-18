import CoreText
import Foundation

enum BundledFontRegistrar {
    @discardableResult
    static func registerUrbanist() -> Bool {
        guard let fontURL = Bundle.main.url(
            forResource: "Urbanist[wght]",
            withExtension: "ttf"
        ) else {
            return false
        }

        var registrationError: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(
            fontURL as CFURL,
            .process,
            &registrationError
        )

        if registered {
            return true
        }

        guard let error = registrationError?.takeRetainedValue() else {
            return false
        }

        return CFErrorGetCode(error) == CTFontManagerError.alreadyRegistered.rawValue
    }
}
