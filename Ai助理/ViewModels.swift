import Foundation
import SwiftUI
import Combine
import UIKit
import NaturalLanguage

@MainActor
final class ChatViewModel: ObservableObject {
    /// 是否允许本机执行（助理入口为 true 时，后端可返回 [CMD] 由用户确认执行）
    let allowLocalExecution: Bool

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isListening = false
    @Published var isVideoCalling = false
    @Published var isPhotoMode = false
    @Published var statusText = "AI 已就绪"
    @Published var isSending = false
    @Published var alertMessage: String?
    @Published var conversationHistory: [CloudConversationSummary] = []
    @Published var isLoadingConversationHistory = false
    /// 本机执行模式：助理返回 [CMD] 时等待用户确认执行
    @Published var pendingCommand: (displayText: String, command: String, conversationId: String?)?
    /// 命令已执行，等待用户确认后再将结果发送至服务器（保护隐私）
    @Published var pendingSendResult: (output: String, conversationId: String?)?

    private let speechTranscriber = SpeechTranscriber()
    private let maxContextCount = 12
    private var serverConversationId: String?
    private var localConversationId: String
    private var voiceStopWorkItem: DispatchWorkItem?
    private var lastVoiceText: String?
    private var isStoppingVoice = false
    private var pendingImageData: Data? = nil
    private var cancellables = Set<AnyCancellable>()
    private var hasHydratedFromCloud = false
    
    init(allowLocalExecution: Bool = false) {
        self.allowLocalExecution = allowLocalExecution
        // 加载或创建本地对话ID
        if let savedId = LocalDataStore.shared.loadCurrentConversationId() {
            localConversationId = savedId
            // 加载本地保存的消息
            messages = LocalDataStore.shared.loadConversation(id: savedId)
        } else {
            localConversationId = UUID().uuidString
            LocalDataStore.shared.saveCurrentConversationId(localConversationId)
        }
        
        // 如果已登录，尝试从云端同步
        if TokenStore.shared.isLoggedIn {
            Task {
                await syncFromCloud()
            }
        }
        
        TokenStore.shared.$token
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.handleAuthStateChanged()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAuthStateChanged() {
        if TokenStore.shared.isLoggedIn {
            Task { await syncFromCloud() }
        } else {
            // 退出登录后回到本地会话上下文
            serverConversationId = nil
            hasHydratedFromCloud = false
        }
    }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = pendingImageData != nil
        guard !trimmed.isEmpty || hasImage else { return }
        
        // 创建用户消息（如果有图片，显示提示）
        let messageContent = hasImage ? (trimmed.isEmpty ? "[图片]" : trimmed + " [图片]") : trimmed
        let userMessage = ChatMessage(id: UUID().uuidString, role: .user, content: messageContent, time: Date())
        messages.append(userMessage)
        
        // 保存到本地
        saveMessagesToLocal()
        
        let imageData = pendingImageData
        pendingImageData = nil
        inputText = ""
        statusText = "思考中..."
        isSending = true

        Task {
            do {
                var effectiveMessage = trimmed
                if let imageData {
                    // 图片识别增强：先做 OCR，把可识别文字一并发送给 AI，避免模型仅返回“无法读取图片”
                    if let ocrText = try? await VisionService.shared.recognizeText(from: imageData) {
                        let cleanOCR = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanOCR.isEmpty {
                            let snippet = String(cleanOCR.prefix(2500))
                            if effectiveMessage.isEmpty {
                                effectiveMessage = "请基于这张图片识别并总结。以下是OCR识别文字：\n\(snippet)"
                            } else {
                                effectiveMessage += "\n\n以下是图片OCR识别文字，请结合分析：\n\(snippet)"
                            }
                        } else if effectiveMessage.isEmpty {
                            effectiveMessage = "请描述并分析这张图片内容。"
                        }
                    } else if effectiveMessage.isEmpty {
                        effectiveMessage = "请描述并分析这张图片内容。"
                    }
                }
                let userContext = TokenStore.shared.isLoggedIn ? nil : LocalDataStore.shared.memoriesAsUserContext()
                let (cid, serverReply) = try await APIClient.shared.assistantChat(
                    conversationId: serverConversationId,
                    message: effectiveMessage.isEmpty ? nil : (effectiveMessage + (imageData != nil ? " [用户附了一张图]" : "")),
                    imageData: imageData,
                    userContext: userContext,
                    localExecution: allowLocalExecution
                )
                serverConversationId = cid
                let (displayText, command) = allowLocalExecution ? OpenClawService.parseCommand(from: serverReply) : (serverReply, nil)
                let replyMsg = ChatMessage(id: UUID().uuidString, role: .assistant, content: displayText, time: Date())
                messages.append(replyMsg)
                saveMessagesToLocal()
                if let cmd = command, !cmd.isEmpty {
                    pendingCommand = (displayText, cmd, cid)
                } else {
                    statusText = "AI 已就绪"
                    SpeechService.shared.speak(displayText, language: "zh-CN")
                }
            } catch {
                alertMessage = userFacingMessage(for: error)
                statusText = "AI 未就绪"
            }
            isSending = false
        }
    }
    
