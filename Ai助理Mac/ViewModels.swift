import Foundation
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import NaturalLanguage

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isListening = false
    @Published var isVideoCalling = false
    @Published var isPhotoMode = false
    @Published var statusText = "AI 已就绪"
    @Published var isSending = false
    @Published var alertMessage: String?

    private let speechTranscriber = SpeechTranscriber()
    private let maxContextCount = 12
    private var serverConversationId: String?
    private var voiceStopWorkItem: DispatchWorkItem?
    private var lastVoiceText: String?
    private var isStoppingVoice = false

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userMessage = ChatMessage(id: UUID().uuidString, role: .user, content: trimmed, time: Date())
        messages.append(userMessage)
        inputText = ""
        statusText = "思考中..."
        isSending = true

        Task {
            do {
                let (cid, reply) = try await APIClient.shared.assistantChat(
                    conversationId: serverConversationId,
                    message: trimmed
                )
                serverConversationId = cid
                let replyMsg = ChatMessage(id: UUID().uuidString, role: .assistant, content: reply, time: Date())
                messages.append(replyMsg)
                statusText = "AI 已就绪"
                SpeechService.shared.speak(reply, language: "zh-CN")
            } catch {
                alertMessage = userFacingMessage(for: error)
                statusText = "AI 未就绪"
            }
            isSending = false
        }
    }

    func resetConversation() {
        messages.removeAll()
        serverConversationId = nil
        statusText = "AI 已就绪"
    }

    /// 发送一条消息并等待 AI 回复（用于语音/视频通话）
    func sendAndWaitForReply(text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NSError(domain: "Chat", code: -1, userInfo: [NSLocalizedDescriptionKey: "内容为空"]) }
        let userMessage = ChatMessage(id: UUID().uuidString, role: .user, content: trimmed, time: Date())
        await MainActor.run { messages.append(userMessage) }
        let (cid, replyText) = try await APIClient.shared.assistantChat(
            conversationId: serverConversationId,
            message: trimmed
        )
        await MainActor.run { serverConversationId = cid }
        let replyMsg = ChatMessage(id: UUID().uuidString, role: .assistant, content: replyText, time: Date())
        await MainActor.run { messages.append(replyMsg) }
        return replyText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        SpeechService.shared.stopSpeaking()
        Task {
            let granted = await speechTranscriber.requestAuthorization()
            guard granted else {
                await MainActor.run { alertMessage = "未获得语音识别权限" }
                return
            }
            var startError: Error?
            await MainActor.run {
                do {
                    lastVoiceText = nil
                    isStoppingVoice = false
                    voiceStopWorkItem?.cancel()
                    isListening = true
                    statusText = "语音监听中"
                    try speechTranscriber.startTranscribing(locale: Locale(identifier: "zh-CN")) { [weak self] text, isFinal in
                        Task { @MainActor in
                            guard let self else { return }
                            if !text.isEmpty { self.inputText = text }
                            if isFinal { self.stopListening() }
                            self.scheduleAutoStopIfNeeded()
                        }
                    }
                } catch {
                    startError = error
                    isListening = false
                }
            }
            if let startError {
                await MainActor.run { alertMessage = startError.localizedDescription }
            }
        }
    }

    func stopListening() {
        if isStoppingVoice { return }
        isStoppingVoice = true
        voiceStopWorkItem?.cancel()
        speechTranscriber.stopTranscribing()
        isListening = false
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != lastVoiceText {
            lastVoiceText = trimmed
            sendMessage()
        }
        statusText = "AI 已就绪"
        isStoppingVoice = false
    }

    /// 手动打断 AI 朗读
    func stopSpeaking() {
        SpeechService.shared.stopSpeaking()
    }

    private func scheduleAutoStopIfNeeded() {
        voiceStopWorkItem?.cancel()
        guard isListening else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isListening else { return }
            let trimmed = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                self.stopListening()
            }
        }
        voiceStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    func toggleVideoCall() {
        if let url = URL(string: "facetime://") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
            isVideoCalling = true
            statusText = "已打开系统通话"
        } else {
            alertMessage = "无法打开系统通话"
        }
    }

    func togglePhotoMode() {
        isPhotoMode.toggle()
        statusText = isPhotoMode ? "请选择图片进行识别" : "AI 已就绪"
    }

    func handleImageData(_ data: Data) {
        #if os(iOS)
        guard UIImage(data: data) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
        #elseif os(macOS)
        guard NSImage(data: data) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
        #endif
        statusText = "图片识别中..."
        Task {
            do {
                let text = try await VisionService.shared.recognizeText(from: data)
                if text.isEmpty {
                    statusText = "未识别到文字"
                } else {
                    inputText = text
                    statusText = "已识别图片文字"
                }
            } catch {
                alertMessage = "识别失败：\(error.localizedDescription)"
                statusText = "AI 已就绪"
            }
        }
    }

    /// 视觉对话：识别图片文字后自动发送
    func handleImageDataAndSend(_ data: Data) async {
        #if os(iOS)
        guard UIImage(data: data) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
        #elseif os(macOS)
        guard NSImage(data: data) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
        #endif
        statusText = "图片识别中..."
        do {
            let text = try await VisionService.shared.recognizeText(from: data)
            if text.isEmpty {
                statusText = "未识别到文字"
                return
            }
            inputText = text
            statusText = "已识别图片文字"
            sendMessage()
        } catch {
            alertMessage = "识别失败：\(error.localizedDescription)"
            statusText = "AI 已就绪"
        }
    }
}

/// 根据文本检测语言（用于翻译「说完自动识别」）
private func detectedLanguage(from text: String) -> LanguageOption? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(trimmed)
    guard let lang = recognizer.dominantLanguage else { return nil }
    let code = lang.rawValue
    if code.hasPrefix("zh") { return .chinese }
    if code.hasPrefix("id") { return .indonesian }
    return nil
}

enum ListeningSide {
    case left
    case right
}

@MainActor
final class TranslateViewModel: ObservableObject {
    @Published var sourceLang: LanguageOption = .chinese
    @Published var targetLang: LanguageOption = .indonesian
    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var history: [TranslationEntry] = []
    @Published var isTranslating = false
    @Published var isListening = false
    @Published var listeningSide: ListeningSide = .left
    @Published var alertMessage: String?

    private let speechTranscriber = SpeechTranscriber()
    private var autoStopWorkItem: DispatchWorkItem?
    private let silenceTimeout: TimeInterval = 1.2

    init() {
        NotificationCenter.default.addObserver(forName: .clearLocalData, object: nil, queue: .main) { [weak self] _ in
            guard let viewModel = self else { return }
            Task { @MainActor in
                viewModel.history.removeAll()
            }
        }
    }

    func clearHistory() {
        history.removeAll()
    }

    func swapLanguages() {
        let temp = sourceLang
        sourceLang = targetLang
        targetLang = temp
        let tempText = sourceText
        sourceText = translatedText
        translatedText = tempText
    }

    /// 智能翻译：根据哪个框有内容，自动判断翻译方向
    func translate() {
        let leftTrimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rightTrimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果左边有内容，翻译到右边
        if !leftTrimmed.isEmpty && rightTrimmed.isEmpty {
            translateFromLeft()
        }
        // 如果右边有内容，翻译到左边
        else if !rightTrimmed.isEmpty && leftTrimmed.isEmpty {
            translateFromRight()
        }
        // 如果两边都有内容，优先翻译左边到右边
        else if !leftTrimmed.isEmpty {
            translateFromLeft()
        }
    }
    
