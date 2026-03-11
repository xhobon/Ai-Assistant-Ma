import Foundation
import Combine

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let role: ChatRole
    var content: String
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

    var displayName: String { L(name) }

    static let chinese = LanguageOption(id: "zh", code: "zh", name: "中文", speechCode: "zh-CN")
    static let indonesian = LanguageOption(id: "id", code: "id", name: "印尼文", speechCode: "id-ID")
    static let english = LanguageOption(id: "en", code: "en", name: "English", speechCode: "en-US")

    static let all: [LanguageOption] = [.chinese, .indonesian, .english]
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

enum LearningMode: String, CaseIterable, Identifiable, Codable {
    case zhToId
    case idToZh

    var id: String { rawValue }

    var sourceLanguage: LanguageOption {
        switch self {
        case .zhToId: return .chinese
        case .idToZh: return .indonesian
        }
    }

    var targetLanguage: LanguageOption {
        switch self {
        case .zhToId: return .indonesian
        case .idToZh: return .chinese
        }
    }
}

enum PracticeQuestionType: String, CaseIterable, Identifiable, Codable {
    case multipleChoice
    case trueFalse
    case matching
    case fillBlank
    case wordBuild
    case translation
    case listening
    case sentenceOrder
    case dictation

    var id: String { rawValue }
}

struct PracticeMatchPair: Hashable, Codable {
    let left: String
    let right: String
}

enum PracticeQuestionPayload: Hashable {
    case multipleChoice(sourceText: String, options: [String], answer: String, targetLanguage: String)
    case trueFalse(sourceText: String, candidateText: String, correctText: String, answer: Bool, targetLanguage: String)
    case matching(left: [String], right: [String], pairs: [PracticeMatchPair])
    case fillBlank(prompt: String, answer: String)
    case wordBuild(prompt: String, tokens: [String], answer: String, separator: String, targetLanguage: String)
    case translation(sourceText: String, answer: String, targetLanguage: String)
    case listening(audioText: String, options: [String], answer: String, targetLanguage: String, audioLanguage: String)
    case sentenceOrder(words: [String], answer: String, language: String)
    case dictation(audioText: String, answer: String, targetLanguage: String, audioLanguage: String)
}

struct PracticeQuestion: Identifiable, Hashable {
    let id: String
    let type: PracticeQuestionType
    let mode: LearningMode
    let itemId: String
    let payload: PracticeQuestionPayload
}

struct DailyTaskItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let targetCount: Int
    let type: String
    var isCompleted: Bool
}

enum LearningLevel: String, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }
}

enum LearningDifficulty: String, CaseIterable, Identifiable {
    case all
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .all: return "difficulty_all"
        case .beginner: return "difficulty_beginner"
        case .intermediate: return "difficulty_intermediate"
        case .advanced: return "difficulty_advanced"
        }
    }
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

// MARK: - User Memory (Key-Value)

/// 用户关键事实记忆（结构化 KV）
struct UserMemoryEntry: Identifiable, Hashable, Codable {
    let id: String
    var userId: String
    var memoryKey: String
    var memoryValue: String
    var createdAt: Date
    var updatedAt: Date

    static func make(
        userId: String = "local",
        memoryKey: String,
        memoryValue: String,
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> UserMemoryEntry {
        UserMemoryEntry(
            id: id,
            userId: userId,
            memoryKey: memoryKey,
            memoryValue: memoryValue,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Knowledge Base

struct KnowledgeDocument: Identifiable, Hashable, Codable {
    let id: String
    let fileName: String
    let fileType: String
    let localPath: String
    let size: Int
    let chunkCount: Int
    let createdAt: Date
}

struct VectorStoreEntry: Identifiable, Hashable, Codable {
    let id: String
    let documentId: String
    let chunkText: String
    let embeddingVector: [Double]
    let createdAt: Date
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

struct SummaryEntry: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let tags: [String]
    let content: String
    let rawText: String
    let createdAt: Date

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: createdAt)
    }
}

enum SyncStatus: String {
    case idle
    case syncing
    case success
    case failed

    var label: String {
        switch self {
        case .idle: return L("未同步")
        case .syncing: return L("同步中")
        case .success: return L("已同步")
        case .failed: return L("同步失败")
        }
    }
}

final class SyncStatusStore: ObservableObject {
    static let shared = SyncStatusStore()
    @Published var status: SyncStatus = .idle
    @Published var lastError: String? = nil

    private init() {}
}
