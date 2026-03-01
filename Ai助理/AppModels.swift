import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let role: ChatRole
    let content: String
    let time: Date
}

struct TranslationEntry: Identifiable, Hashable {
    let id: String
    let sourceText: String
    let targetText: String
    let sourceLang: LanguageOption
    let targetLang: LanguageOption
    let createdAt: Date
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let speechCode: String

    static let chinese = LanguageOption(id: "zh", code: "zh", name: "中文", speechCode: "zh-CN")
    static let indonesian = LanguageOption(id: "id", code: "id", name: "印尼文", speechCode: "id-ID")
    static let english = LanguageOption(id: "en", code: "en", name: "英语", speechCode: "en-US")

    static let all: [LanguageOption] = [.chinese, .indonesian, .english]
}

struct VocabCategory: Identifiable, Hashable {
    let id: String
    let nameZh: String
    let nameId: String
    let items: [VocabItem]
}

struct VocabItem: Identifiable, Hashable {
    let id: String
    let textZh: String
    let textId: String
    let exampleZh: String
    let exampleId: String
}

struct LearningStat: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
}

struct UserStats: Codable {
    let todayConversations: Int
    let todayTranslations: Int
    let todayLearningMinutes: Int
    let totalConversations: Int
    let totalTranslations: Int
    let totalLearningMinutes: Int
    let learningSessions: Int
}

/// 助理长期记忆条目（偏好、习惯、重要事实），用于个性化回复与持续学习
struct UserMemoryItem: Identifiable, Hashable, Codable {
    let id: String
    var content: String
    var category: String /// fact | preference | habit
    let createdAt: Date

    static func from(_ content: String, category: String = "fact", id: String = UUID().uuidString, createdAt: Date = Date()) -> UserMemoryItem {
        UserMemoryItem(id: id, content: content, category: category, createdAt: createdAt)
    }
}