    /// 加载历史对话列表（登录走云端，未登录走本地）
    func loadConversationHistory() async {
        isLoadingConversationHistory = true
        defer { isLoadingConversationHistory = false }
        
        if TokenStore.shared.isLoggedIn {
            do {
                conversationHistory = try await APIClient.shared.getConversations(take: 50)
                return
            } catch {
                // 云端历史接口不可用时，静默回退到本地历史，避免弹出 HTML 错误内容
                #if DEBUG
                print("[History] cloud conversations unavailable, fallback to local: \(error.localizedDescription)")
                #endif
            }
        }
        
        // 未登录回退：本地会话列表
        let all = LocalDataStore.shared.loadAllConversations()
        let formatter = ISO8601DateFormatter()
        let localList: [CloudConversationSummary] = all.map { (id, rows) in
            let last = rows.last
            let first = rows.first
            let lastText = (last?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstText = (first?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleRaw = (firstText?.isEmpty == false ? firstText! : "本地会话")
            let title = String(titleRaw.prefix(20))
            let lastTime = (last?["time"] as? TimeInterval) ?? Date().timeIntervalSince1970
            let firstTime = (first?["time"] as? TimeInterval) ?? lastTime
            return CloudConversationSummary(
                id: id,
                title: title,
                createdAt: formatter.string(from: Date(timeIntervalSince1970: firstTime)),
                updatedAt: formatter.string(from: Date(timeIntervalSince1970: lastTime)),
                lastMessage: String((lastText ?? "").prefix(80))
            )
        }
        conversationHistory = localList.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// 切换到历史会话继续对话
    func switchToConversation(_ summary: CloudConversationSummary) async {
        statusText = "加载会话中..."
        do {
            if TokenStore.shared.isLoggedIn {
                let cloudMessages = try await APIClient.shared.getConversationMessages(conversationId: summary.id)
                serverConversationId = summary.id
                messages = cloudMessages
            } else {
                messages = LocalDataStore.shared.loadConversation(id: summary.id)
                serverConversationId = nil
            }
            localConversationId = summary.id
            LocalDataStore.shared.saveCurrentConversationId(summary.id)
            saveMessagesToLocal()
            statusText = "AI 已就绪"
        } catch {
            alertMessage = userFacingMessage(for: error)
            statusText = "AI 未就绪"
        }
    }

    /// 通过会话 ID 切换到历史会话（侧边栏快捷入口使用）
    func switchToConversation(id: String) async {
        statusText = "加载会话中..."
        do {
            if TokenStore.shared.isLoggedIn {
                let cloudMessages = try await APIClient.shared.getConversationMessages(conversationId: id)
                serverConversationId = id
                messages = cloudMessages
            } else {
                messages = LocalDataStore.shared.loadConversation(id: id)
                serverConversationId = nil
            }
            localConversationId = id
            LocalDataStore.shared.saveCurrentConversationId(id)
            saveMessagesToLocal()
            statusText = "AI 已就绪"
        } catch {
            alertMessage = userFacingMessage(for: error)
            statusText = "AI 未就绪"
        }
    }

    /// 用户确认执行本机命令后调用（先执行，再弹出「发送结果」确认以保护隐私）
    func confirmCommandExecution() {
        guard let pending = pendingCommand else { return }
        let command = pending.command
        let cid = pending.conversationId
        pendingCommand = nil
        if !OpenClawService.isCommandAllowed(command) {
            alertMessage = "出于安全与隐私保护，该命令未被允许执行。仅支持只读类命令（如 ls、pwd、date、whoami、df）。"
            statusText = "AI 已就绪"
            return
        }
        statusText = "执行中..."
        Task {
            let output = await OpenClawService.shared.runLocalCommand(command)
            await MainActor.run {
                pendingSendResult = (output, cid)
                statusText = "请确认是否将结果发送至服务器"
            }
        }
    }

    /// 用户确认将执行结果发送至服务器后调用
    func confirmSendResult() {
        guard let pending = pendingSendResult else { return }
        let output = pending.output
        let cid = pending.conversationId
        pendingSendResult = nil
        statusText = "思考中..."
        Task {
            do {
                let followUp = "（你上一条回复中请求执行的命令已执行，结果如下）\n```\n\(output)\n```\n请根据结果用中文继续回答。"
                let userContext = TokenStore.shared.isLoggedIn ? nil : LocalDataStore.shared.memoriesAsUserContext()
                let (newCid, secondReply) = try await APIClient.shared.assistantChat(
                    conversationId: cid,
                    message: followUp,
                    userContext: userContext,
                    localExecution: true
                )
                serverConversationId = newCid
                let (displayText, _) = OpenClawService.parseCommand(from: secondReply)
                let replyMsg = ChatMessage(id: UUID().uuidString, role: .assistant, content: displayText, time: Date())
                messages.append(replyMsg)
                saveMessagesToLocal()
                statusText = "AI 已就绪"
                SpeechService.shared.speak(displayText, language: "zh-CN")
            } catch {
                alertMessage = userFacingMessage(for: error)
                statusText = "AI 已就绪"
            }
        }
    }

    /// 用户取消发送执行结果
    func cancelSendResult() {
        pendingSendResult = nil
        statusText = "AI 已就绪"
    }

    /// 用户取消执行本机命令
    func cancelCommandExecution() {
        pendingCommand = nil
        statusText = "AI 已就绪"
    }
    
    /// 处理粘贴的图片
    func handlePastedImage(_ imageData: Data) {
        guard UIImage(data: imageData) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
        pendingImageData = imageData
        // 如果输入框为空，自动发送；否则等待用户输入文字后一起发送
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            inputText = "请识别这张图片"
            sendMessage()
        }
    }
    
    /// 处理文件上传
    func handleFileUpload(url: URL, data: Data) {
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        
        // 判断文件类型
        let isImage = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"].contains(fileExtension)
        let isPDF = fileExtension == "pdf"
        let isText = ["txt", "md", "markdown", "json", "xml", "csv", "log"].contains(fileExtension)
        
        if isImage {
            // 图片文件，使用图片处理逻辑
            pendingImageData = data
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = "请识别这张图片：\(fileName)"
            } else {
                inputText += " [文件: \(fileName)]"
            }
            sendMessage()
        } else if isPDF || isText {
            // PDF或文本文件，发送给AI分析
            statusText = "正在上传文件..."
            isSending = true
            
            Task {
                do {
                    let userContext = TokenStore.shared.isLoggedIn ? nil : LocalDataStore.shared.memoriesAsUserContext()
                    let (cid, reply) = try await APIClient.shared.assistantChatWithFile(
                        conversationId: serverConversationId,
                        message: inputText.isEmpty ? "请分析这个文件：\(fileName)" : inputText,
                        fileData: data,
                        fileName: fileName,
                        fileType: isPDF ? "pdf" : "text",
                        userContext: userContext
                    )
                    serverConversationId = cid
                    
                    // 添加用户消息
                    let userMessageContent = inputText.isEmpty ? "[文件: \(fileName)]" : inputText + " [文件: \(fileName)]"
                    let userMessage = ChatMessage(id: UUID().uuidString, role: .user, content: userMessageContent, time: Date())
                    await MainActor.run {
                        messages.append(userMessage)
                        saveMessagesToLocal()
                    }
                    
                    // 添加AI回复
                    let replyMsg = ChatMessage(id: UUID().uuidString, role: .assistant, content: reply, time: Date())
                    await MainActor.run {
                        messages.append(replyMsg)
                        saveMessagesToLocal()
                        inputText = ""
                        statusText = "AI 已就绪"
                        SpeechService.shared.speak(reply, language: "zh-CN")
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = userFacingMessage(for: error)
                        statusText = "AI 未就绪"
                    }
                }
                await MainActor.run {
                    isSending = false
                }
            }
        } else {
            alertMessage = "不支持的文件类型：\(fileExtension)。支持的类型：图片、PDF、文本文件"
        }
    }

    func resetConversation() {
        messages.removeAll()
        serverConversationId = nil
        
        // 创建新的本地对话
        localConversationId = UUID().uuidString
        LocalDataStore.shared.saveCurrentConversationId(localConversationId)
        
        statusText = "AI 已就绪"
    }
    
    /// 保存消息到本地
    private func saveMessagesToLocal() {
        LocalDataStore.shared.saveConversation(id: localConversationId, messages: messages)
    }
    
    /// 从云端同步数据
    private func syncFromCloud() async {
        guard TokenStore.shared.isLoggedIn else { return }
        if hasHydratedFromCloud { return }
        do {
            let conversations = try await APIClient.shared.getConversations(take: 1)
            guard let latest = conversations.first else {
                hasHydratedFromCloud = true
                return
            }
            let cloudMessages = try await APIClient.shared.getConversationMessages(conversationId: latest.id)
            guard !cloudMessages.isEmpty else {
                serverConversationId = latest.id
                hasHydratedFromCloud = true
                return
            }
            serverConversationId = latest.id
            messages = cloudMessages
            saveMessagesToLocal()
            hasHydratedFromCloud = true
            statusText = "AI 已就绪"
        } catch {
            // 同步失败不打断本地可用性，保持静默回退
            print("[ChatViewModel] 云端会话同步失败: \(error.localizedDescription)")
        }
    }

    /// 发送一条消息并等待 AI 回复（用于语音/视频通话）；本机执行模式下若有 [CMD] 只返回文案不执行
    func sendAndWaitForReply(text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NSError(domain: "Chat", code: -1, userInfo: [NSLocalizedDescriptionKey: "内容为空"]) }
        let userMessage = ChatMessage(id: UUID().uuidString, role: .user, content: trimmed, time: Date())
        await MainActor.run {
            messages.append(userMessage)
            saveMessagesToLocal()
        }
        let userContext = TokenStore.shared.isLoggedIn ? nil : LocalDataStore.shared.memoriesAsUserContext()
        let (cid, serverReply) = try await APIClient.shared.assistantChat(
            conversationId: serverConversationId,
            message: trimmed,
            userContext: userContext,
            localExecution: allowLocalExecution
        )
        await MainActor.run { serverConversationId = cid }
        let (displayText, _) = OpenClawService.parseCommand(from: serverReply)
        let replyMsg = ChatMessage(id: UUID().uuidString, role: .assistant, content: displayText, time: Date())
        await MainActor.run {
            messages.append(replyMsg)
            saveMessagesToLocal()
        }
        return displayText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
                            if !text.isEmpty {
                                // 用户开口时自动打断正在播放的AI语音
                                if SpeechService.shared.isPlaying {
                                    SpeechService.shared.stopSpeaking()
                                }
                                // 过滤应用自身播报被回采的文本
                                if SpeechService.shared.shouldFilterRecognizedText(text) {
                                    return
                                }
                                self.inputText = text
                            }
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
            // 确保输入框被清空（防止某些情况下 sendMessage 没有清空）
            inputText = ""
        } else {
            // 即使不发送消息，也要清空输入框
            inputText = ""
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
            UIApplication.shared.open(url)
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
        guard UIImage(data: data) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
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
        guard UIImage(data: data) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
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
    private var autoTranslateWorkItem: DispatchWorkItem?
    private let autoTranslateDelay: TimeInterval = 0.6
    private var autoStopWorkItem: DispatchWorkItem?
    private let silenceTimeout: TimeInterval = 1.2
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 加载本地翻译历史
        history = LocalDataStore.shared.loadAllTranslations()
        
        // 如果已登录，尝试从云端同步
        if TokenStore.shared.isLoggedIn {
            Task {
                await syncTranslationsFromCloud()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .clearLocalData, object: nil, queue: .main) { [weak self] _ in
            guard let viewModel = self else { return }
            Task { @MainActor in
                viewModel.history.removeAll()
            }
        }
        
        TokenStore.shared.$token
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.handleAuthStateChanged()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAuthStateChanged() {
        if TokenStore.shared.isLoggedIn {
            Task { await syncTranslationsFromCloud() }
        } else {
            // 退出登录后仅显示本地记录
            history = LocalDataStore.shared.loadAllTranslations()
        }
    }

    func clearHistory() {
        history.removeAll()
    }

    /// 从历史记录回填到输入框，便于继续编辑后再次翻译
    func loadHistoryEntryForEditing(_ entry: TranslationEntry) {
        sourceLang = entry.sourceLang
        targetLang = entry.targetLang
        sourceText = entry.sourceText
        translatedText = entry.targetText
        isListening = false
        isTranslating = false
    }

    /// 文本改变后延迟自动翻译（边输入边翻译），避免每个按键都请求后端
    func scheduleAutoTranslate() {
        autoTranslateWorkItem?.cancel()
        guard !isTranslating else { return }
        let leftTrimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rightTrimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 两个框都空时不翻译
        guard !leftTrimmed.isEmpty || !rightTrimmed.isEmpty else { return }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.translate()
            }
        }
        autoTranslateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoTranslateDelay, execute: workItem)
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
                    let entry = TranslationEntry(
                        id: UUID().uuidString,
                        sourceText: trimmed,
                        targetText: result,
                        sourceLang: sourceLang,
                        targetLang: targetLang,
                        createdAt: Date()
                    )
                    history.insert(entry, at: 0)
                    
