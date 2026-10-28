import Foundation

/// A service-layer message that exists in both interface languages.
/// Services own the wording; the app resolves exactly one form for display
/// from the user's language choice, so no user ever sees both languages
/// concatenated in one string.
struct ServiceText {
    let arabic: String
    let english: String

    init(_ arabic: String, _ english: String) {
        self.arabic = arabic
        self.english = english
    }

    func resolved(arabicUI: Bool) -> String { arabicUI ? arabic : english }

    static func containsArabicLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { ($0.value >= 0x0621 && $0.value <= 0x064A) || $0.value == 0x0640 }
    }

    /// Maps common network failures to stable, app-localized wording instead
    /// of the OS-localized description, which follows the system locale
    /// rather than the app's language choice.
    static func network(_ error: Error) -> ServiceText {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet: return ServiceText("لا يوجد اتصال بالإنترنت", "No internet connection")
            case .timedOut: return ServiceText("انتهت مهلة الاتصال", "The connection timed out")
            case .cannotFindHost, .cannotConnectToHost: return ServiceText("تعذّر الوصول إلى الخدمة", "The service is unreachable")
            case .badURL: return ServiceText("رابط غير صالح", "Invalid URL")
            default: break
            }
        }
        let ns = error as NSError
        return ServiceText(ns.localizedDescription, ns.localizedDescription)
    }
}
