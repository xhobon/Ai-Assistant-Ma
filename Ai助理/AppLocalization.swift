import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh"
    case indonesian = "id"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .indonesian: return "Bahasa Indonesia"
        case .english: return "English"
        }
    }

    static func fromSystem() -> AppLanguage {
        let code = Locale.current.languageCode ?? "zh"
        switch code {
        case "zh": return .chinese
        case "id": return .indonesian
        case "en": return .english
        default: return .english
        }
    }

    var localeIdentifier: String {
        switch self {
        case .chinese: return "zh-Hans"
        case .indonesian: return "id"
        case .english: return "en"
        }
    }
}

final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    private let key = "app_language"

    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: key)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: key), let lang = AppLanguage(rawValue: saved) {
            current = lang
        } else {
            let detected = AppLanguage.fromSystem()
            current = detected
            UserDefaults.standard.set(detected.rawValue, forKey: key)
        }
    }

    func setLanguage(code: String) {
        guard let lang = AppLanguage(rawValue: code) else { return }
        current = lang
    }

    var locale: Locale { Locale(identifier: current.localeIdentifier) }

    private var bundle: Bundle {
        if let path = Bundle.main.path(forResource: current.localeIdentifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle.main.path(forResource: current.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: args)
    }
}

final class PinyinService {
    static let shared = PinyinService()
    private var cache: [String: String] = [:]

    private init() {}

    func pinyin(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let cached = cache[trimmed] {
            return cached
        }
        let mutable = NSMutableString(string: trimmed) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        var result = mutable as String
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: "\n", with: " ")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.capitalized
        cache[trimmed] = result
        return result
    }
}

@inline(__always)
func L(_ key: String) -> String {
    AppLanguageStore.shared.localized(key)
}

@inline(__always)
func Lf(_ key: String, _ args: CVarArg...) -> String {
    AppLanguageStore.shared.localizedFormat(key, args)
}