                    // 保存到本地
                    LocalDataStore.shared.saveTranslation(entry)
                    
                    // 如果已登录，同步到云端
                    if TokenStore.shared.isLoggedIn {
                        Task {
                            await syncTranslationToCloud(entry)
                        }
                    }
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
                    let entry = TranslationEntry(
                        id: UUID().uuidString,
                        sourceText: trimmed,
                        targetText: result,
                        sourceLang: targetLang,
                        targetLang: sourceLang,
                        createdAt: Date()
                    )
                    history.insert(entry, at: 0)
                    
                    // 保存到本地
                    LocalDataStore.shared.saveTranslation(entry)
                    
                    // 如果已登录，同步到云端
                    if TokenStore.shared.isLoggedIn {
                        Task {
                            await syncTranslationToCloud(entry)
                        }
                    }
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
                                if SpeechService.shared.isPlaying {
                                    SpeechService.shared.stopSpeaking()
                                }
                                if SpeechService.shared.shouldFilterRecognizedText(text) {
                                    return
                                }
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
    
    /// 同步翻译到云端
    private func syncTranslationToCloud(_ entry: TranslationEntry) async {
        do {
            try await APIClient.shared.saveTranslation(
                sourceLang: entry.sourceLang.code,
                targetLang: entry.targetLang.code,
                sourceText: entry.sourceText,
                targetText: entry.targetText
            )
        } catch {
            // 静默失败，不影响用户体验
            #if DEBUG
            print("[TranslateViewModel] 云端同步失败: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// 从云端同步翻译历史
    private func syncTranslationsFromCloud() async {
        do {
            let cloudTranslations = try await APIClient.shared.getTranslationHistory()
            await MainActor.run {
                // 合并云端和本地数据，去重
                var merged = history
                for cloud in cloudTranslations {
                    if !merged.contains(where: { $0.id == cloud.id }) {
                        merged.append(cloud)
                    }
                }
                history = merged.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            // 静默失败，使用本地数据
            #if DEBUG
            print("[TranslateViewModel] 云端同步失败: \(error.localizedDescription)")
            #endif
        }
    }
}

enum RealtimeSourceLanguage {
    case indonesian
    case chinese
}

struct RealtimeTranslateEntry: Identifiable {
    let id = UUID()
    let indonesian: String
    let chinese: String
    let sourceLanguage: RealtimeSourceLanguage
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
    @Published var currentSourceLanguage: RealtimeSourceLanguage = .indonesian

    private let speechTranscriber = SpeechTranscriber()
    private var autoStopWorkItem: DispatchWorkItem?
    private let silenceTimeout: TimeInterval = 1.2

    func toggleLeft() {
        if isLeftRecording {
            stopRecording()
        } else {
            currentSourceLanguage = .indonesian
            startRecording(locale: Locale(identifier: "id-ID"), isLeft: true)
        }
    }

    func toggleRight() {
        if isRightRecording {
            stopRecording()
        } else {
            currentSourceLanguage = .chinese
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
                                if SpeechService.shared.isPlaying {
                                    SpeechService.shared.stopSpeaking()
                                }
                                if SpeechService.shared.shouldFilterRecognizedText(text) {
                                    return
                                }
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
                        entries.append(RealtimeTranslateEntry(indonesian: source, chinese: result, sourceLanguage: .indonesian))
                        leftText = ""
                        rightTranslated = ""
                        SpeechService.shared.speak(result, language: "zh-CN")
                    }
                } else {
                    result = try await APIClient.shared.translate(text: source, sourceLang: "zh-CN", targetLang: "id-ID")
                    await MainActor.run {
                        leftTranslated = result
                        entries.append(RealtimeTranslateEntry(indonesian: result, chinese: source, sourceLanguage: .chinese))
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
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let categoriesCacheKey = "learning_categories_cache"
    private let favoritesKey = "favorite_vocab_ids"
    private let activeDaysKey = "learning_active_days"
    private let syncedActiveDayKey = "learning_active_day_synced"

    init() {
        loadCachedCategories()
        if selectedCategoryId == nil {
            selectedCategoryId = categories.first?.id
        }
        loadFavorites()
        NotificationCenter.default.addObserver(forName: .clearLocalData, object: nil, queue: .main) { [weak self] _ in
            let viewModel = self
            Task { @MainActor in
                viewModel?.loadFavorites()
            }
        }
        TokenStore.shared.$token
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.syncFavoritesFromCloud()
                    await self.syncActiveDayIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    func bootstrap() async {
        await refreshCategories()
        await syncFavoritesFromCloud()
        await syncActiveDayIfNeeded()
    }

    /// 全部词汇总数（所有分类）
    var totalVocabCount: Int {
        categories.flatMap { $0.items }.count
    }

    /// 已标记为收藏/掌握的数量
    var masteredCount: Int {
        favoriteIds.count
    }

    /// 有学习记录的天数（本地记忆，按自然日去重）
    var activeDaysCount: Int {
        let stored = UserDefaults.standard.array(forKey: activeDaysKey) as? [String] ?? []
        return Set(stored).count
    }

    /// 记录今天有学习行为（用于统计“坚持天数”）
    func registerActiveDayIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        var days = UserDefaults.standard.array(forKey: activeDaysKey) as? [String] ?? []
        if !days.contains(today) {
            days.append(today)
            UserDefaults.standard.set(days, forKey: activeDaysKey)
        }
        Task { @MainActor in
            await syncActiveDayIfNeeded()
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
        guard TokenStore.shared.isLoggedIn else { return }
        Task { @MainActor in
            do {
                try await APIClient.shared.setLearningFavorite(vocabId: item.id, isFavorite: favoriteIds.contains(item.id))
            } catch {
                errorMessage = userFacingMessage(for: error)
            }
        }
    }

    func isFavorite(_ item: VocabItem) -> Bool {
        favoriteIds.contains(item.id)
    }

    func loadFavorites() {
        let stored = UserDefaults.standard.array(forKey: favoritesKey) as? [String] ?? []
        favoriteIds = Set(stored)
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: favoritesKey)
    }

    private func loadCachedCategories() {
        guard let data = UserDefaults.standard.data(forKey: categoriesCacheKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([VocabCategory].self, from: data)
            categories = decoded
        } catch {
            #if DEBUG
            print("[Learning] failed to decode cached categories: \(error)")
            #endif
        }
    }

    private func saveCategoriesCache(_ categories: [VocabCategory]) {
        do {
            let data = try JSONEncoder().encode(categories)
            UserDefaults.standard.set(data, forKey: categoriesCacheKey)
        } catch {
            #if DEBUG
            print("[Learning] failed to cache categories: \(error)")
            #endif
        }
    }

    func refreshCategories() async {
        isLoading = true
        do {
            let remote = try await APIClient.shared.getLearningCategories()
            categories = remote
            if let current = selectedCategoryId,
               categories.contains(where: { $0.id == current }) {
            } else {
                selectedCategoryId = categories.first?.id
            }
            saveCategoriesCache(remote)
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
        isLoading = false
    }

    func syncFavoritesFromCloud() async {
        guard TokenStore.shared.isLoggedIn else { return }
        do {
            let remoteFavorites = Set(try await APIClient.shared.getLearningFavorites())
            let localFavorites = favoriteIds
            let toUpload = localFavorites.subtracting(remoteFavorites)
            for vocabId in toUpload {
                try await APIClient.shared.setLearningFavorite(vocabId: vocabId, isFavorite: true)
            }
            favoriteIds = localFavorites.union(remoteFavorites)
            saveFavorites()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func syncActiveDayIfNeeded() async {
        guard TokenStore.shared.isLoggedIn else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let lastSynced = UserDefaults.standard.string(forKey: syncedActiveDayKey)
        guard lastSynced != today else { return }
        let stored = UserDefaults.standard.array(forKey: activeDaysKey) as? [String] ?? []
        guard stored.contains(today) else { return }
        do {
            try await APIClient.shared.logLearningSession(minutes: 1, masteredCount: masteredCount)
            UserDefaults.standard.set(today, forKey: syncedActiveDayKey)
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }
}

@MainActor
final class UserStatsViewModel: ObservableObject {
    @Published var stats: UserStats?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        guard TokenStore.shared.isLoggedIn else {
            await MainActor.run {
                self.stats = nil
                self.errorMessage = nil
            }
            return
        }
        isLoading = true
        do {
            let s = try await APIClient.shared.getUserStats()
            await MainActor.run {
                self.stats = s
                self.errorMessage = nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
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
