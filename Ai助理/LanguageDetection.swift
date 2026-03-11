import Foundation
import NaturalLanguage

enum SupportedLanguage: String {
    case zh
    case id
    case en

    var localeIdentifier: String {
        switch self {
        case .zh: return "zh-CN"
        case .id: return "id-ID"
        case .en: return "en-US"
        }
    }
}

struct LanguageDetector {
    static func detect(from text: String) -> SupportedLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if containsChinese(trimmed) { return .zh }
        if containsIndonesian(trimmed) { return .id }

        if trimmed.count >= 6 {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(trimmed)
            if let lang = recognizer.dominantLanguage {
                switch lang {
                case .simplifiedChinese, .traditionalChinese:
                    return .zh
                case .indonesian:
                    return .id
                case .english:
                    return .en
                default:
                    break
                }
            }
        }

        return .en
    }

    static func detectLocale(from text: String) -> Locale? {
        guard let lang = detect(from: text) else { return nil }
        return Locale(identifier: lang.localeIdentifier)
    }

    static func defaultLocale() -> Locale {
        for preferred in Locale.preferredLanguages {
            if preferred.hasPrefix("zh") { return Locale(identifier: "zh-CN") }
            if preferred.hasPrefix("id") { return Locale(identifier: "id-ID") }
            if preferred.hasPrefix("en") { return Locale(identifier: "en-US") }
        }
        return Locale(identifier: "en-US")
    }

    private static func containsChinese(_ text: String) -> Bool {
        return text.range(of: "\\p{Han}", options: .regularExpression) != nil
    }

    private static func containsIndonesian(_ text: String) -> Bool {
        let lower = text.lowercased()
        let tokens = lower.split { !$0.isLetter }
        let keywords: Set<String> = [
            "yang","dan","tidak","apa","saya","kamu","anda","ini","itu","dengan","untuk",
            "karena","bagaimana","terima","kasih","tolong","bisa","akan","sudah","belum","juga",
            "mohon","sebagai","pada","dari","ke","di","adalah"
        ]
        return tokens.contains { keywords.contains(String($0)) }
    }
}
