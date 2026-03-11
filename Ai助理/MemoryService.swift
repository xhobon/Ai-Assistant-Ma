import Foundation
import Combine

final class MemoryModeStore: ObservableObject {
    static let shared = MemoryModeStore()
    private let key = "memory_mode_enabled"

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: key)
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        isEnabled = UserDefaults.standard.bool(forKey: key)
    }
}

final class MemoryService {
    static let shared = MemoryService()
    private init() {}

    private struct Rule {
        let key: String
        let patterns: [NSRegularExpression]
    }

    private lazy var rules: [Rule] = {
        func make(_ key: String, _ patterns: [String]) -> Rule {
            Rule(
                key: key,
                patterns: patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
            )
        }
        return [
            make("name", [
                "\\bmy name is\\s+([^\\.\\!\\?\\n]{1,60})",
                "\\bcall me\\s+([^\\.\\!\\?\\n]{1,60})",
                "\\bnama saya\\s+([^\\.\\!\\?\\n]{1,60})",
                "\\bsaya bernama\\s+([^\\.\\!\\?\\n]{1,60})",
                "我叫([^。！？\\n]{1,30})",
                "我的名字是([^。！？\\n]{1,30})"
            ]),
            make("location", [
                "\\bi live in\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bi am in\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bi'm in\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bsaya tinggal di\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bsaya berada di\\s+([^\\.\\!\\?\\n]{1,80})",
                "我住在([^。！？\\n]{1,40})",
                "我在([^。！？\\n]{1,40})"
            ]),
            make("language", [
                "\\bi speak\\s+([^\\.\\!\\?\\n]{1,40})",
                "\\bi prefer\\s+([^\\.\\!\\?\\n]{1,40})\\s+language",
                "\\bbahasa saya\\s+([^\\.\\!\\?\\n]{1,40})",
                "\\bsaya lebih suka\\s+bahasa\\s+([^\\.\\!\\?\\n]{1,40})",
                "我喜欢用([^。！？\\n]{1,20})语"
            ]),
            make("company", [
                "\\bmy company is\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bi work at\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bi work for\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bperusahaan saya\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bsaya bekerja di\\s+([^\\.\\!\\?\\n]{1,80})",
                "我的公司是([^。！？\\n]{1,40})"
            ]),
            make("interest", [
                "\\bi like\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bi enjoy\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bi'm interested in\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bsaya suka\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bsaya tertarik pada\\s+([^\\.\\!\\?\\n]{1,80})",
                "我喜欢([^。！？\\n]{1,40})"
            ]),
            make("preference", [
                "\\bi prefer\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bi want\\s+([^\\.\\!\\?\\n]{1,80})",
                "\\bsaya lebih suka\\s+([^\\.\\!\\?\\n]{1,80})",
                "我更喜欢([^。！？\\n]{1,40})"
            ])
        ]
    }()

    func extractMemories(from text: String) -> [UserMemoryEntry] {
        guard MemoryModeStore.shared.isEnabled else { return [] }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        var results: [UserMemoryEntry] = []
        let userId = currentUserId()

        for rule in rules {
            for regex in rule.patterns {
                let nsText = cleaned as NSString
                let range = NSRange(location: 0, length: nsText.length)
                if let match = regex.firstMatch(in: cleaned, range: range), match.numberOfRanges >= 2 {
                    let valueRange = match.range(at: 1)
                    if valueRange.location != NSNotFound,
                       let swiftRange = Range(valueRange, in: cleaned) {
                        let raw = String(cleaned[swiftRange])
                        let value = sanitizeValue(raw)
                        guard !value.isEmpty else { continue }
                        let entry = UserMemoryEntry.make(userId: userId, memoryKey: rule.key, memoryValue: value)
                        results.append(entry)
                    }
                }
            }
        }

        return dedupe(results)
    }

    func upsert(_ entries: [UserMemoryEntry]) {
        guard !entries.isEmpty else { return }
        var list = LocalDataStore.shared.loadUserMemories()
        for entry in entries {
            if let idx = list.firstIndex(where: { $0.memoryKey.lowercased() == entry.memoryKey.lowercased() }) {
                var updated = list[idx]
                updated.memoryValue = entry.memoryValue
                updated.updatedAt = Date()
                list[idx] = updated
            } else {
                list.insert(entry, at: 0)
            }
        }
        LocalDataStore.shared.saveUserMemories(list)
    }

    func loadMemories() -> [UserMemoryEntry] {
        LocalDataStore.shared.loadUserMemories()
    }

    func deleteMemory(id: String) {
        LocalDataStore.shared.removeUserMemory(id: id)
    }

    func updateMemory(id: String, key: String, value: String) {
        var list = LocalDataStore.shared.loadUserMemories()
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].memoryKey = key
            list[idx].memoryValue = value
            list[idx].updatedAt = Date()
            LocalDataStore.shared.saveUserMemories(list)
        }
    }

    func buildContext() -> String {
        let list = LocalDataStore.shared.loadUserMemories()
        guard !list.isEmpty else { return "" }
        let lines = list
            .sorted { $0.memoryKey.lowercased() < $1.memoryKey.lowercased() }
            .map { entry in
                "\(prettyKey(entry.memoryKey)): \(entry.memoryValue)"
            }
        return "User info:\n" + lines.joined(separator: "\n")
    }

    private func currentUserId() -> String {
        TokenStore.shared.isLoggedIn ? "logged_in" : "local"
    }

    private func sanitizeValue(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let punctuation = CharacterSet(charactersIn: ".,;!?:\"'，。！？；：")
        value = value.trimmingCharacters(in: punctuation).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count > 120 {
            value = String(value.prefix(120))
        }
        return value
    }

    private func prettyKey(_ key: String) -> String {
        switch key.lowercased() {
        case "name": return "Name"
        case "language": return "Language"
        case "location": return "Location"
        case "company": return "Company"
        case "interest": return "Interests"
        case "preference": return "Preference"
        default: return key.capitalized
        }
    }

    private func dedupe(_ items: [UserMemoryEntry]) -> [UserMemoryEntry] {
        var seen = Set<String>()
        var result: [UserMemoryEntry] = []
        for item in items {
            let key = item.memoryKey.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }
}