    /// 从左边（中文）翻译到右边（印尼文）
    private func translateFromLeft() {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isTranslating = true

        Task {
            do {
                let result = try await APIClient.shared.translate(
                    text: trimmed,
                    sourceLang: sourceLang.speechCode,
                    targetLang: targetLang.speechCode
                )
                let translated = result.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    translatedText = translated
                    history.insert(
                        TranslationEntry(
                            id: UUID().uuidString,
                            sourceText: trimmed,
                            targetText: result,
                            sourceLang: sourceLang,
                            targetLang: targetLang,
                            createdAt: Date()
                        ),
                        at: 0
                    )
                    SpeechService.shared.speak(translated, language: targetLang.speechCode)
                }
            } catch {
                await MainActor.run { alertMessage = userFacingMessage(for: error) }
            }
            await MainActor.run { isTranslating = false }
        }
    }
    
    /// 从右边（印尼文）翻译到左边（中文）
    private func translateFromRight() {
        let trimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isTranslating = true

        Task {
            do {
                // 交换语言方向翻译
                let result = try await APIClient.shared.translate(
                    text: trimmed,
                    sourceLang: targetLang.speechCode,
                    targetLang: sourceLang.speechCode
                )
                let translated = result.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    sourceText = translated
                    history.insert(
                        TranslationEntry(
                            id: UUID().uuidString,
                            sourceText: trimmed,
                            targetText: result,
                            sourceLang: targetLang,
                            targetLang: sourceLang,
                            createdAt: Date()
                        ),
                        at: 0
                    )
                    SpeechService.shared.speak(translated, language: sourceLang.speechCode)
                }
            } catch {
                await MainActor.run { alertMessage = userFacingMessage(for: error) }
            }
            await MainActor.run { isTranslating = false }
        }
    }

    func toggleListening(side: ListeningSide) {
        if isListening {
            stopListening()
        } else {
            startListening(side: side)
        }
    }

    private func startListening(side: ListeningSide) {
        SpeechService.shared.stopSpeaking()
        autoStopWorkItem?.cancel()
        Task {
            let granted = await speechTranscriber.requestAuthorization()
            guard granted else {
                await MainActor.run { alertMessage = "未获得语音识别权限" }
                return
            }
            var startError: Error?
            await MainActor.run {
                do {
                    isListening = true
                    listeningSide = side
                    let language = side == .left ? sourceLang : targetLang
                    try speechTranscriber.startTranscribing(locale: Locale(identifier: language.speechCode)) { [weak self] text, isFinal in
                        Task { @MainActor in
                            guard let self else { return }
                            if !text.isEmpty {
                                if self.listeningSide == .left {
                                    self.sourceText = text
                                } else {
                                    self.translatedText = text
                                }
                                self.scheduleAutoStop()
                            }
                            if isFinal { self.stopListening() }
                        }
                    }
                } catch {
                    startError = error
                    isListening = false
                }
            }
            if let startError {
                await MainActor.run { alertMessage = startError.localizedDescription }
            }
        }
    }

    private func scheduleAutoStop() {
        autoStopWorkItem?.cancel()
        guard isListening else { return }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.isListening else { return }
                let text = self.listeningSide == .left 
                    ? self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                    : self.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { self.stopListening() }
            }
        }
        autoStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + silenceTimeout, execute: workItem)
    }

    private func stopListening() {
        guard isListening else { return }
        autoStopWorkItem?.cancel()
        speechTranscriber.stopTranscribing()
        isListening = false
        
        let text = listeningSide == .left
            ? sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            : translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !text.isEmpty {
            if let detected = detectedLanguage(from: text) {
                if listeningSide == .left {
                    sourceLang = detected
                    targetLang = detected == .chinese ? .indonesian : .chinese
                } else {
                    targetLang = detected
                    sourceLang = detected == .chinese ? .indonesian : .chinese
                }
            }
            translate()
        }
    }

    func playResult() {
        guard !translatedText.isEmpty else { return }
        SpeechService.shared.speak(translatedText, language: targetLang.speechCode)
    }

    func copyResult() {
        guard !translatedText.isEmpty else { return }
        ClipboardService.copy(translatedText)
    }
}

struct RealtimeTranslateEntry: Identifiable {
    let id = UUID()
    let indonesian: String
    let chinese: String
}

@MainActor
final class RealTimeTranslateViewModel: ObservableObject {
    @Published var entries: [RealtimeTranslateEntry] = []
    @Published var leftText: String = ""
    @Published var rightText: String = ""
    @Published var leftTranslated: String = ""
    @Published var rightTranslated: String = ""
    @Published var isLeftRecording = false
    @Published var isRightRecording = false
    @Published var isTranslating = false
    @Published var alertMessage: String?

    private let speechTranscriber = SpeechTranscriber()
    private var autoStopWorkItem: DispatchWorkItem?
    private let silenceTimeout: TimeInterval = 1.2

    func toggleLeft() {
        if isLeftRecording {
            stopRecording()
        } else {
            startRecording(locale: Locale(identifier: "id-ID"), isLeft: true)
        }
    }

    func toggleRight() {
        if isRightRecording {
            stopRecording()
        } else {
            startRecording(locale: Locale(identifier: "zh-CN"), isLeft: false)
        }
    }

    private func startRecording(locale: Locale, isLeft: Bool) {
        SpeechService.shared.stopSpeaking()
        autoStopWorkItem?.cancel()
        Task {
            let granted = await speechTranscriber.requestAuthorization()
            guard granted else {
                await MainActor.run { alertMessage = "未获得语音识别权限" }
                return
            }
            var startError: Error?
            await MainActor.run {
                do {
                    isLeftRecording = isLeft
                    isRightRecording = !isLeft
                    try speechTranscriber.startTranscribing(locale: locale) { [weak self] text, isFinal in
                        Task { @MainActor in
                            guard let self else { return }
                            if !text.isEmpty {
                                if isLeft { self.leftText = text }
                                else { self.rightText = text }
                                self.scheduleAutoStop()
                            }
                            if isFinal { self.stopRecording() }
                        }
                    }
                } catch {
                    startError = error
                    isLeftRecording = false
                    isRightRecording = false
                }
            }
            if let startError {
                await MainActor.run { alertMessage = startError.localizedDescription }
            }
        }
    }

    private func scheduleAutoStop() {
        autoStopWorkItem?.cancel()
        guard isLeftRecording || isRightRecording else { return }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.isLeftRecording || self.isRightRecording else { return }
                let src = self.isLeftRecording ? self.leftText : self.rightText
                if !src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.stopRecording()
                }
            }
        }
        autoStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + silenceTimeout, execute: workItem)
    }

    func stopRecording() {
        guard isLeftRecording || isRightRecording else { return }
        autoStopWorkItem?.cancel()
        let wasLeft = isLeftRecording
        speechTranscriber.stopTranscribing()
        isLeftRecording = false
        isRightRecording = false

        let source = wasLeft ? leftText.trimmingCharacters(in: .whitespacesAndNewlines)
                             : rightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }

        isTranslating = true
        Task {
            do {
                let result: String
                if wasLeft {
                    result = try await APIClient.shared.translate(text: source, sourceLang: "id-ID", targetLang: "zh-CN")
                    await MainActor.run {
                        rightTranslated = result
                        entries.append(RealtimeTranslateEntry(indonesian: source, chinese: result))
                        leftText = ""
                        rightTranslated = ""
                        SpeechService.shared.speak(result, language: "zh-CN")
                    }
                } else {
                    result = try await APIClient.shared.translate(text: source, sourceLang: "zh-CN", targetLang: "id-ID")
                    await MainActor.run {
                        leftTranslated = result
                        entries.append(RealtimeTranslateEntry(indonesian: result, chinese: source))
                        rightText = ""
                        leftTranslated = ""
                        SpeechService.shared.speak(result, language: "id-ID")
                    }
                }
            } catch {
                await MainActor.run { alertMessage = userFacingMessage(for: error) }
            }
            await MainActor.run { isTranslating = false }
        }
    }
}

@MainActor
final class LearningViewModel: ObservableObject {
    @Published var categories: [VocabCategory] = []
    @Published var selectedCategoryId: String?
    @Published var favoriteIds: Set<String> = []

    init() {
        categories = SampleData.vocabCategories
        selectedCategoryId = categories.first?.id
        loadFavorites()
        NotificationCenter.default.addObserver(forName: .clearLocalData, object: nil, queue: .main) { [weak self] _ in
            let viewModel = self
            Task { @MainActor in
                viewModel?.loadFavorites()
            }
        }
    }

    var filteredItems: [VocabItem] {
        guard let selectedCategoryId,
              let category = categories.first(where: { $0.id == selectedCategoryId }) else {
            return categories.flatMap { $0.items }
        }
        return category.items
    }

    func toggleFavorite(_ item: VocabItem) {
        if favoriteIds.contains(item.id) {
            favoriteIds.remove(item.id)
        } else {
            favoriteIds.insert(item.id)
        }
        saveFavorites()
    }

    func isFavorite(_ item: VocabItem) -> Bool {
        favoriteIds.contains(item.id)
    }

    func loadFavorites() {
        let stored = UserDefaults.standard.array(forKey: "favorite_vocab_ids") as? [String] ?? []
        favoriteIds = Set(stored)
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: "favorite_vocab_ids")
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var serviceStatus: String = "检测中..."
    @Published var lastCheck: String = "-"
    @Published var isReachable = false
    @Published var errorMessage: String?

    func refresh() async {
        do {
            let health = try await APIClient.shared.health()
            serviceStatus = "服务正常"
            lastCheck = health.time
            isReachable = true
            errorMessage = nil
        } catch {
            serviceStatus = "连接失败"
            lastCheck = Date().formatted(date: .numeric, time: .standard)
            isReachable = false
            errorMessage = error.localizedDescription
        }
    }
}

enum SampleData {
    static let vocabCategories: [VocabCategory] = [
        greetingCategory,
        travelCategory,
        foodCategory,
        emergencyCategory,
        ecommerceCategory,
        programmingCategory
    ]

