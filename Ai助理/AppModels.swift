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

    static let all: [LanguageOption] = [.chinese, .indonesian]
}

struct VocabCategory: Identifiable, Hashable, Codable {
    let id: String
    let nameZh: String
    let nameId: String
    let items: [VocabItem]
}

struct VocabItem: Identifiable, Hashable, Codable {
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

struct LearningCategoriesResponse: Codable {
    let categories: [VocabCategory]
}

struct LearningFavoritesResponse: Codable {
    let favorites: [String]
}

/// 助理长期记忆条目（偏好、习惯、重要事实），用于个性化回复与持续学习
struct UserMemoryItem: Identifiable, Hashable, Codable {
    let id: String
    var content: String
    var category: String /// preference | habit | goal
    var confidence: Double? = nil
    var expiresAt: Date? = nil
    var source: String? = nil
    let createdAt: Date

    static func from(
        _ content: String,
        category: String = "preference",
        confidence: Double? = nil,
        expiresAt: Date? = nil,
        source: String? = nil,
        id: String = UUID().uuidString,
        createdAt: Date = Date()
    ) -> UserMemoryItem {
        UserMemoryItem(
            id: id,
            content: content,
            category: category,
            confidence: confidence,
            expiresAt: expiresAt,
            source: source,
            createdAt: createdAt
        )
    }
}

enum ReminderStatus: String, Codable {
    case none
    case pending
    case done
}

struct NoteEntry: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let summary: String
    let content: String
    let tags: [String]
    let category: String
    var reminderAt: Date?
    var reminderText: String?
    var reminderSnoozeHours: Int?
    var reminderStatus: ReminderStatus
    let createdAt: Date

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: createdAt)
    }

    var notificationId: String { "note-reminder-\(id)" }
}
