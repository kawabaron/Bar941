import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case englishUS = "en-US"
    case englishGB = "en-GB"
    case englishAU = "en-AU"
    case englishCA = "en-CA"
    case french = "fr"
    case italian = "it"
    case german = "de"
    case spanishSpain = "es-ES"
    case spanishMexico = "es-MX"
    case portuguesePortugal = "pt-PT"
    case portugueseBrazil = "pt-BR"

    static let storageKey = "selectedAppLanguage"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        default:
            return Locale(identifier: rawValue)
        }
    }
}

enum AppLocalizer {
    static func string(_ key: String, languageCode: String) -> String {
        bundle(for: languageCode).localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, languageCode: String, _ arguments: CVarArg...) -> String {
        let format = string(key, languageCode: languageCode)
        let locale = locale(for: languageCode)

        return withVaList(arguments) {
            NSString(format: format, locale: locale, arguments: $0) as String
        }
    }

    static func locale(for languageCode: String) -> Locale {
        AppLanguage(rawValue: languageCode)?.locale ?? .autoupdatingCurrent
    }

    private static func bundle(for languageCode: String) -> Bundle {
        guard let appLanguage = AppLanguage(rawValue: languageCode), appLanguage != .system else {
            return .main
        }

        let preferences = localizationPreferences(for: appLanguage)
        guard let localization = Bundle.preferredLocalizations(
            from: Bundle.main.localizations,
            forPreferences: preferences
        ).first,
        let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
        let bundle = Bundle(path: path) else {
            return .main
        }

        return bundle
    }

    private static func localizationPreferences(for language: AppLanguage) -> [String] {
        let locale = language.locale
        let languageCode = locale.language.languageCode?.identifier

        return [language.rawValue, languageCode]
            .compactMap { $0 }
    }
}
