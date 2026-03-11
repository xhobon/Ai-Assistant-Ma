import Foundation
import Combine

/// 本地数据存储服务（用于未登录用户）
final class LocalDataStore: ObservableObject {
    static let shared = LocalDataStore()
    
    private let conversationsKey = "local_conversations"
    private let translationsKey = "local_translations"
    private let currentConversationKey = "current_conversation_id"
    private let memoriesKey = "local_assistant_memories"
    private let notesKey = "local_notes_v2"
    private let summariesKey = "local_summaries_v1"
    private let cloudConversationSummariesKey = "cloud_conversation_summaries_v1"
    private let localConversationSummariesKey = "local_conversation_summaries_v1"
    private let localConversationCustomTitlesKey = "local_conversation_custom_titles_v1"
    private let pendingTitleUpdatesKey = "pending_conversation_title_updates_v1"
    private let pendingDeleteIdsKey = "pending_conversation_delete_ids_v1"

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
        updateLocalConversationSummary(id: id, messages: messages)
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
        removeLocalConversationSummary(id: id)
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
        UserDefaults.standard.removeObject(forKey: notesKey)
        UserDefaults.standard.removeObject(forKey: summariesKey)
        UserDefaults.standard.removeObject(forKey: cloudConversationSummariesKey)
        UserDefaults.standard.removeObject(forKey: localConversationSummariesKey)
        UserDefaults.standard.removeObject(forKey: localConversationCustomTitlesKey)
        UserDefaults.standard.removeObject(forKey: pendingTitleUpdatesKey)
        UserDefaults.standard.removeObject(forKey: pendingDeleteIdsKey)
    }

    // MARK: - 助理长期记忆（未登录时本地存储，登录后与云端同步）

    /// 保存本地记忆列表
    func saveMemories(_ items: [UserMemoryItem]) {
        let data = items.map { m in
            var row: [String: Any] = [
                "id": m.id,
                "content": m.content,
                "category": m.category,
                "createdAt": m.createdAt.timeIntervalSince1970
            ]
            if let confidence = m.confidence { row["confidence"] = confidence }
            if let expiresAt = m.expiresAt { row["expiresAt"] = expiresAt.timeIntervalSince1970 }
            if let source = m.source, !source.isEmpty { row["source"] = source }
            return row
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
            let confidence = data["confidence"] as? Double
            let expiresAt = (data["expiresAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            let source = data["source"] as? String
            return UserMemoryItem(
                id: id,
                content: content,
                category: category,
                confidence: confidence,
                expiresAt: expiresAt,
                source: source,
                createdAt: Date(timeIntervalSince1970: t)
            )
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

    // MARK: - Notes

    func saveNotes(_ notes: [NoteEntry]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    func loadNotes() -> [NoteEntry] {
        guard let data = UserDefaults.standard.data(forKey: notesKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([NoteEntry].self, from: data)) ?? []
    }

    func updateNote(_ note: NoteEntry) {
        var list = loadNotes()
        if let idx = list.firstIndex(where: { $0.id == note.id }) {
            list[idx] = note
        } else {
            list.insert(note, at: 0)
        }
        saveNotes(list)
    }

    // MARK: - Cloud Conversation Summaries (缓存)

    func saveCloudConversationSummaries(_ list: [CloudConversationSummary]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(list) {
            UserDefaults.standard.set(data, forKey: cloudConversationSummariesKey)
        }
    }

    func loadCloudConversationSummaries() -> [CloudConversationSummary] {
        guard let data = UserDefaults.standard.data(forKey: cloudConversationSummariesKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([CloudConversationSummary].self, from: data)) ?? []
    }

    // MARK: - Local Conversation Summaries

    func loadLocalConversationSummaries() -> [CloudConversationSummary] {
        if let data = UserDefaults.standard.data(forKey: localConversationSummariesKey) {
            let decoder = JSONDecoder()
            let decoded = (try? decoder.decode([CloudConversationSummary].self, from: data)) ?? []
            if !decoded.isEmpty {
                return decoded.sorted { $0.updatedAt > $1.updatedAt }
            }
        }
        let all = loadAllConversations()
        if all.isEmpty { return [] }
        var rebuilt: [CloudConversationSummary] = []
        let formatter = ISO8601DateFormatter()
        for (id, rows) in all {
            let last = rows.last
            let first = rows.first
            let lastText = (last?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let firstText = (first?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = firstText.isEmpty ? "对话摘要" : String(firstText.prefix(20))
            let lastTime = (last?["time"] as? TimeInterval) ?? Date().timeIntervalSince1970
            let firstTime = (first?["time"] as? TimeInterval) ?? lastTime
            rebuilt.append(
                CloudConversationSummary(
                    id: id,
                    title: title,
                    createdAt: formatter.string(from: Date(timeIntervalSince1970: firstTime)),
                    updatedAt: formatter.string(from: Date(timeIntervalSince1970: lastTime)),
                    lastMessage: String(lastText.prefix(80))
                )
            )
        }
        rebuilt.sort { $0.updatedAt > $1.updatedAt }
        saveLocalConversationSummaries(rebuilt)
        return rebuilt
    }

    func saveLocalConversationSummaries(_ list: [CloudConversationSummary]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(list) {
            UserDefaults.standard.set(data, forKey: localConversationSummariesKey)
        }
    }

    func markConversationTitleCustom(id: String) {
        var set = loadCustomTitleIds()
        set.insert(id)
        saveCustomTitleIds(set)
    }

    func isConversationTitleCustom(id: String) -> Bool {
        let set = loadCustomTitleIds()
        return set.contains(id)
    }

    private func loadCustomTitleIds() -> Set<String> {
        let raw = UserDefaults.standard.array(forKey: localConversationCustomTitlesKey) as? [String] ?? []
        return Set(raw)
    }

    private func saveCustomTitleIds(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: localConversationCustomTitlesKey)
    }

    private func updateLocalConversationSummary(id: String, messages: [ChatMessage]) {
        let summaryTitle: String
        if let existing = loadLocalConversationSummaries().first(where: { $0.id == id }),
           isConversationTitleCustom(id: id),
           !existing.title.isEmpty {
            summaryTitle = existing.title
        } else {
            summaryTitle = deriveConversationTitle(from: messages)
        }
        let lastMessage = messages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let createdAt = messages.first?.time ?? Date()
        let updatedAt = messages.last?.time ?? Date()

        var list = loadLocalConversationSummaries()
        list.removeAll { $0.id == id }
        list.append(CloudConversationSummary(
            id: id,
            title: summaryTitle,
            createdAt: ISO8601DateFormatter().string(from: createdAt),
            updatedAt: ISO8601DateFormatter().string(from: updatedAt),
            lastMessage: String(lastMessage.prefix(80))
        ))
        list.sort { $0.updatedAt > $1.updatedAt }
        saveLocalConversationSummaries(list)
    }

    func updateLocalConversationTitle(id: String, title: String) {
        var list = loadLocalConversationSummaries()
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        if let idx = list.firstIndex(where: { $0.id == id }) {
            let existing = list[idx]
            list[idx] = CloudConversationSummary(
                id: existing.id,
                title: title,
                createdAt: existing.createdAt,
                updatedAt: now,
                lastMessage: existing.lastMessage
            )
        } else {
            list.append(CloudConversationSummary(
                id: id,
                title: title,
                createdAt: now,
                updatedAt: now,
                lastMessage: ""
            ))
        }
        list.sort { $0.updatedAt > $1.updatedAt }
        saveLocalConversationSummaries(list)
        markConversationTitleCustom(id: id)
    }

    private func removeLocalConversationSummary(id: String) {
        var list = loadLocalConversationSummaries()
        list.removeAll { $0.id == id }
        saveLocalConversationSummaries(list)
        var set = loadCustomTitleIds()
        set.remove(id)
        saveCustomTitleIds(set)
    }

    // MARK: - Pending Sync Ops

    func enqueuePendingTitleUpdate(id: String, title: String) {
        var dict = loadPendingTitleUpdates()
        dict[id] = title
        savePendingTitleUpdates(dict)
    }

    func removePendingTitleUpdate(id: String) {
        var dict = loadPendingTitleUpdates()
        dict.removeValue(forKey: id)
        savePendingTitleUpdates(dict)
    }

    func loadPendingTitleUpdates() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: pendingTitleUpdatesKey) as? [String: String] ?? [:]
    }

    private func savePendingTitleUpdates(_ dict: [String: String]) {
        UserDefaults.standard.set(dict, forKey: pendingTitleUpdatesKey)
    }

    func enqueuePendingDelete(id: String) {
        var list = loadPendingDeletes()
        if !list.contains(id) { list.append(id) }
        UserDefaults.standard.set(list, forKey: pendingDeleteIdsKey)
    }

    func removePendingDelete(id: String) {
        var list = loadPendingDeletes()
        list.removeAll { $0 == id }
        UserDefaults.standard.set(list, forKey: pendingDeleteIdsKey)
    }

    func loadPendingDeletes() -> [String] {
        return UserDefaults.standard.array(forKey: pendingDeleteIdsKey) as? [String] ?? []
    }

    // MARK: - Summaries

    func saveSummaries(_ summaries: [SummaryEntry]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(summaries) {
            UserDefaults.standard.set(data, forKey: summariesKey)
        }
    }

    func loadSummaries() -> [SummaryEntry] {
        guard let data = UserDefaults.standard.data(forKey: summariesKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([SummaryEntry].self, from: data)) ?? []
    }

    func addSummary(_ summary: SummaryEntry) {
        var list = loadSummaries()
        list.insert(summary, at: 0)
        saveSummaries(list)
    }
    
    // MARK: - 私有方法
    
    /// 加载翻译原始数据（用于内部读写）
    private func loadTranslationsRaw() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: translationsKey) as? [[String: Any]] ?? []
    }

    private func deriveConversationTitle(from messages: [ChatMessage]) -> String {
        guard let firstUser = messages.first(where: { $0.role == .user }) else {
            return "对话摘要"
        }
        var raw = firstUser.content
        raw = raw
            .replacingOccurrences(of: "[图片]", with: " ")
            .replacingOccurrences(of: "[用户附了一张图]", with: " ")
        raw = raw.replacingOccurrences(of: "\\[文件:[^\\]]+\\]", with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            raw = "图片识别任务"
        }
        raw = raw.replacingOccurrences(of: "^(请|帮我|帮忙|麻烦|能否|能不能|可以|想要|请帮我|帮我一下|帮忙一下)\\s*", with: "", options: .regularExpression)
        let noPunc = raw.replacingOccurrences(of: "[^\\p{L}\\p{N}\\s]", with: " ", options: .regularExpression)
        let base = noPunc.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        var chars = Array(base.isEmpty ? raw : base)
        if chars.count > 20 {
            chars = Array(chars.prefix(20))
        }
        if chars.count < 6 {
            let padded = "关于" + String(chars) + "对话"
            var paddedChars = Array(padded)
            if paddedChars.count < 6 {
                paddedChars.append(contentsOf: Array("记录"))
            }
            return String(paddedChars.prefix(20))
        }
        return String(chars)
    }
}
