import Foundation

/// Looks up interface strings in the String Catalog for the in-app language.
/// Commentary text never goes through this type.
enum L10n {
    private static var cache: [String: Bundle] = [:]

    static func text(_ key: String, _ language: AppLanguage) -> String {
        let bundle = localizationBundle(for: language)
        let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if value != key {
            return value
        }
        // `value: nil` returns the key when the catalog has not been compiled
        // into this bundle. Try the main bundle's development language next.
        let fallback = Bundle.main.localizedString(forKey: key, value: nil, table: "Localizable")
        return fallback
    }

    private static func localizationBundle(for language: AppLanguage) -> Bundle {
        if let cached = cache[language.rawValue] {
            return cached
        }
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            cache[language.rawValue] = bundle
            return bundle
        }
        return .main
    }
}
