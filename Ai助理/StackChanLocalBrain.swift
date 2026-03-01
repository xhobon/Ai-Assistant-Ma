import Foundation

struct StackChanBrainReply {
    let text: String
    let emotion: StackChanEmotion
}

final class StackChanLocalBrain {
    static let shared = StackChanLocalBrain()

    private let learnedMapKey = "stack_chan_learned_map"
    private let notesKey = "stack_chan_learned_notes"
    private let recentTopicsKey = "stack_chan_recent_topics"

    private init() {}

    func reply(
        to input: String,
        petName: String,
        favoriteTopic: String
    ) -> StackChanBrainReply {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return .init(text: "我在，想聊什么呀？", emotion: .neutral)
        }

        if let learnedReply = teachIfNeeded(clean) {
            return learnedReply
        }

        if let answer = learnedAnswer(for: clean) {
            return .init(text: answer, emotion: .happy)
        }

        storeTopic(from: clean)

        if clean.contains("你是谁") || clean.contains("自我介绍") {
            return .init(text: "我是\(petName)，你的手机机器人伙伴。", emotion: .happy)
        }
        if clean.contains("你会什么") {
            return .init(text: "我会听你说话、语音播报、记住你教我的内容，还会情绪互动。", emotion: .thinking)
        }
        if clean.contains("学习") || clean.contains("练习") {
            return .init(text: "我们来练\(favoriteTopic)吧，你说一句我来陪练。", emotion: .happy)
        }
        if clean.contains("翻译") {
            return .init(text: "收到，切到翻译模式我可以继续帮你。", emotion: .neutral)
        }
        if clean.contains("笑话") {
            return .init(text: "为什么机器人不熬夜？因为会低电量emo。", emotion: .happy)
        }
        if clean.contains("我今天") && (clean.contains("累") || clean.contains("烦")) {
            return .init(text: "辛苦了，先深呼吸三次，我在这陪你。", emotion: .sad)
        }
        if clean.contains("最近话题") || clean.contains("我们聊了什么") {
            let topics = recentTopics().joined(separator: "、")
            let summary = topics.isEmpty ? "还没有记录到明显话题。" : "最近你常聊：\(topics)。"
            return .init(text: summary, emotion: .thinking)
        }

        let fallback = [
            "嗯嗯，我在认真听。",
            "收到，我记下来了。",
            "这个有意思，再说详细一点。",
            "明白，我和你一起处理。"
        ].randomElement() ?? "我在听。"
        return .init(text: fallback, emotion: .neutral)
    }

    private func teachIfNeeded(_ text: String) -> StackChanBrainReply? {
        if text.hasPrefix("记住：") || text.hasPrefix("学习：") {
            let body = text.replacingOccurrences(of: "记住：", with: "").replacingOccurrences(of: "学习：", with: "")
            return persistPair(body)
        }
        if text.contains("当我说") && text.contains("你说") {
            let normalized = text.replacingOccurrences(of: "当我说", with: "")
            let parts = normalized.components(separatedBy: "你说")
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return savePair(key: key, value: value)
        }
        return nil
    }

    private func persistPair(_ body: String) -> StackChanBrainReply {
        let splitters = ["=", "=>", "->", "：", ":"]
        for splitter in splitters {
            let pair = body.components(separatedBy: splitter)
            if pair.count == 2 {
                let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return savePair(key: key, value: value)
            }
        }
        return .init(text: "学习格式可用：记住：关键词=回复内容", emotion: .thinking)
    }

    private func savePair(key: String, value: String) -> StackChanBrainReply {
        guard !key.isEmpty, !value.isEmpty else {
            return .init(text: "学习失败，关键词和回复都不能为空。", emotion: .sad)
        }
        var map = learnedMap()
        map[key.lowercased()] = value
        saveLearnedMap(map)
        return .init(text: "好，我学会了：当你说“\(key)”时，我会回答“\(value)”。", emotion: .happy)
    }

    private func learnedAnswer(for input: String) -> String? {
        let map = learnedMap()
        let lower = input.lowercased()
        if let exact = map[lower] { return exact }
        return map.first(where: { lower.contains($0.key) })?.value
    }

    private func learnedMap() -> [String: String] {
        guard let json = UserDefaults.standard.string(forKey: learnedMapKey),
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func saveLearnedMap(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map),
              let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: learnedMapKey)
    }

    private func storeTopic(from input: String) {
        var topics = recentTopics()
        let tokens = input
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count >= 2 }
            .prefix(3)
        for token in tokens {
            if !topics.contains(token) {
                topics.append(token)
            }
        }
        if topics.count > 12 {
            topics = Array(topics.suffix(12))
        }
        UserDefaults.standard.set(topics.joined(separator: "|"), forKey: recentTopicsKey)
    }

    private func recentTopics() -> [String] {
        let raw = UserDefaults.standard.string(forKey: recentTopicsKey) ?? ""
        if raw.isEmpty { return [] }
        return raw.components(separatedBy: "|")
    }

    func appendNote(_ note: String) {
        guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var notes = notesList()
        notes.append(note)
        if notes.count > 30 {
            notes = Array(notes.suffix(30))
        }
        UserDefaults.standard.set(notes.joined(separator: "\n"), forKey: notesKey)
    }

    func notesList() -> [String] {
        let raw = UserDefaults.standard.string(forKey: notesKey) ?? ""
        if raw.isEmpty { return [] }
        return raw.components(separatedBy: "\n")
    }
}