    static var greetingCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "g1", textZh: "你好", textId: "Halo", exampleZh: "你好，很高兴认识你。", exampleId: "Halo, senang bertemu denganmu."),
            VocabItem(id: "g2", textZh: "早上好", textId: "Selamat pagi", exampleZh: "早上好，今天感觉如何？", exampleId: "Selamat pagi, apa kabar?"),
            VocabItem(id: "g3", textZh: "谢谢", textId: "Terima kasih", exampleZh: "谢谢你的帮助。", exampleId: "Terima kasih atas bantuanmu."),
            VocabItem(id: "g4", textZh: "不客气", textId: "Sama-sama", exampleZh: "不客气，这是我应该做的。", exampleId: "Sama-sama, ini sudah kewajiban saya."),
            VocabItem(id: "g5", textZh: "对不起", textId: "Maaf", exampleZh: "对不起，我迟到了。", exampleId: "Maaf, saya terlambat."),
            VocabItem(id: "g6", textZh: "没关系", textId: "Tidak apa-apa", exampleZh: "没关系，下次注意。", exampleId: "Tidak apa-apa, lain kali hati-hati."),
            VocabItem(id: "g7", textZh: "再见", textId: "Sampai jumpa", exampleZh: "再见，明天见。", exampleId: "Sampai jumpa, sampai besok."),
            VocabItem(id: "g8", textZh: "欢迎", textId: "Selamat datang", exampleZh: "欢迎来到我的城市。", exampleId: "Selamat datang di kota saya."),
            VocabItem(id: "g9", textZh: "请稍等", textId: "Mohon tunggu sebentar", exampleZh: "请稍等，我马上来。", exampleId: "Mohon tunggu sebentar, saya segera datang."),
            VocabItem(id: "g10", textZh: "祝你今天愉快", textId: "Semoga harimu menyenangkan", exampleZh: "祝你今天愉快！", exampleId: "Semoga harimu menyenangkan!"),
            VocabItem(id: "g11", textZh: "下午好", textId: "Selamat siang", exampleZh: "下午好，吃过午饭了吗？", exampleId: "Selamat siang, sudah makan siang?"),
            VocabItem(id: "g12", textZh: "晚上好", textId: "Selamat malam", exampleZh: "晚上好，今天忙吗？", exampleId: "Selamat malam, hari ini sibuk?"),
            VocabItem(id: "g13", textZh: "晚安", textId: "Selamat tidur", exampleZh: "晚安，做个好梦。", exampleId: "Selamat tidur, semoga mimpi indah."),
            VocabItem(id: "g14", textZh: "好久不见", textId: "Lama tidak bertemu", exampleZh: "好久不见，你最近怎么样？", exampleId: "Lama tidak bertemu, bagaimana kabarmu?"),
            VocabItem(id: "g15", textZh: "请问", textId: "Permisi", exampleZh: "请问洗手间在哪里？", exampleId: "Permisi, di mana toilet?"),
            VocabItem(id: "g16", textZh: "请多关照", textId: "Mohon bimbingannya", exampleZh: "我是新来的，请多关照。", exampleId: "Saya baru, mohon bimbingannya."),
            VocabItem(id: "g17", textZh: "幸会", textId: "Senang berkenalan", exampleZh: "幸会，久仰大名。", exampleId: "Senang berkenalan, sudah sering dengar nama Anda."),
            VocabItem(id: "g18", textZh: "打扰了", textId: "Maaf mengganggu", exampleZh: "打扰了，能帮个忙吗？", exampleId: "Maaf mengganggu, bisa bantu?"),
            VocabItem(id: "g19", textZh: "拜托了", textId: "Tolong ya", exampleZh: "这件事拜托你了。", exampleId: "Urusan ini saya serahkan kepadamu."),
            VocabItem(id: "g20", textZh: "辛苦了", textId: "Terima kasih atas kerja kerasnya", exampleZh: "大家辛苦了，休息一下吧。", exampleId: "Terima kasih atas kerja kerasnya, istirahat dulu."),
            VocabItem(id: "g21", textZh: "请进", textId: "Silakan masuk", exampleZh: "请进，不用脱鞋。", exampleId: "Silakan masuk, tidak usah lepas sepatu."),
            VocabItem(id: "g22", textZh: "请坐", textId: "Silakan duduk", exampleZh: "请坐，喝点什么？", exampleId: "Silakan duduk, mau minum apa?"),
            VocabItem(id: "g23", textZh: "慢走", textId: "Hati-hati di jalan", exampleZh: "慢走，路上注意安全。", exampleId: "Hati-hati di jalan, jaga keselamatan."),
            VocabItem(id: "g24", textZh: "保重", textId: "Jaga diri", exampleZh: "多保重身体。", exampleId: "Jaga kesehatan."),
            VocabItem(id: "g25", textZh: "一路顺风", textId: "Selamat jalan", exampleZh: "一路顺风，到了报个平安。", exampleId: "Selamat jalan, kabari kalau sudah sampai."),
            VocabItem(id: "g26", textZh: "恭喜", textId: "Selamat", exampleZh: "恭喜你考上大学！", exampleId: "Selamat kamu lulus ujian masuk universitas!"),
            VocabItem(id: "g27", textZh: "生日快乐", textId: "Selamat ulang tahun", exampleZh: "生日快乐，祝你健康快乐。", exampleId: "Selamat ulang tahun, semoga sehat dan bahagia."),
            VocabItem(id: "g28", textZh: "新年快乐", textId: "Selamat tahun baru", exampleZh: "新年快乐，万事如意。", exampleId: "Selamat tahun baru, semoga sukses."),
            VocabItem(id: "g29", textZh: "节日快乐", textId: "Selamat hari raya", exampleZh: "节日快乐，阖家幸福。", exampleId: "Selamat hari raya, keluarga bahagia."),
            VocabItem(id: "g30", textZh: "干杯", textId: "Bersulang", exampleZh: "来，大家干杯！", exampleId: "Ayo, bersulang!"),
            VocabItem(id: "g31", textZh: "请便", textId: "Silakan", exampleZh: "请便，别客气。", exampleId: "Silakan, jangan sungkan."),
            VocabItem(id: "g32", textZh: "不好意思", textId: "Malu", exampleZh: "不好意思，我来晚了。", exampleId: "Maaf, saya terlambat."),
            VocabItem(id: "g33", textZh: "非常感谢", textId: "Terima kasih banyak", exampleZh: "非常感谢你的热情款待。", exampleId: "Terima kasih banyak atas sambutannya."),
            VocabItem(id: "g34", textZh: "不用谢", textId: "Kembali", exampleZh: "不用谢，小事一桩。", exampleId: "Kembali, hal kecil."),
            VocabItem(id: "g35", textZh: "哪里哪里", textId: "Ah tidak", exampleZh: "哪里哪里，您过奖了。", exampleId: "Ah tidak, Anda terlalu memuji."),
            VocabItem(id: "g36", textZh: "久仰", textId: "Sudah lama mendengar", exampleZh: "久仰大名，今日得见。", exampleId: "Sudah lama mendengar nama Anda, akhirnya bertemu."),
            VocabItem(id: "g37", textZh: "失陪一下", textId: "Permisi sebentar", exampleZh: "失陪一下，我接个电话。", exampleId: "Permisi sebentar, saya terima telepon dulu."),
            VocabItem(id: "g38", textZh: "回头见", textId: "Sampai jumpa lagi", exampleZh: "回头见，有事联系。", exampleId: "Sampai jumpa lagi, hubungi kalau ada perlu."),
            VocabItem(id: "g39", textZh: "再会", textId: "Sampai bertemu lagi", exampleZh: "再会，期待下次见面。", exampleId: "Sampai bertemu lagi, sampai jumpa next time."),
            VocabItem(id: "g40", textZh: "告辞", textId: "Saya pamit", exampleZh: "时间不早了，我先告辞了。", exampleId: "Sudah larut, saya pamit dulu."),
            VocabItem(id: "g41", textZh: "留步", textId: "Tidak usah antar", exampleZh: "您留步，不用送了。", exampleId: "Tidak usah antar, cukup di sini."),
            VocabItem(id: "g42", textZh: "欢迎光临", textId: "Selamat datang", exampleZh: "欢迎光临，几位？", exampleId: "Selamat datang, berapa orang?"),
            VocabItem(id: "g43", textZh: "请慢用", textId: "Silakan dinikmati", exampleZh: "菜上齐了，请慢用。", exampleId: "Masakan sudah lengkap, silakan dinikmati."),
            VocabItem(id: "g44", textZh: "借过", textId: "Permisi", exampleZh: "借过一下，谢谢。", exampleId: "Permisi lewat, terima kasih."),
            VocabItem(id: "g45", textZh: "劳驾", textId: "Tolong", exampleZh: "劳驾，让一让。", exampleId: "Tolong, minggir sebentar."),
            VocabItem(id: "g46", textZh: "不好意思打扰", textId: "Maaf mengganggu", exampleZh: "不好意思打扰，请问现在几点？", exampleId: "Maaf mengganggu, jam berapa sekarang?"),
            VocabItem(id: "g47", textZh: "多谢", textId: "Makasih", exampleZh: "多谢帮忙。", exampleId: "Makasih sudah bantu."),
            VocabItem(id: "g48", textZh: "谢了", textId: "Thanks", exampleZh: "谢了兄弟。", exampleId: "Thanks bro."),
            VocabItem(id: "g49", textZh: "没事儿", textId: "Tidak apa-apa", exampleZh: "没事儿，别放在心上。", exampleId: "Tidak apa-apa, jangan dipikirkan."),
            VocabItem(id: "g50", textZh: "别见外", textId: "Jangan sungkan", exampleZh: "别见外，当自己家就行。", exampleId: "Jangan sungkan, anggap saja rumah sendiri.")
        ]
        return VocabCategory(id: "greeting", nameZh: "日常问候", nameId: "Sapaan", items: items)
    }

    static var travelCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "t1", textZh: "机场", textId: "Bandara", exampleZh: "机场怎么走？", exampleId: "Bagaimana ke bandara?"),
            VocabItem(id: "t2", textZh: "酒店", textId: "Hotel", exampleZh: "我已经预订了酒店。", exampleId: "Saya sudah memesan hotel."),
            VocabItem(id: "t3", textZh: "护照", textId: "Paspor", exampleZh: "我的护照不见了。", exampleId: "Paspor saya hilang."),
            VocabItem(id: "t4", textZh: "出租车", textId: "Taksi", exampleZh: "请帮我叫出租车。", exampleId: "Tolong panggilkan taksi."),
            VocabItem(id: "t5", textZh: "登机口", textId: "Pintu keberangkatan", exampleZh: "登机口在哪里？", exampleId: "Di mana pintu keberangkatan?"),
            VocabItem(id: "t6", textZh: "行李", textId: "Bagasi", exampleZh: "我的行李很重。", exampleId: "Bagasi saya berat."),
            VocabItem(id: "t7", textZh: "换汇", textId: "Tukar uang", exampleZh: "哪里可以换汇？", exampleId: "Di mana bisa tukar uang?"),
            VocabItem(id: "t8", textZh: "地图", textId: "Peta", exampleZh: "我需要一张地图。", exampleId: "Saya butuh peta."),
            VocabItem(id: "t9", textZh: "左转", textId: "Belok kiri", exampleZh: "前面左转。", exampleId: "Belok kiri di depan."),
            VocabItem(id: "t10", textZh: "右转", textId: "Belok kanan", exampleZh: "下一条路右转。", exampleId: "Belok kanan di jalan berikutnya."),
            VocabItem(id: "t11", textZh: "直走", textId: "Lurus saja", exampleZh: "直走两百米就到了。", exampleId: "Lurus saja dua ratus meter sampai."),
            VocabItem(id: "t12", textZh: "签证", textId: "Visa", exampleZh: "你的签证办好了吗？", exampleId: "Visa kamu sudah jadi?"),
            VocabItem(id: "t13", textZh: "登机牌", textId: "Boarding pass", exampleZh: "请出示登机牌。", exampleId: "Tolong tunjukkan boarding pass."),
            VocabItem(id: "t14", textZh: "行李托运", textId: "Check-in bagasi", exampleZh: "我要托运这件行李。", exampleId: "Saya mau check-in bagasi ini."),
            VocabItem(id: "t15", textZh: "海关", textId: "Bea cukai", exampleZh: "海关在出口那边。", exampleId: "Bea cukai di sebelah pintu keluar."),
            VocabItem(id: "t16", textZh: "兑换率", textId: "Kurs", exampleZh: "今天的兑换率是多少？", exampleId: "Kurs hari ini berapa?"),
            VocabItem(id: "t17", textZh: "单程票", textId: "Tiket sekali jalan", exampleZh: "我买一张单程票。", exampleId: "Saya beli satu tiket sekali jalan."),
            VocabItem(id: "t18", textZh: "往返票", textId: "Tiket pulang pergi", exampleZh: "往返票便宜一些。", exampleId: "Tiket pulang pergi lebih murah."),
            VocabItem(id: "t19", textZh: "预订", textId: "Reservasi", exampleZh: "我想预订一间双人房。", exampleId: "Saya mau reservasi satu kamar double."),
            VocabItem(id: "t20", textZh: "退房", textId: "Check-out", exampleZh: "明天早上退房。", exampleId: "Besok pagi check-out."),
            VocabItem(id: "t21", textZh: "房卡", textId: "Kartu kamar", exampleZh: "我的房卡丢了。", exampleId: "Kartu kamar saya hilang."),
            VocabItem(id: "t22", textZh: "叫醒服务", textId: "Bangun pagi", exampleZh: "请明天六点叫醒我。", exampleId: "Tolong bangunkan saya jam enam besok."),
            VocabItem(id: "t23", textZh: "租车", textId: "Sewa mobil", exampleZh: "这里可以租车吗？", exampleId: "Di sini bisa sewa mobil?"),
            VocabItem(id: "t24", textZh: "加油站", textId: "SPBU", exampleZh: "前面有加油站吗？", exampleId: "Di depan ada SPBU?"),
            VocabItem(id: "t25", textZh: "堵车", textId: "Macet", exampleZh: "现在堵车，可能晚到。", exampleId: "Sekarang macet, mungkin terlambat."),
            VocabItem(id: "t26", textZh: "地铁", textId: "MRT / Kereta bawah tanah", exampleZh: "坐地铁比较快。", exampleId: "Naik MRT lebih cepat."),
            VocabItem(id: "t27", textZh: "公交", textId: "Bus", exampleZh: "这路公交到市中心吗？", exampleId: "Bus ini ke pusat kota?"),
            VocabItem(id: "t28", textZh: "售票处", textId: "Loket tiket", exampleZh: "售票处在那边。", exampleId: "Loket tiket di sana."),
            VocabItem(id: "t29", textZh: "候车室", textId: "Ruang tunggu", exampleZh: "请在候车室等候。", exampleId: "Mohon tunggu di ruang tunggu."),
            VocabItem(id: "t30", textZh: "行李架", textId: "Rak bagasi", exampleZh: "行李放行李架上吧。", exampleId: "Taruh bagasi di rak."),
            VocabItem(id: "t31", textZh: "晕车", textId: "Mabuk perjalanan", exampleZh: "我有点晕车。", exampleId: "Saya agak mabuk."),
            VocabItem(id: "t32", textZh: "景点", textId: "Tempat wisata", exampleZh: "附近有什么景点？", exampleId: "Di dekat sini ada tempat wisata apa?"),
            VocabItem(id: "t33", textZh: "门票", textId: "Tiket masuk", exampleZh: "门票多少钱一张？", exampleId: "Tiket masuk berapa per orang?"),
            VocabItem(id: "t34", textZh: "导游", textId: "Pemandu wisata", exampleZh: "我们需要一位中文导游。", exampleId: "Kami butuh pemandu bahasa Mandarin."),
            VocabItem(id: "t35", textZh: "防晒", textId: "Tabir surya", exampleZh: "别忘了涂防晒。", exampleId: "Jangan lupa pakai tabir surya."),
            VocabItem(id: "t36", textZh: "插座", textId: "Stop kontak", exampleZh: "房间里有插座吗？", exampleId: "Di kamar ada stop kontak?"),
            VocabItem(id: "t37", textZh: "Wi-Fi", textId: "Wi-Fi", exampleZh: "这里的 Wi-Fi 密码是多少？", exampleId: "Password Wi-Fi di sini berapa?"),
            VocabItem(id: "t38", textZh: "空调", textId: "AC", exampleZh: "能把空调开大一点吗？", exampleId: "Bisa besarkan AC?"),
            VocabItem(id: "t39", textZh: "热水", textId: "Air panas", exampleZh: "有热水吗？", exampleId: "Ada air panas?"),
            VocabItem(id: "t40", textZh: "保险", textId: "Asuransi", exampleZh: "我买了旅游保险。", exampleId: "Saya beli asuransi perjalanan."),
            VocabItem(id: "t41", textZh: "急救箱", textId: "Kotak P3K", exampleZh: "车上有急救箱吗？", exampleId: "Di mobil ada kotak P3K?"),
            VocabItem(id: "t42", textZh: "时差", textId: "Perbedaan waktu", exampleZh: "我们和雅加达有一小时时差。", exampleId: "Kita beda satu jam dengan Jakarta."),
            VocabItem(id: "t43", textZh: "转机", textId: "Transit", exampleZh: "我在新加坡转机。", exampleId: "Saya transit di Singapura."),
            VocabItem(id: "t44", textZh: "延误", textId: "Terlambat", exampleZh: "航班延误了两小时。", exampleId: "Penerbangan terlambat dua jam."),
            VocabItem(id: "t45", textZh: "取消", textId: "Dibatalkan", exampleZh: "航班被取消了。", exampleId: "Penerbangan dibatalkan."),
            VocabItem(id: "t46", textZh: "改签", textId: "Ubah jadwal", exampleZh: "我想改签明天的航班。", exampleId: "Saya mau ubah jadwal ke penerbangan besok."),
            VocabItem(id: "t47", textZh: "靠窗座位", textId: "Tempat duduk jendela", exampleZh: "我想要靠窗的座位。", exampleId: "Saya mau tempat duduk jendela."),
            VocabItem(id: "t48", textZh: "过道座位", textId: "Tempat duduk lorong", exampleZh: "过道座位方便走动。", exampleId: "Tempat duduk lorong lebih enak untuk jalan."),
            VocabItem(id: "t49", textZh: "入境卡", textId: "Kartu masuk", exampleZh: "请填写入境卡。", exampleId: "Mohon isi kartu masuk."),
            VocabItem(id: "t50", textZh: "免税店", textId: "Toko bebas bea", exampleZh: "机场免税店几点关门？", exampleId: "Toko bebas bea bandara tutup jam berapa?")
        ]
        return VocabCategory(id: "travel", nameZh: "旅行必备", nameId: "Perjalanan", items: items)
    }

    static var foodCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "f1", textZh: "多少钱", textId: "Berapa harga", exampleZh: "这个多少钱？", exampleId: "Berapa harga ini?"),
            VocabItem(id: "f2", textZh: "菜单", textId: "Menu", exampleZh: "可以给我菜单吗？", exampleId: "Bisa minta menunya?"),
            VocabItem(id: "f3", textZh: "咖啡", textId: "Kopi", exampleZh: "我想要一杯咖啡。", exampleId: "Saya mau kopi."),
            VocabItem(id: "f4", textZh: "打包", textId: "Bungkus", exampleZh: "可以打包吗？", exampleId: "Bisa bungkus?"),
            VocabItem(id: "f5", textZh: "买单", textId: "Bayar", exampleZh: "请帮我买单。", exampleId: "Tolong saya mau bayar."),
            VocabItem(id: "f6", textZh: "少糖", textId: "Kurang gula", exampleZh: "饮料少糖。", exampleId: "Minumannya kurang gula."),
            VocabItem(id: "f7", textZh: "辣", textId: "Pedas", exampleZh: "我不吃太辣。", exampleId: "Saya tidak makan terlalu pedas."),
            VocabItem(id: "f8", textZh: "素食", textId: "Vegetarian", exampleZh: "我吃素食。", exampleId: "Saya vegetarian."),
            VocabItem(id: "f9", textZh: "收据", textId: "Struk", exampleZh: "可以给我收据吗？", exampleId: "Bisa minta struk?"),
            VocabItem(id: "f10", textZh: "打折", textId: "Diskon", exampleZh: "今天有打折吗？", exampleId: "Hari ini ada diskon?"),
            VocabItem(id: "f11", textZh: "点菜", textId: "Pesan makanan", exampleZh: "我们开始点菜吧。", exampleId: "Kita pesan makanan yuk."),
            VocabItem(id: "f12", textZh: "推荐", textId: "Rekomendasi", exampleZh: "有什么推荐的吗？", exampleId: "Ada rekomendasi?"),
            VocabItem(id: "f13", textZh: "招牌菜", textId: "Menu andalan", exampleZh: "招牌菜来一份。", exampleId: "Satu porsi menu andalan."),
            VocabItem(id: "f14", textZh: "不要辣", textId: "Tidak pedas", exampleZh: "这份不要辣。", exampleId: "Ini jangan pedas."),
            VocabItem(id: "f15", textZh: "加冰", textId: "Pakai es", exampleZh: "饮料加冰。", exampleId: "Minumannya pakai es."),
            VocabItem(id: "f16", textZh: "去冰", textId: "Tanpa es", exampleZh: "我去冰，谢谢。", exampleId: "Tanpa es, terima kasih."),
            VocabItem(id: "f17", textZh: "筷子", textId: "Sumpit", exampleZh: "请给我一双筷子。", exampleId: "Tolong beri saya sumpit."),
            VocabItem(id: "f18", textZh: "勺子", textId: "Sendok", exampleZh: "再要一个勺子。", exampleId: "Minta satu sendok lagi."),
            VocabItem(id: "f19", textZh: "餐巾纸", textId: "Tisu", exampleZh: "麻烦拿点餐巾纸。", exampleId: "Tolong ambilkan tisu."),
            VocabItem(id: "f20", textZh: "开水", textId: "Air putih panas", exampleZh: "有开水吗？", exampleId: "Ada air putih panas?"),
            VocabItem(id: "f21", textZh: "结账", textId: "Bayar bill", exampleZh: "我们结账吧。", exampleId: "Kita bayar bill yuk."),
            VocabItem(id: "f22", textZh: "分开付", textId: "Bayar sendiri-sendiri", exampleZh: "我们分开付。", exampleId: "Kita bayar sendiri-sendiri."),
            VocabItem(id: "f23", textZh: "刷卡", textId: "Bayar kartu", exampleZh: "可以刷卡吗？", exampleId: "Bisa bayar pakai kartu?"),
            VocabItem(id: "f24", textZh: "找零", textId: "Kembalian", exampleZh: "不用找零了。", exampleId: "Kembaliannya tidak usah."),
            VocabItem(id: "f25", textZh: "太咸", textId: "Terlalu asin", exampleZh: "这道菜太咸了。", exampleId: "Masakan ini terlalu asin."),
            VocabItem(id: "f26", textZh: "太甜", textId: "Terlalu manis", exampleZh: "饮料太甜了。", exampleId: "Minumannya terlalu manis."),
            VocabItem(id: "f27", textZh: "好吃", textId: "Enak", exampleZh: "这个真好吃。", exampleId: "Ini enak banget."),
            VocabItem(id: "f28", textZh: "吃饱了", textId: "Kenyang", exampleZh: "我吃饱了。", exampleId: "Saya sudah kenyang."),
            VocabItem(id: "f29", textZh: "再来一份", textId: "Tambah satu porsi", exampleZh: "这个再来一份。", exampleId: "Ini tambah satu porsi."),
            VocabItem(id: "f30", textZh: "打包盒", textId: "Kotak bungkus", exampleZh: "需要打包盒吗？", exampleId: "Perlu kotak bungkus?"),
            VocabItem(id: "f31", textZh: "叉子", textId: "Garpu", exampleZh: "给我一把叉子。", exampleId: "Beri saya garpu."),
            VocabItem(id: "f32", textZh: "刀", textId: "Pisau", exampleZh: "请问有刀吗？", exampleId: "Ada pisau?"),
            VocabItem(id: "f33", textZh: "盘子", textId: "Piring", exampleZh: "盘子脏了，换一个。", exampleId: "Piringnya kotor, ganti satu."),
            VocabItem(id: "f34", textZh: "杯子", textId: "Gelas", exampleZh: "再拿一个杯子。", exampleId: "Ambil satu gelas lagi."),
            VocabItem(id: "f35", textZh: "吸管", textId: "Sedotan", exampleZh: "要一根吸管。", exampleId: "Minta satu sedotan."),
            VocabItem(id: "f36", textZh: "米饭", textId: "Nasi", exampleZh: "加一碗米饭。", exampleId: "Tambah satu piring nasi."),
            VocabItem(id: "f37", textZh: "面条", textId: "Mie", exampleZh: "我要一碗牛肉面。", exampleId: "Saya mau satu mangkuk mie sapi."),
            VocabItem(id: "f38", textZh: "汤", textId: "Sup", exampleZh: "今天的汤是什么？", exampleId: "Sup hari ini apa?"),
            VocabItem(id: "f39", textZh: "沙拉", textId: "Salad", exampleZh: "来一份蔬菜沙拉。", exampleId: "Satu porsi salad sayur."),
            VocabItem(id: "f40", textZh: "甜点", textId: "Hidangan penutup", exampleZh: "有什么甜点？", exampleId: "Ada hidangan penutup apa?"),
            VocabItem(id: "f41", textZh: "啤酒", textId: "Bir", exampleZh: "来两瓶啤酒。", exampleId: "Dua botol bir."),
            VocabItem(id: "f42", textZh: "茶", textId: "Teh", exampleZh: "一壶绿茶。", exampleId: "Satu teko teh hijau."),
            VocabItem(id: "f43", textZh: "果汁", textId: "Jus", exampleZh: "鲜榨果汁有吗？", exampleId: "Ada jus segar?"),
            VocabItem(id: "f44", textZh: "矿泉水", textId: "Air mineral", exampleZh: "一瓶矿泉水。", exampleId: "Satu botol air mineral."),
            VocabItem(id: "f45", textZh: "小费", textId: "Tip", exampleZh: "小费包含在账单里吗？", exampleId: "Tip sudah termasuk di bill?"),
            VocabItem(id: "f46", textZh: "预订座位", textId: "Reservasi meja", exampleZh: "我想预订今晚七点的座位。", exampleId: "Saya mau reservasi meja jam tujuh malam."),
            VocabItem(id: "f47", textZh: "几位", textId: "Berapa orang", exampleZh: "请问几位？", exampleId: "Berapa orang?"),
            VocabItem(id: "f48", textZh: "靠窗", textId: "Dekat jendela", exampleZh: "有靠窗的位子吗？", exampleId: "Ada tempat duduk dekat jendela?"),
            VocabItem(id: "f49", textZh: "过敏", textId: "Alergi", exampleZh: "我对花生过敏。", exampleId: "Saya alergi kacang."),
            VocabItem(id: "f50", textZh: "忌口", textId: "Pantang", exampleZh: "我忌辣。", exampleId: "Saya pantang pedas.")
        ]
        return VocabCategory(id: "food", nameZh: "购物点餐", nameId: "Belanja & Pesan", items: items)
    }

    static var emergencyCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "e1", textZh: "帮助", textId: "Tolong", exampleZh: "请帮帮我。", exampleId: "Tolong saya."),
            VocabItem(id: "e2", textZh: "医生", textId: "Dokter", exampleZh: "我需要医生。", exampleId: "Saya butuh dokter."),
            VocabItem(id: "e3", textZh: "警察", textId: "Polisi", exampleZh: "我要报警。", exampleId: "Saya mau lapor polisi."),
            VocabItem(id: "e4", textZh: "医院", textId: "Rumah sakit", exampleZh: "最近的医院在哪里？", exampleId: "Di mana rumah sakit terdekat?"),
            VocabItem(id: "e5", textZh: "急救", textId: "Pertolongan pertama", exampleZh: "我需要急救。", exampleId: "Saya butuh pertolongan pertama."),
            VocabItem(id: "e6", textZh: "报警", textId: "Laporkan", exampleZh: "我需要报警。", exampleId: "Saya perlu melapor."),
            VocabItem(id: "e7", textZh: "迷路", textId: "Tersesat", exampleZh: "我迷路了。", exampleId: "Saya tersesat."),
            VocabItem(id: "e8", textZh: "危险", textId: "Berbahaya", exampleZh: "这里很危险。", exampleId: "Di sini berbahaya."),
            VocabItem(id: "e9", textZh: "受伤", textId: "Terluka", exampleZh: "我受伤了。", exampleId: "Saya terluka."),
            VocabItem(id: "e10", textZh: "救护车", textId: "Ambulans", exampleZh: "请叫救护车。", exampleId: "Tolong panggil ambulans."),
            VocabItem(id: "e11", textZh: "着火", textId: "Kebakaran", exampleZh: "着火了，快跑！", exampleId: "Kebakaran, lari!"),
            VocabItem(id: "e12", textZh: "地震", textId: "Gempa", exampleZh: "地震了，找掩护。", exampleId: "Gempa, cari perlindungan."),
            VocabItem(id: "e13", textZh: "流血", textId: "Berdarah", exampleZh: "他在流血。", exampleId: "Dia berdarah."),
            VocabItem(id: "e14", textZh: "发烧", textId: "Demam", exampleZh: "我发烧了，很难受。", exampleId: "Saya demam, tidak enak badan."),
            VocabItem(id: "e15", textZh: "头疼", textId: "Sakit kepala", exampleZh: "我头疼得厉害。", exampleId: "Kepala saya sakit sekali."),
            VocabItem(id: "e16", textZh: "肚子疼", textId: "Sakit perut", exampleZh: "我肚子疼。", exampleId: "Saya sakit perut."),
            VocabItem(id: "e17", textZh: "过敏", textId: "Alergi", exampleZh: "他过敏了，需要药。", exampleId: "Dia alergi, butuh obat."),
            VocabItem(id: "e18", textZh: "药", textId: "Obat", exampleZh: "附近有药店吗？", exampleId: "Di dekat sini ada apotek?"),
            VocabItem(id: "e19", textZh: "失窃", textId: "Kecurian", exampleZh: "我的包被偷了。", exampleId: "Tas saya dicuri."),
            VocabItem(id: "e20", textZh: "走失", textId: "Hilang", exampleZh: "孩子走失了，请帮忙找。", exampleId: "Anak hilang, tolong bantu cari."),
            VocabItem(id: "e21", textZh: "紧急出口", textId: "Pintu darurat", exampleZh: "紧急出口在那边。", exampleId: "Pintu darurat di sana."),
            VocabItem(id: "e22", textZh: "灭火器", textId: "Alat pemadam kebakaran", exampleZh: "灭火器在墙上。", exampleId: "Alat pemadam di dinding."),
            VocabItem(id: "e23", textZh: "呼吸困难", textId: "Sulit bernapas", exampleZh: "我呼吸困难。", exampleId: "Saya sulit bernapas."),
            VocabItem(id: "e24", textZh: "晕倒", textId: "Pingsan", exampleZh: "有人晕倒了。", exampleId: "Ada yang pingsan."),
            VocabItem(id: "e25", textZh: "骨折", textId: "Patah tulang", exampleZh: "可能骨折了，别动。", exampleId: "Mungkin patah tulang, jangan gerak."),
            VocabItem(id: "e26", textZh: "烫伤", textId: "Luka bakar", exampleZh: "小心烫伤。", exampleId: "Hati-hati luka bakar."),
            VocabItem(id: "e27", textZh: "溺水", textId: "Tenggelam", exampleZh: "有人溺水了！", exampleId: "Ada yang tenggelam!"),
            VocabItem(id: "e28", textZh: "蛇咬", textId: "Digigit ular", exampleZh: "他被蛇咬了。", exampleId: "Dia digigit ular."),
            VocabItem(id: "e29", textZh: "中毒", textId: "Keracunan", exampleZh: "可能是食物中毒。", exampleId: "Mungkin keracunan makanan."),
            VocabItem(id: "e30", textZh: "大使馆", textId: "Kedutaan", exampleZh: "中国大使馆在哪里？", exampleId: "Di mana Kedutaan Cina?"),
            VocabItem(id: "e31", textZh: "护照丢了", textId: "Paspor hilang", exampleZh: "我的护照丢了。", exampleId: "Paspor saya hilang."),
            VocabItem(id: "e32", textZh: "钱包丢了", textId: "Dompet hilang", exampleZh: "我的钱包丢了。", exampleId: "Dompet saya hilang."),
            VocabItem(id: "e33", textZh: "手机丢了", textId: "HP hilang", exampleZh: "我手机丢了，能借你的用一下吗？", exampleId: "HP saya hilang, bisa pinjam?"),
            VocabItem(id: "e34", textZh: "车祸", textId: "Kecelakaan", exampleZh: "前面发生车祸了。", exampleId: "Di depan ada kecelakaan."),
            VocabItem(id: "e35", textZh: "停电", textId: "Listrik padam", exampleZh: "停电了，有手电吗？", exampleId: "Listrik padam, ada senter?"),
            VocabItem(id: "e36", textZh: "停水", textId: "Air mati", exampleZh: "停水了。", exampleId: "Air mati."),
            VocabItem(id: "e37", textZh: "漏水", textId: "Kebocoran", exampleZh: "楼上漏水了。", exampleId: "Lantai atas bocor."),
            VocabItem(id: "e38", textZh: "煤气泄漏", textId: "Kebocoran gas", exampleZh: "可能有煤气泄漏，别开灯。", exampleId: "Mungkin ada kebocoran gas, jangan nyalakan lampu."),
            VocabItem(id: "e39", textZh: "紧急联系人", textId: "Kontak darurat", exampleZh: "请帮我联系紧急联系人。", exampleId: "Tolong hubungi kontak darurat saya."),
            VocabItem(id: "e40", textZh: "血型", textId: "Golongan darah", exampleZh: "我的是 A 型血。", exampleId: "Golongan darah saya A."),
            VocabItem(id: "e41", textZh: "慢性病", textId: "Penyakit kronis", exampleZh: "我有慢性病，需要定期吃药。", exampleId: "Saya punya penyakit kronis, harus minum obat teratur."),
            VocabItem(id: "e42", textZh: "急救电话", textId: "Nomor darurat", exampleZh: "印尼急救电话是多少？", exampleId: "Nomor darurat Indonesia berapa?"),
            VocabItem(id: "e43", textZh: "疏散", textId: "Evakuasi", exampleZh: "请大家有序疏散。", exampleId: "Mohon evakuasi dengan tertib."),
            VocabItem(id: "e44", textZh: "安全区", textId: "Zona aman", exampleZh: "请到安全区集合。", exampleId: "Mohon berkumpul di zona aman."),
            VocabItem(id: "e45", textZh: "伤口", textId: "Luka", exampleZh: "伤口需要消毒。", exampleId: "Luka perlu disinfeksi."),
            VocabItem(id: "e46", textZh: "绷带", textId: "Perban", exampleZh: "有绷带吗？", exampleId: "Ada perban?"),
            VocabItem(id: "e47", textZh: "创可贴", textId: "Plaster", exampleZh: "给我一个创可贴。", exampleId: "Beri saya satu plaster."),
            VocabItem(id: "e48", textZh: "晕车药", textId: "Obat mabuk", exampleZh: "你有晕车药吗？", exampleId: "Kamu punya obat mabuk?"),
            VocabItem(id: "e49", textZh: "退烧药", textId: "Obat penurun demam", exampleZh: "我需要退烧药。", exampleId: "Saya butuh obat penurun demam."),
            VocabItem(id: "e50", textZh: "止泻药", textId: "Obat diare", exampleZh: "有止泻药吗？", exampleId: "Ada obat diare?")
        ]
        return VocabCategory(id: "emergency", nameZh: "紧急沟通", nameId: "Darurat", items: items)
    }

    static var ecommerceCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "ec1", textZh: "订单", textId: "Pesanan", exampleZh: "我的订单在哪里查看？", exampleId: "Di mana saya bisa melihat pesanan?"),
            VocabItem(id: "ec2", textZh: "物流", textId: "Pengiriman", exampleZh: "物流信息更新了吗？", exampleId: "Apakah informasi pengiriman sudah diperbarui?"),
            VocabItem(id: "ec3", textZh: "退款", textId: "Pengembalian dana", exampleZh: "我想申请退款。", exampleId: "Saya ingin mengajukan pengembalian dana."),
            VocabItem(id: "ec4", textZh: "客服", textId: "Layanan pelanggan", exampleZh: "请帮我联系在线客服。", exampleId: "Tolong hubungkan saya dengan layanan pelanggan."),
            VocabItem(id: "ec5", textZh: "下单", textId: "Buat pesanan", exampleZh: "我现在下单。", exampleId: "Saya buat pesanan sekarang."),
            VocabItem(id: "ec6", textZh: "库存", textId: "Stok", exampleZh: "这个商品还有库存吗？", exampleId: "Apakah produk ini masih ada stok?"),
            VocabItem(id: "ec7", textZh: "优惠券", textId: "Kupon", exampleZh: "我有一张优惠券。", exampleId: "Saya punya kupon."),
            VocabItem(id: "ec8", textZh: "包邮", textId: "Gratis ongkir", exampleZh: "这件商品包邮吗？", exampleId: "Apakah produk ini gratis ongkir?"),
            VocabItem(id: "ec9", textZh: "评价", textId: "Ulasan", exampleZh: "我想写一条评价。", exampleId: "Saya ingin menulis ulasan."),
            VocabItem(id: "ec10", textZh: "售后", textId: "Layanan purna jual", exampleZh: "我需要售后支持。", exampleId: "Saya butuh layanan purna jual."),
            VocabItem(id: "ec11", textZh: "加入购物车", textId: "Tambah ke keranjang", exampleZh: "先加入购物车。", exampleId: "Tambah ke keranjang dulu."),
            VocabItem(id: "ec12", textZh: "立即购买", textId: "Beli sekarang", exampleZh: "我选择立即购买。", exampleId: "Saya pilih beli sekarang."),
            VocabItem(id: "ec13", textZh: "运费", textId: "Ongkos kirim", exampleZh: "运费怎么算？", exampleId: "Ongkos kirim bagaimana hitungnya?"),
            VocabItem(id: "ec14", textZh: "预计送达", textId: "Perkiraan tiba", exampleZh: "预计什么时候送达？", exampleId: "Perkiraan kapan tiba?"),
            VocabItem(id: "ec15", textZh: "确认收货", textId: "Konfirmasi terima", exampleZh: "收到货后请确认收货。", exampleId: "Setelah terima, mohon konfirmasi."),
            VocabItem(id: "ec16", textZh: "换货", textId: "Tukar barang", exampleZh: "我想换货，尺寸不对。", exampleId: "Saya mau tukar barang, ukurannya salah."),
            VocabItem(id: "ec17", textZh: "退货", textId: "Pengembalian", exampleZh: "七天无理由退货。", exampleId: "Pengembalian 7 hari tanpa alasan."),
            VocabItem(id: "ec18", textZh: "发票", textId: "Faktur", exampleZh: "可以开发票吗？", exampleId: "Bisa buat faktur?"),
            VocabItem(id: "ec19", textZh: "秒杀", textId: "Flash sale", exampleZh: "今晚八点秒杀。", exampleId: "Flash sale jam delapan malam."),
            VocabItem(id: "ec20", textZh: "预售", textId: "Pre-order", exampleZh: "这是预售商品。", exampleId: "Ini barang pre-order."),
            VocabItem(id: "ec21", textZh: "限购", textId: "Batas beli", exampleZh: "每人限购两件。", exampleId: "Maksimal dua per orang."),
            VocabItem(id: "ec22", textZh: "缺货", textId: "Habis", exampleZh: "这款暂时缺货。", exampleId: "Model ini sedang habis."),
            VocabItem(id: "ec23", textZh: "到货通知", textId: "Notifikasi stok", exampleZh: "到货了会通知我吗？", exampleId: "Kalau sudah ada stok akan diberitahu?"),
            VocabItem(id: "ec24", textZh: "规格", textId: "Spesifikasi", exampleZh: "请选规格和颜色。", exampleId: "Mohon pilih spesifikasi dan warna."),
            VocabItem(id: "ec25", textZh: "尺码", textId: "Ukuran", exampleZh: "尺码偏大还是偏小？", exampleId: "Ukurannya besar atau kecil?"),
            VocabItem(id: "ec26", textZh: "实拍", textId: "Foto asli", exampleZh: "这是实拍图。", exampleId: "Ini foto asli."),
            VocabItem(id: "ec27", textZh: "正品", textId: "Orisinil", exampleZh: "保证正品。", exampleId: "Dijamin orisinil."),
            VocabItem(id: "ec28", textZh: "假一赔十", textId: "Ganti 10 jika palsu", exampleZh: "假一赔十。", exampleId: "Kalau palsu ganti 10."),
            VocabItem(id: "ec29", textZh: "包退换", textId: "Bisa tukar/return", exampleZh: "支持包退换。", exampleId: "Bisa tukar atau return."),
            VocabItem(id: "ec30", textZh: "凑单", textId: "Gabung pesanan", exampleZh: "再买一点凑单免运费。", exampleId: "Beli lagi sedikit biar gratis ongkir."),
            VocabItem(id: "ec31", textZh: "满减", textId: "Potongan belanja", exampleZh: "满 200 减 30。", exampleId: "Beli 200 potong 30."),
            VocabItem(id: "ec32", textZh: "会员价", textId: "Harga member", exampleZh: "会员价更便宜。", exampleId: "Harga member lebih murah."),
            VocabItem(id: "ec33", textZh: "收藏", textId: "Favorit", exampleZh: "我收藏了这家店。", exampleId: "Saya sudah favorit toko ini."),
            VocabItem(id: "ec34", textZh: "关注", textId: "Follow", exampleZh: "关注店铺领券。", exampleId: "Follow toko dapat kupon."),
            VocabItem(id: "ec35", textZh: "直播", textId: "Live", exampleZh: "今晚有直播。", exampleId: "Malam ini ada live."),
            VocabItem(id: "ec36", textZh: "拼团", textId: "Group buy", exampleZh: "三人拼团更便宜。", exampleId: "Group buy tiga orang lebih murah."),
            VocabItem(id: "ec37", textZh: "砍价", textId: "Tawar harga", exampleZh: "帮我也砍一刀。", exampleId: "Bantu saya tawar juga."),
            VocabItem(id: "ec38", textZh: "快递", textId: "Kurir", exampleZh: "发什么快递？", exampleId: "Pakai kurir apa?"),
            VocabItem(id: "ec39", textZh: "自提", textId: "Ambil sendiri", exampleZh: "支持门店自提。", exampleId: "Bisa ambil sendiri di toko."),
            VocabItem(id: "ec40", textZh: "配送", textId: "Pengantaran", exampleZh: "配送到家。", exampleId: "Antar ke rumah."),
            VocabItem(id: "ec41", textZh: "签收", textId: "Tanda terima", exampleZh: "请本人签收。", exampleId: "Mohon tanda terima sendiri."),
            VocabItem(id: "ec42", textZh: "破损", textId: "Rusak", exampleZh: "收到时外箱破损。", exampleId: "Saat terima kardus rusak."),
            VocabItem(id: "ec43", textZh: "漏发", textId: "Kurang kirim", exampleZh: "少发了一件。", exampleId: "Kurang kirim satu."),
            VocabItem(id: "ec44", textZh: "发错货", textId: "Salah kirim", exampleZh: "发错货了，我要的是 M 码。", exampleId: "Salah kirim, saya pesan ukuran M."),
            VocabItem(id: "ec45", textZh: "差评", textId: "Ulasan buruk", exampleZh: "商品有问题只能给差评。", exampleId: "Barang bermasalah terpaksa ulasan buruk."),
            VocabItem(id: "ec46", textZh: "好评", textId: "Ulasan bagus", exampleZh: "东西不错，给好评。", exampleId: "Barang oke, kasih ulasan bagus."),
            VocabItem(id: "ec47", textZh: "晒单", textId: "Share pembelian", exampleZh: "晒单有奖。", exampleId: "Share pembelian dapat hadiah."),
            VocabItem(id: "ec48", textZh: "店铺", textId: "Toko", exampleZh: "进店铺看看其他款。", exampleId: "Masuk toko lihat model lain."),
            VocabItem(id: "ec49", textZh: "销量", textId: "Penjualan", exampleZh: "这款销量很高。", exampleId: "Model ini laris."),
            VocabItem(id: "ec50", textZh: "定金", textId: "DP", exampleZh: "预付定金，尾款稍后付。", exampleId: "Bayar DP dulu, sisanya nanti.")
        ]
        return VocabCategory(id: "ecommerce", nameZh: "电商场景", nameId: "E-commerce", items: items)
    }

    static var programmingCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "p1", textZh: "变量", textId: "Variabel", exampleZh: "给变量赋一个初始值。", exampleId: "Berikan nilai awal ke variabel."),
            VocabItem(id: "p2", textZh: "函数", textId: "Fungsi", exampleZh: "这个函数返回一个字符串。", exampleId: "Fungsi ini mengembalikan sebuah string."),
            VocabItem(id: "p3", textZh: "循环", textId: "Loop", exampleZh: "用 for 循环遍历数组中的每个元素。", exampleId: "Gunakan loop for untuk mengiterasi setiap elemen array."),
            VocabItem(id: "p4", textZh: "数组", textId: "Array", exampleZh: "创建一个空数组。", exampleId: "Buat array kosong."),
            VocabItem(id: "p5", textZh: "字符串", textId: "String", exampleZh: "字符串需要加引号。", exampleId: "String harus diberi tanda kutip."),
            VocabItem(id: "p6", textZh: "条件判断", textId: "Kondisi", exampleZh: "用 if 做条件判断。", exampleId: "Gunakan if untuk pengecekan kondisi."),
            VocabItem(id: "p7", textZh: "类", textId: "Kelas", exampleZh: "定义一个类，包含属性和方法。", exampleId: "Definisikan kelas dengan properti dan metode."),
            VocabItem(id: "p8", textZh: "对象", textId: "Objek", exampleZh: "实例化一个对象。", exampleId: "Instansiasi sebuah objek."),
            VocabItem(id: "p9", textZh: "参数", textId: "Parameter", exampleZh: "函数接收两个参数。", exampleId: "Fungsi menerima dua parameter."),
            VocabItem(id: "p10", textZh: "返回值", textId: "Nilai return", exampleZh: "函数的返回值类型是整数。", exampleId: "Tipe nilai return fungsi adalah integer."),
            VocabItem(id: "p11", textZh: "调试", textId: "Debug", exampleZh: "在断点处停下来调试。", exampleId: "Berhenti di breakpoint untuk debug."),
            VocabItem(id: "p12", textZh: "接口", textId: "Interface", exampleZh: "这个类实现了该接口。", exampleId: "Kelas ini mengimplementasikan interface tersebut."),
            VocabItem(id: "p13", textZh: "继承", textId: "Warisan", exampleZh: "子类继承父类的属性。", exampleId: "Kelas anak mewarisi properti kelas induk."),
            VocabItem(id: "p14", textZh: "算法", textId: "Algoritma", exampleZh: "这个算法的时间复杂度是 O(n)。", exampleId: "Kompleksitas waktu algoritma ini adalah O(n)."),
            VocabItem(id: "p15", textZh: "编译", textId: "Kompilasi", exampleZh: "编译通过了，没有错误。", exampleId: "Kompilasi berhasil, tidak ada error."),
            VocabItem(id: "p16", textZh: "报错", textId: "Error", exampleZh: "控制台报错了，去看一下日志。", exampleId: "Konsol menampilkan error, cek log-nya."),
            VocabItem(id: "p17", textZh: "提交代码", textId: "Commit", exampleZh: "先提交代码再推送。", exampleId: "Commit kode dulu baru push."),
            VocabItem(id: "p18", textZh: "推送", textId: "Push", exampleZh: "推送到远程仓库。", exampleId: "Push ke repository remote."),
            VocabItem(id: "p19", textZh: "拉取", textId: "Pull", exampleZh: "拉取最新代码。", exampleId: "Pull kode terbaru."),
            VocabItem(id: "p20", textZh: "合并", textId: "Merge", exampleZh: "把分支合并到主分支。", exampleId: "Merge branch ke main."),
            VocabItem(id: "p21", textZh: "分支", textId: "Branch", exampleZh: "新建一个功能分支。", exampleId: "Buat branch fitur baru."),
            VocabItem(id: "p22", textZh: "部署", textId: "Deploy", exampleZh: "部署到生产环境。", exampleId: "Deploy ke lingkungan produksi."),
            VocabItem(id: "p23", textZh: "版本控制", textId: "Kontrol versi", exampleZh: "用 Git 做版本控制。", exampleId: "Gunakan Git untuk kontrol versi."),
            VocabItem(id: "p24", textZh: "后端", textId: "Backend", exampleZh: "他是做后端的。", exampleId: "Dia mengerjakan backend."),
            VocabItem(id: "p25", textZh: "前端", textId: "Frontend", exampleZh: "前端页面需要适配移动端。", exampleId: "Halaman frontend perlu responsif untuk mobile."),
            VocabItem(id: "p26", textZh: "数据库", textId: "Basis data", exampleZh: "把数据存进数据库。", exampleId: "Simpan data ke basis data."),
            VocabItem(id: "p27", textZh: "接口 / API", textId: "API", exampleZh: "调用第三方 API 获取数据。", exampleId: "Panggil API pihak ketiga untuk mengambil data."),
            VocabItem(id: "p28", textZh: "异步", textId: "Asinkron", exampleZh: "用异步请求避免阻塞。", exampleId: "Gunakan request asinkron untuk menghindari blocking."),
            VocabItem(id: "p29", textZh: "缓存", textId: "Cache", exampleZh: "加一层缓存提升性能。", exampleId: "Tambahkan cache untuk meningkatkan performa."),
            VocabItem(id: "p30", textZh: "日志", textId: "Log", exampleZh: "查日志定位问题。", exampleId: "Cek log untuk menemukan masalah."),
            VocabItem(id: "p31", textZh: "测试", textId: "Testing", exampleZh: "写单元测试覆盖主要逻辑。", exampleId: "Tulis unit test untuk menutupi logika utama."),
            VocabItem(id: "p32", textZh: "重构", textId: "Refaktor", exampleZh: "这段代码需要重构。", exampleId: "Kode ini perlu refaktor."),
            VocabItem(id: "p33", textZh: "空指针", textId: "Null pointer", exampleZh: "小心空指针异常。", exampleId: "Hati-hati dengan null pointer exception."),
            VocabItem(id: "p34", textZh: "递归", textId: "Rekursi", exampleZh: "用递归实现这个算法。", exampleId: "Implementasikan algoritma ini dengan rekursi."),
            VocabItem(id: "p35", textZh: "布尔值", textId: "Boolean", exampleZh: "条件表达式返回布尔值。", exampleId: "Ekspresi kondisi mengembalikan nilai boolean."),
            VocabItem(id: "p36", textZh: "整数", textId: "Integer", exampleZh: "声明一个整数类型的变量。", exampleId: "Deklarasikan variabel bertipe integer."),
            VocabItem(id: "p37", textZh: "浮点数", textId: "Float", exampleZh: "价格用浮点数存储。", exampleId: "Harga disimpan sebagai float."),
            VocabItem(id: "p38", textZh: "注释", textId: "Komentar", exampleZh: "在代码里加注释说明逻辑。", exampleId: "Tambahkan komentar di kode untuk menjelaskan logika."),
            VocabItem(id: "p39", textZh: "缩进", textId: "Indentasi", exampleZh: "保持统一的缩进风格。", exampleId: "Pertahankan gaya indentasi yang konsisten."),
            VocabItem(id: "p40", textZh: "代码审查", textId: "Code review", exampleZh: "提交前先做代码审查。", exampleId: "Lakukan code review sebelum submit."),
            VocabItem(id: "p41", textZh: "空值", textId: "Null", exampleZh: "返回值可能为空值。", exampleId: "Nilai return bisa null."),
            VocabItem(id: "p42", textZh: "异常", textId: "Exception", exampleZh: "捕获并处理异常。", exampleId: "Tangkap dan tangani exception."),
            VocabItem(id: "p43", textZh: "堆栈", textId: "Stack", exampleZh: "堆栈溢出错误。", exampleId: "Error stack overflow."),
            VocabItem(id: "p44", textZh: "队列", textId: "Queue", exampleZh: "用队列管理任务。", exampleId: "Gunakan queue untuk mengelola tugas."),
            VocabItem(id: "p45", textZh: "哈希表", textId: "Hash table", exampleZh: "用哈希表做快速查找。", exampleId: "Gunakan hash table untuk pencarian cepat."),
            VocabItem(id: "p46", textZh: "递归", textId: "Rekursi", exampleZh: "递归要有终止条件。", exampleId: "Rekursi harus punya kondisi berhenti."),
            VocabItem(id: "p47", textZh: "迭代", textId: "Iterasi", exampleZh: "用迭代代替递归。", exampleId: "Gunakan iterasi ganti rekursi."),
            VocabItem(id: "p48", textZh: "排序", textId: "Sorting", exampleZh: "对数组进行排序。", exampleId: "Urutkan array."),
            VocabItem(id: "p49", textZh: "查找", textId: "Pencarian", exampleZh: "二分查找效率高。", exampleId: "Binary search efisien."),
            VocabItem(id: "p50", textZh: "并发", textId: "Konkurensi", exampleZh: "处理并发请求。", exampleId: "Tangani request konkuren."),
            VocabItem(id: "p51", textZh: "线程", textId: "Thread", exampleZh: "开一个后台线程。", exampleId: "Buat thread latar belakang."),
            VocabItem(id: "p52", textZh: "进程", textId: "Proses", exampleZh: "进程间通信。", exampleId: "Komunikasi antar proses."),
            VocabItem(id: "p53", textZh: "内存泄漏", textId: "Kebocoran memori", exampleZh: "可能有内存泄漏。", exampleId: "Mungkin ada kebocoran memori."),
            VocabItem(id: "p54", textZh: "性能优化", textId: "Optimasi performa", exampleZh: "做一下性能优化。", exampleId: "Lakukan optimasi performa."),
            VocabItem(id: "p55", textZh: "依赖", textId: "Dependensi", exampleZh: "安装项目依赖。", exampleId: "Install dependensi proyek.")
        ]
        return VocabCategory(
            id: "programming",
            nameZh: "编程用语",
            nameId: "Pemrograman",
            items: items
        )
    }
}
