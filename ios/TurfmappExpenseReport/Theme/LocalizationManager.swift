import Foundation
import SwiftUI

/// Two-language store backed by `.lproj/Localizable.strings`. Bundle is
/// swapped at runtime so the in-app picker can switch English ⇄ ไทย without
/// requiring an app restart. All user-facing strings flow through `tr(_:)`.
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case thai = "th"
        var id: String { rawValue }

        /// Native-name display label for the picker (English uses Latin, Thai
        /// uses Thai script — easier to find for native speakers).
        var displayName: String {
            switch self {
            case .english: return "English"
            case .thai: return "ไทย"
            }
        }
    }

    @Published private(set) var language: Language

    private static let defaultsKey = "app.language"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        if let stored, let language = Language(rawValue: stored) {
            self.language = language
        } else if Locale.current.language.languageCode?.identifier == "th" {
            // Match device language if a Thai-locale device is installing fresh.
            self.language = .thai
        } else {
            self.language = .english
        }
    }

    func setLanguage(_ language: Language) {
        guard language != self.language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
    }

    /// Returns the language-specific Bundle from `<lang>.lproj`. Falls back
    /// to `.main` if the lproj isn't shipped (defensive — should never happen
    /// in a properly-built app).
    fileprivate var localizationBundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

/// Translate `key` into the user's currently selected language. Returns the
/// key unchanged if no translation is registered — that way new strings show
/// up legibly in English while we're filling in Thai (or vice versa).
@MainActor
func tr(_ key: String, _ arguments: CVarArg...) -> String {
    let bundle = LocalizationManager.shared.localizationBundle
    let template = bundle.localizedString(forKey: key, value: key, table: nil)
    if arguments.isEmpty { return template }
    return String(format: template, arguments: arguments)
}

/// Convenience SwiftUI text view that re-renders whenever the language
/// preference changes (subscribes to the shared manager).
struct TText: View {
    @ObservedObject private var manager = LocalizationManager.shared
    let key: String
    let arguments: [CVarArg]

    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }

    var body: some View {
        Text(arguments.isEmpty
             ? tr(key)
             : String(format: manager.localizationBundle.localizedString(forKey: key, value: key, table: nil),
                      arguments: arguments))
    }
}
