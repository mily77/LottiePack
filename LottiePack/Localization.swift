import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        case .japanese:
            return "日本語"
        }
    }

    static func resolved(from identifier: String?) -> AppLanguage {
        guard let identifier, !identifier.isEmpty else {
            return preferredLanguage
        }

        if let exact = AppLanguage(rawValue: identifier) {
            return exact
        }

        let normalized = identifier.lowercased()
        if normalized.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if normalized.hasPrefix("ja") {
            return .japanese
        }
        return .english
    }

    private static var preferredLanguage: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let language = resolved(from: identifier)
            if language == .simplifiedChinese || language == .japanese {
                return language
            }
            if identifier.lowercased().hasPrefix("en") {
                return .english
            }
        }

        return .english
    }
}

final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private let languageKey = "appLanguageCode"
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        }
    }

    var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    private init() {
        let storedValue = UserDefaults.standard.string(forKey: languageKey)
        language = AppLanguage.resolved(from: storedValue)
    }
}

enum L10n {
    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        guard !arguments.isEmpty else {
            return format
        }

        return String(format: format, locale: AppPreferences.shared.locale, arguments: arguments)
    }

    private static var bundle: Bundle {
        let language = AppPreferences.shared.language
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
