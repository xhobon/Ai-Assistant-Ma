import Foundation
import Combine

/// 本地数据存储服务（用于未登录用户）
final class LocalDataStore: ObservableObject {
    static let shared = LocalDataStore()
    
    private let conversationsKey = "local_conversations"
    private let translationsKey = "local_translations"
    private let currentConversationKey = "current_conversation_id"
    private let memoriesKey = "local_assistant_memories"

    private init() {}
    
    // MARK: - 对话数据
    
    /// 保存对话消息
    func saveConversation(id: String, messages: [ChatMessage]) {
        var conversations = loadAllConversations()
        conversations[id] = messages.map { msg in
            [
                "id": msg.id,
                "role": msg.role.rawValue,
                "content": msg.content,
                "time": msg.time.timeIntervalSince1970
            ]
        }
        UserDefaults.standard.set(conversations, forKey: conversationsKey)
    }
    
    /// 加载对话消息
    func loadConversation(id: String) -> [ChatMessage] {
        guard let conversations = UserDefaults.standard.dictionary(forKey: conversationsKey) as? [String: [[String: Any]]],
              let messagesData = conversations[id] else {
            return []
        }
        
        return messagesData.compactMap { data in
            guard let id = data["id"] as? String,
                  let roleStr = data["role"] as? String,
                  let role = ChatRole(rawValue: roleStr),
                  let content = data["content"] as? String,
                  let timeInterval = data["time"] as? TimeInterval else {
                return nil
            }
            return ChatMessage(
                id: id,
                role: role,
                content: content,
                time: Date(timeIntervalSince1970: timeInterval)
            )
        }
    }
    
    /// 加载所有对话
    func loadAllConversations() -> [String: [[String: Any]]] {
        return UserDefaults.standard.dictionary(forKey: conversationsKey) as? [String: [[String: Any]]] ?? [:]
    }
    
    /// 删除对话
    func deleteConversation(id: String) {
        var conversations = loadAllConversations()
        conversations.removeValue(forKey: id)
        UserDefaults.standard.set(conversations, forKey: conversationsKey)
    }
    
    /// 保存当前对话ID
    func saveCurrentConversationId(_ id: String?) {
        if let id = id {
            UserDefaults.standard.set(id, forKey: currentConversationKey)
        } else {
            UserDefaults.standard.removeObject(forKey: currentConversationKey)
        }
    }
    
    /// 加载当前对话ID
    func loadCurrentConversationId() -> String? {
        return UserDefaults.standard.string(forKey: currentConversationKey)
    }
    
    // MARK: - 翻译历史
    
    /// 保存翻译记录
    func saveTranslation(_ translation: TranslationEntry) {
        var translations = loadTranslationsRaw()
        let data: [String: Any] = [
            "id": translation.id,
            "sourceText": translation.sourceText,
            "targetText": translation.targetText,
            "sourceLang": translation.sourceLang.code,
            "targetLang": translation.targetLang.code,
            "createdAt": translation.createdAt.timeIntervalSince1970
        ]
        translations.append(data)
        UserDefaults.standard.set(translations, forKey: translationsKey)
    }
    
    /// 加载所有翻译记录
    func loadAllTranslations() -> [TranslationEntry] {
        guard let translationsData = UserDefaults.standard.array(forKey: translationsKey) as? [[String: Any]] else {
            return []
        }
        
        return translationsData.compactMap { data in
            guard let id = data["id"] as? String,
                  let sourceText = data["sourceText"] as? String,
                  let targetText = data["targetText"] as? String,
                  let sourceLangCode = data["sourceLang"] as? String,
                  let targetLangCode = data["targetLang"] as? String,
                  let createdAtInterval = data["createdAt"] as? TimeInterval else {
                return nil
            }
            
            let sourceLang = LanguageOption.all.first { $0.code == sourceLangCode } ?? .chinese
            let targetLang = LanguageOption.all.first { $0.code == targetLangCode } ?? .indonesian
            
            return TranslationEntry(
                id: id,
                sourceText: sourceText,
                targetText: targetText,
                sourceLang: sourceLang,
                targetLang: targetLang,
                createdAt: Date(timeIntervalSince1970: createdAtInterval)
            )
        }
    }
    
    /// 删除翻译记录
    func deleteTranslation(id: String) {
        var translations = loadAllTranslations()
        translations.removeAll { $0.id == id }
        let translationsData = translations.map { trans in
            [
                "id": trans.id,
                "sourceText": trans.sourceText,
                "targetText": trans.targetText,
                "sourceLang": trans.sourceLang.code,
                "targetLang": trans.targetLang.code,
                "createdAt": trans.createdAt.timeIntervalSince1970
            ]
        }
        UserDefaults.standard.set(translationsData, forKey: translationsKey)
    }
    
    /// 清除所有本地数据
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: conversationsKey)
        UserDefaults.standard.removeObject(forKey: translationsKey)
        UserDefaults.standard.removeObject(forKey: currentConversationKey)
        UserDefaults.standard.removeObject(forKey: memoriesKey)
    }

    // MARK: - 助理长期记忆（未登录时本地存储，登录后与云端同步）

    /// 保存本地记忆列表
    func saveMemories(_ items: [UserMemoryItem]) {
        let data = items.map { m in
            [
                "id": m.id,
                "content": m.content,
                "category": m.category,
                "createdAt": m.createdAt.timeIntervalSince1970
            ] as [String: Any]
        }
        UserDefaults.standard.set(data, forKey: memoriesKey)
    }

    /// 加载本地记忆
    func loadMemories() -> [UserMemoryItem] {
        guard let list = UserDefaults.standard.array(forKey: memoriesKey) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { data in
            guard let id = data["id"] as? String,
                  let content = data["content"] as? String,
                  let category = data["category"] as? String,
                  let t = data["createdAt"] as? TimeInterval else { return nil }
            return UserMemoryItem(id: id, content: content, category: category, createdAt: Date(timeIntervalSince1970: t))
        }
    }

    /// 追加一条本地记忆（去重：同内容不重复添加）
    func addMemory(_ item: UserMemoryItem) {
        var list = loadMemories()
        if list.contains(where: { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) == item.content.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            return
        }
        list.insert(item, at: 0)
        if list.count > 100 { list = Array(list.prefix(100)) }
        saveMemories(list)
    }

    /// 删除一条本地记忆
    func removeMemory(id: String) {
        var list = loadMemories()
        list.removeAll { $0.id == id }
        saveMemories(list)
    }

    /// 将本地记忆格式化为发送给后端的 userContext 字符串
    func memoriesAsUserContext() -> String {
        let list = loadMemories()
        guard !list.isEmpty else { return "" }
        return list.prefix(30).map { "[\($0.category)] \($0.content)" }.joined(separator: "\n")
    }
    
    // MARK: - 私有方法
    
    /// 加载翻译原始数据（用于内部读写）
    private func loadTranslationsRaw() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: translationsKey) as? [[String: Any]] ?? []
    }
}
