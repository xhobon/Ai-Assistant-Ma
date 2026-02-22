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
