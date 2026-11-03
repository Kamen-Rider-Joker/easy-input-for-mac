public enum ShiftTypeLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    public var id: String { rawValue }
}

public enum ShiftTypeLanguage: Equatable {
    case english
    case simplifiedChinese
}

public enum ShiftTypeLanguageResolver {
    public static func resolve(
        preference: ShiftTypeLanguagePreference,
        preferredLanguages: [String]
    ) -> ShiftTypeLanguage {
        switch preference {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .system:
            let systemLanguage = preferredLanguages.first?.lowercased() ?? "en"
            return systemLanguage.hasPrefix("zh") ? .simplifiedChinese : .english
        }
    }
}
