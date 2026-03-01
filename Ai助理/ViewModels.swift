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
    @Published private(set) var latestVoiceCapturedText: String = ""
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
    private var voiceShouldAutoSend = true
    private var pendingImageData: Data? = nil
    private var cancellables = Set<AnyCancellable>()
    
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
                let userContext = TokenStore.shared.isLoggedIn ? nil : LocalDataStore.shared.memoriesAsUserContext()
                let (cid, serverReply) = try await APIClient.shared.assistantChat(
                    conversationId: serverConversationId,
                    message: trimmed.isEmpty ? nil : (trimmed + (imageData != nil ? " [用户附了一张图]" : "")),
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
        #if os(macOS)
        guard NSImage(data: imageData) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
        #elseif os(iOS)
        guard UIImage(data: imageData) != nil else {
            alertMessage = "图片格式不支持"
            return
        }
        #endif
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
        // 如果已有服务器对话ID，可在此从云端加载对话；目前先使用本地数据
        guard serverConversationId != nil else { return }
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
            startListening(localeIdentifier: "zh-CN", autoSendOnStop: true)
        }
    }

    /// 语音通话页使用：只做 STT，不自动触发 sendMessage
    func startListeningForRealtime(localeIdentifier: String = "zh-CN") {
        startListening(localeIdentifier: localeIdentifier, autoSendOnStop: false)
    }

    /// 语音通话页使用：停止 STT 并返回本轮识别文本，不自动发送
    @discardableResult
    func stopListeningForRealtime() -> String {
        stopListening(autoSendOverride: false)
    }

    /// 读取并清空最新一次语音识别文本
    func consumeLatestVoiceCapturedText() -> String {
        let text = latestVoiceCapturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        latestVoiceCapturedText = ""
        return text
    }

    private func startListening(localeIdentifier: String, autoSendOnStop: Bool) {
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
                    latestVoiceCapturedText = ""
                    isStoppingVoice = false
                    voiceShouldAutoSend = autoSendOnStop
                    voiceStopWorkItem?.cancel()
                    isListening = true
                    statusText = "语音监听中"
                    try speechTranscriber.startTranscribing(locale: Locale(identifier: localeIdentifier)) { [weak self] text, isFinal in
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
        _ = stopListening(autoSendOverride: nil)
    }

    @discardableResult
    private func stopListening(autoSendOverride: Bool?) -> String {
        if isStoppingVoice {
            return latestVoiceCapturedText
        }
        guard isListening else {
            return ""
        }
        isStoppingVoice = true
        voiceStopWorkItem?.cancel()
        speechTranscriber.stopTranscribing()
        isListening = false
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        latestVoiceCapturedText = trimmed

        let shouldAutoSend = autoSendOverride ?? voiceShouldAutoSend
        if shouldAutoSend {
            if !trimmed.isEmpty, trimmed != lastVoiceText {
                lastVoiceText = trimmed
                sendMessage()
                // 确保输入框被清空（防止某些情况下 sendMessage 没有清空）
                inputText = ""
            } else {
                // 即使不发送消息，也要清空输入框
                inputText = ""
            }
        } else {
            // 实时模式：仅返回识别结果给调用方，由调用方决定何时发送
            inputText = ""
        }
        statusText = "AI 已就绪"
        isStoppingVoice = false
        return trimmed
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

    func clearTexts() {
        sourceText = ""
        translatedText = ""
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
                    sourceLang: sourceLang.code,
                    targetLang: targetLang.code
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
                    sourceLang: targetLang.code,
                    targetLang: sourceLang.code
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
        SpeechService.shared.stopSpeaking()
        if isLeftRecording {
            stopRecording()
        } else {
            currentSourceLanguage = .indonesian
            startRecording(locale: Locale(identifier: "id-ID"), isLeft: true)
        }
    }

    func toggleRight() {
        SpeechService.shared.stopSpeaking()
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
                        if !isLeftRecording && !isRightRecording {
                            SpeechService.shared.speak(result, language: "zh-CN")
                        }
                    }
                } else {
                    result = try await APIClient.shared.translate(text: source, sourceLang: "zh-CN", targetLang: "id-ID")
                    await MainActor.run {
                        leftTranslated = result
                        entries.append(RealtimeTranslateEntry(indonesian: result, chinese: source, sourceLanguage: .chinese))
                        rightText = ""
                        leftTranslated = ""
                        if !isLeftRecording && !isRightRecording {
                            SpeechService.shared.speak(result, language: "id-ID")
                        }
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
        let stored = UserDefaults.standard.array(forKey: "learning_active_days") as? [String] ?? []
        return Set(stored).count
    }

    /// 记录今天有学习行为（用于统计“坚持天数”）
    func registerActiveDayIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        var days = UserDefaults.standard.array(forKey: "learning_active_days") as? [String] ?? []
        if !days.contains(today) {
            days.append(today)
            UserDefaults.standard.set(days, forKey: "learning_active_days")
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

enum SampleData {
    static let vocabCategories: [VocabCategory] = [
        greetingCategory,
        travelCategory,
        foodCategory,
        emergencyCategory,
        ecommerceCategory,
        programmingCategory,
        workCategory,
        campusCategory,
        healthCategory,
        familyCategory,
        financeCategory,
        socialCategory
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

    /// 新增：职场沟通
    static var workCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "w1", textZh: "开早会", textId: "Rapat pagi", exampleZh: "我们九点开早会。", exampleId: "Kita rapat pagi jam sembilan."),
            VocabItem(id: "w2", textZh: "项目进度", textId: "Progres proyek", exampleZh: "今天汇报一下项目进度。", exampleId: "Hari ini kita laporkan progres proyek."),
            VocabItem(id: "w3", textZh: "截止日期", textId: "Tenggat waktu", exampleZh: "这个任务截止日期是周五。", exampleId: "Tenggat tugas ini hari Jumat."),
            VocabItem(id: "w4", textZh: "加班", textId: "Lembur", exampleZh: "如果赶不完可能要加班。", exampleId: "Kalau tidak selesai mungkin harus lembur."),
            VocabItem(id: "w5", textZh: "请假", textId: "Izin cuti", exampleZh: "明天我想请一天假。", exampleId: "Besok saya mau izin cuti satu hari."),
            VocabItem(id: "w6", textZh: "远程办公", textId: "Kerja jarak jauh", exampleZh: "本周三我远程办公。", exampleId: "Rabu ini saya kerja jarak jauh."),
            VocabItem(id: "w7", textZh: "发邮件", textId: "Kirim email", exampleZh: "我待会儿给你发一封邮件。", exampleId: "Nanti saya kirim email ke kamu."),
            VocabItem(id: "w8", textZh: "会议纪要", textId: "Notulen rapat", exampleZh: "会后请发会议纪要。", exampleId: "Setelah rapat tolong kirim notulen."),
            VocabItem(id: "w9", textZh: "同事", textId: "Rekan kerja", exampleZh: "我和同事一起负责这个项目。", exampleId: "Saya dan rekan kerja bersama menangani proyek ini."),
            VocabItem(id: "w10", textZh: "领导", textId: "Atasan", exampleZh: "这个需要领导先确认。", exampleId: "Ini perlu dikonfirmasi atasan dulu."),
            VocabItem(id: "w11", textZh: "客户", textId: "Klien", exampleZh: "今天下午要见一个重要客户。", exampleId: "Sore ini kita bertemu klien penting."),
            VocabItem(id: "w12", textZh: "报价", textId: "Penawaran harga", exampleZh: "我已经把报价发过去了。", exampleId: "Saya sudah kirim penawaran harga."),
            VocabItem(id: "w13", textZh: "合同", textId: "Kontrak", exampleZh: "合同签好之后再启动项目。", exampleId: "Proyek dimulai setelah kontrak ditandatangani."),
            VocabItem(id: "w14", textZh: "审批", textId: "Persetujuan", exampleZh: "这个流程还在审批中。", exampleId: "Proses ini masih menunggu persetujuan."),
            VocabItem(id: "w15", textZh: "绩效考核", textId: "Penilaian kinerja", exampleZh: "本月有绩效考核。", exampleId: "Bulan ini ada penilaian kinerja."),
            VocabItem(id: "w16", textZh: "试用期", textId: "Masa percobaan", exampleZh: "我还在试用期。", exampleId: "Saya masih dalam masa percobaan."),
            VocabItem(id: "w17", textZh: "正式员工", textId: "Karyawan tetap", exampleZh: "通过考核后转为正式员工。", exampleId: "Setelah lulus penilaian akan jadi karyawan tetap."),
            VocabItem(id: "w18", textZh: "调岗", textId: "Mutasi posisi", exampleZh: "下个月我可能要调岗。", exampleId: "Bulan depan mungkin saya mutasi posisi."),
            VocabItem(id: "w19", textZh: "奖金", textId: "Bonus", exampleZh: "年终会发绩效奖金。", exampleId: "Akhir tahun akan ada bonus kinerja."),
            VocabItem(id: "w20", textZh: "报销", textId: "Reimburse", exampleZh: "出差费用可以报销。", exampleId: "Biaya dinas bisa reimburse."),
            VocabItem(id: "w21", textZh: "出差", textId: "Perjalanan dinas", exampleZh: "下周我要去雅加达出差。", exampleId: "Minggu depan saya dinas ke Jakarta."),
            VocabItem(id: "w22", textZh: "排班表", textId: "Jadwal shift", exampleZh: "新的排班表已经发群里了。", exampleId: "Jadwal shift baru sudah dikirim ke grup."),
            VocabItem(id: "w23", textZh: "工作汇报", textId: "Laporan kerja", exampleZh: "每周一提交工作汇报。", exampleId: "Setiap Senin kirim laporan kerja."),
            VocabItem(id: "w24", textZh: "晋升", textId: "Promosi", exampleZh: "她今年晋升为部门经理。", exampleId: "Tahun ini dia promosi jadi manajer."),
            VocabItem(id: "w25", textZh: "团队合作", textId: "Kerja sama tim", exampleZh: "这个项目非常考验团队合作。", exampleId: "Proyek ini sangat menguji kerja sama tim."),
            VocabItem(id: "w26", textZh: "工作计划", textId: "Rencana kerja", exampleZh: "先做一个本周的工作计划。", exampleId: "Buat dulu rencana kerja minggu ini."),
            VocabItem(id: "w27", textZh: "绩效目标", textId: "Target kinerja", exampleZh: "今年绩效目标比较高。", exampleId: "Target kinerja tahun ini cukup tinggi."),
            VocabItem(id: "w28", textZh: "请你配合", textId: "Mohon kerja samanya", exampleZh: "这件事还需要你多多配合。", exampleId: "Hal ini masih perlu banyak kerja sama dari kamu."),
            VocabItem(id: "w29", textZh: "加个微信", textId: "Tambah kontak WhatsApp", exampleZh: "方便的话加一下微信保持沟通。", exampleId: "Kalau berkenan tambah kontak WhatsApp supaya mudah komunikasi."),
            VocabItem(id: "w30", textZh: "线上培训", textId: "Pelatihan online", exampleZh: "下午有一场线上培训。", exampleId: "Sore ini ada pelatihan online."),
            VocabItem(id: "w31", textZh: "入职手续", textId: "Proses onboarding", exampleZh: "新人先办完入职手续。", exampleId: "Karyawan baru selesaikan dulu proses onboarding."),
            VocabItem(id: "w32", textZh: "打卡上班", textId: "Absen masuk", exampleZh: "记得早上先打卡上班。", exampleId: "Ingat pagi-pagi absen masuk dulu."),
            VocabItem(id: "w33", textZh: "打卡下班", textId: "Absen pulang", exampleZh: "别忘了下班前打卡。", exampleId: "Jangan lupa absen pulang sebelum keluar."),
            VocabItem(id: "w34", textZh: "办公设备", textId: "Peralatan kantor", exampleZh: "办公设备坏了要及时报修。", exampleId: "Kalau peralatan kantor rusak segera lapor perbaikan."),
            VocabItem(id: "w35", textZh: "人事部门", textId: "Bagian HR", exampleZh: "有问题可以问人事部门。", exampleId: "Kalau ada masalah bisa tanya bagian HR."),
            VocabItem(id: "w36", textZh: "试用期反馈", textId: "Umpan balik masa percobaan", exampleZh: "月底会给你试用期反馈。", exampleId: "Akhir bulan kami beri umpan balik masa percobaan."),
            VocabItem(id: "w37", textZh: "请确认一下", textId: "Mohon dikonfirmasi", exampleZh: "文件发你了，请确认一下。", exampleId: "Dokumen sudah saya kirim, mohon dikonfirmasi."),
            VocabItem(id: "w38", textZh: "更新进度", textId: "Perbarui progres", exampleZh: "群里及时更新一下进度。", exampleId: "Mohon perbarui progres di grup."),
            VocabItem(id: "w39", textZh: "换个时间", textId: "Ganti jadwal", exampleZh: "这个会议我们能不能换个时间？", exampleId: "Bisa tidak kita ganti jadwal rapat ini?"),
            VocabItem(id: "w40", textZh: "跨部门协作", textId: "Kolaborasi lintas divisi", exampleZh: "这是一个跨部门协作项目。", exampleId: "Ini proyek kolaborasi lintas divisi."),
            VocabItem(id: "w41", textZh: "年度目标", textId: "Target tahunan", exampleZh: "我们先对齐一下年度目标。", exampleId: "Mari selaraskan dulu target tahunan."),
            VocabItem(id: "w42", textZh: "OKR", textId: "OKR", exampleZh: "本季度需要更新 OKR。", exampleId: "Kuartal ini kita harus memperbarui OKR."),
            VocabItem(id: "w43", textZh: "绩效面谈", textId: "One-on-one kinerja", exampleZh: "下周和你做一次绩效面谈。", exampleId: "Minggu depan kita one-on-one bahas kinerja."),
            VocabItem(id: "w44", textZh: "交接工作", textId: "Serah terima pekerjaan", exampleZh: "离职前要做好工作交接。", exampleId: "Sebelum resign harus bereskan serah terima pekerjaan."),
            VocabItem(id: "w45", textZh: "内部通知", textId: "Pengumuman internal", exampleZh: "最新的内部通知在邮箱里。", exampleId: "Pengumuman internal terbaru ada di email."),
            VocabItem(id: "w46", textZh: "公司制度", textId: "Peraturan perusahaan", exampleZh: "新员工要先了解公司制度。", exampleId: "Karyawan baru harus memahami peraturan perusahaan."),
            VocabItem(id: "w47", textZh: "薪资调整", textId: "Penyesuaian gaji", exampleZh: "每年会有一次薪资调整。", exampleId: "Setiap tahun ada penyesuaian gaji."),
            VocabItem(id: "w48", textZh: "团队建设", textId: "Team building", exampleZh: "周末有团队建设活动。", exampleId: "Akhir pekan ada kegiatan team building."),
            VocabItem(id: "w49", textZh: "会议链接", textId: "Link rapat", exampleZh: "稍后把会议链接发到群里。", exampleId: "Nanti kirim link rapat ke grup."),
            VocabItem(id: "w50", textZh: "共享文档", textId: "Dokumen bersama", exampleZh: "资料放在共享文档里。", exampleId: "Materi ada di dokumen bersama."),
            VocabItem(id: "w51", textZh: "上级审批", textId: "Persetujuan atasan", exampleZh: "这笔费用需要上级审批。", exampleId: "Biaya ini perlu persetujuan atasan."),
            VocabItem(id: "w52", textZh: "同频沟通", textId: "Tetap seirama komunikasi", exampleZh: "有变动及时同频沟通。", exampleId: "Kalau ada perubahan segera komunikasikan supaya tetap seirama.")
        ]
        return VocabCategory(
            id: "work",
            nameZh: "职场沟通",
            nameId: "Komunikasi kerja",
            items: items
        )
    }

    /// 新增：校园生活
    static var campusCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "c1", textZh: "上课", textId: "Masuk kelas", exampleZh: "八点正式上课。", exampleId: "Jam delapan kelas dimulai."),
            VocabItem(id: "c2", textZh: "点名", textId: "Absen", exampleZh: "老师先点个名。", exampleId: "Guru absen dulu."),
            VocabItem(id: "c3", textZh: "自习", textId: "Belajar mandiri", exampleZh: "晚上教室开放自习。", exampleId: "Malam hari kelas dibuka untuk belajar mandiri."),
            VocabItem(id: "c4", textZh: "图书馆", textId: "Perpustakaan", exampleZh: "我们去图书馆复习吧。", exampleId: "Ayo kita ke perpustakaan untuk belajar."),
            VocabItem(id: "c5", textZh: "借书证", textId: "Kartu perpustakaan", exampleZh: "办一张借书证很方便。", exampleId: "Punya kartu perpustakaan itu praktis."),
            VocabItem(id: "c6", textZh: "课表", textId: "Jadwal pelajaran", exampleZh: "新学期的课表出了。", exampleId: "Jadwal pelajaran semester baru sudah keluar."),
            VocabItem(id: "c7", textZh: "选修课", textId: "Mata kuliah pilihan", exampleZh: "这门是很热门的选修课。", exampleId: "Ini mata kuliah pilihan yang populer."),
            VocabItem(id: "c8", textZh: "必修课", textId: "Mata kuliah wajib", exampleZh: "必修课不能随便缺勤。", exampleId: "Mata kuliah wajib tidak boleh sering absen."),
            VocabItem(id: "c9", textZh: "考试周", textId: "Minggu ujian", exampleZh: "考试周大家都很紧张。", exampleId: "Minggu ujian semua orang tegang."),
            VocabItem(id: "c10", textZh: "期中考试", textId: "Ujian tengah semester", exampleZh: "下周有期中考试。", exampleId: "Minggu depan ada ujian tengah semester."),
            VocabItem(id: "c11", textZh: "期末考试", textId: "Ujian akhir semester", exampleZh: "要准备期末考试了。", exampleId: "Sudah waktunya siap-siap ujian akhir semester."),
            VocabItem(id: "c12", textZh: "成绩单", textId: "Transkrip nilai", exampleZh: "成绩单下个月发。", exampleId: "Transkrip nilai dibagikan bulan depan."),
            VocabItem(id: "c13", textZh: "宿舍", textId: "Asrama", exampleZh: "你住在学校宿舍吗？", exampleId: "Kamu tinggal di asrama kampus?"),
            VocabItem(id: "c14", textZh: "室友", textId: "Teman sekamar", exampleZh: "我和三个室友一起住。", exampleId: "Saya tinggal dengan tiga teman sekamar."),
            VocabItem(id: "c15", textZh: "食堂", textId: "Kantin kampus", exampleZh: "中午去食堂吃饭吧。", exampleId: "Siang kita makan di kantin kampus."),
            VocabItem(id: "c16", textZh: "社团", textId: "UKM / klub", exampleZh: "你参加了什么社团？", exampleId: "Kamu ikut UKM apa?"),
            VocabItem(id: "c17", textZh: "迎新会", textId: "Acara orientasi", exampleZh: "新生都有迎新会。", exampleId: "Mahasiswa baru ada acara orientasi."),
            VocabItem(id: "c18", textZh: "辅导员", textId: "Pembimbing akademik", exampleZh: "有事可以找辅导员聊聊。", exampleId: "Kalau ada masalah bisa bicara dengan pembimbing akademik."),
            VocabItem(id: "c19", textZh: "请假条", textId: "Surat izin", exampleZh: "生病要交请假条。", exampleId: "Kalau sakit harus menyerahkan surat izin."),
            VocabItem(id: "c20", textZh: "课堂讨论", textId: "Diskusi kelas", exampleZh: "这节课有小组讨论。", exampleId: "Di kelas ini ada diskusi kelompok."),
            VocabItem(id: "c21", textZh: "小组作业", textId: "Tugas kelompok", exampleZh: "我们分工完成小组作业。", exampleId: "Kita bagi tugas untuk tugas kelompok."),
            VocabItem(id: "c22", textZh: "演讲汇报", textId: "Presentasi", exampleZh: "下周要做课题演讲。", exampleId: "Minggu depan harus presentasi topik."),
            VocabItem(id: "c23", textZh: "毕业论文", textId: "Skripsi / tugas akhir", exampleZh: "大四要写毕业论文。", exampleId: "Semester akhir harus menulis skripsi."),
            VocabItem(id: "c24", textZh: "导师", textId: "Dosen pembimbing", exampleZh: "先和导师约个时间。", exampleId: "Buat janji dulu dengan dosen pembimbing."),
            VocabItem(id: "c25", textZh: "学分", textId: "SKS", exampleZh: "这门课有三学分。", exampleId: "Mata kuliah ini tiga SKS."),
            VocabItem(id: "c26", textZh: "挂科", textId: "Tidak lulus mata kuliah", exampleZh: "挂科就要重修。", exampleId: "Kalau tidak lulus harus mengulang."),
            VocabItem(id: "c27", textZh: "重修", textId: "Mengulang mata kuliah", exampleZh: "我明年要重修这门课。", exampleId: "Tahun depan saya harus mengulang mata kuliah ini."),
            VocabItem(id: "c28", textZh: "校车", textId: "Bus kampus", exampleZh: "校车几点发车？", exampleId: "Bus kampus berangkat jam berapa?"),
            VocabItem(id: "c29", textZh: "操场", textId: "Lapangan olahraga", exampleZh: "晚上去操场跑步。", exampleId: "Malam kita lari di lapangan."),
            VocabItem(id: "c30", textZh: "社团招新", textId: "Rekrutmen UKM", exampleZh: "社团这周在招新。", exampleId: "UKM minggu ini sedang rekrutmen anggota baru."),
            VocabItem(id: "c31", textZh: "奖学金", textId: "Beasiswa", exampleZh: "成绩好可以申请奖学金。", exampleId: "Kalau nilainya bagus bisa ajukan beasiswa."),
            VocabItem(id: "c32", textZh: "教务处", textId: "Bagian akademik", exampleZh: "选课问题去教务处问。", exampleId: "Masalah KRS tanya ke bagian akademik."),
            VocabItem(id: "c33", textZh: "课堂签到", textId: "Absensi kelas", exampleZh: "记得课堂签到。", exampleId: "Ingat isi absensi kelas."),
            VocabItem(id: "c34", textZh: "实验课", textId: "Praktikum", exampleZh: "今天下午有实验课。", exampleId: "Sore ini ada praktikum."),
            VocabItem(id: "c35", textZh: "实习", textId: "Magang", exampleZh: "大三开始可以去公司实习。", exampleId: "Semester tiga sudah bisa magang di perusahaan."),
            VocabItem(id: "c36", textZh: "毕业典礼", textId: "Wisuda", exampleZh: "下个月是毕业典礼。", exampleId: "Bulan depan ada wisuda."),
            VocabItem(id: "c37", textZh: "校园卡", textId: "Kartu mahasiswa", exampleZh: "进图书馆要刷校园卡。", exampleId: "Masuk perpustakaan harus tap kartu mahasiswa."),
            VocabItem(id: "c38", textZh: "打印作业", textId: "Cetak tugas", exampleZh: "先去打印店打印作业。", exampleId: "Pergi ke fotokopi dulu untuk cetak tugas."),
            VocabItem(id: "c39", textZh: "课程评价", textId: "Evaluasi mata kuliah", exampleZh: "期末要做课程评价。", exampleId: "Akhir semester harus isi evaluasi mata kuliah."),
            VocabItem(id: "c40", textZh: "同学聚会", textId: "Reuni teman sekelas", exampleZh: "周末有个小型同学聚会。", exampleId: "Akhir pekan ada reuni kecil teman sekelas."),
            VocabItem(id: "c41", textZh: "学习小组", textId: "Kelompok belajar", exampleZh: "我们组建一个学习小组吧。", exampleId: "Mari bentuk kelompok belajar."),
            VocabItem(id: "c42", textZh: "挂科警告", textId: "Peringatan akademik", exampleZh: "连着两门挂科会收到警告。", exampleId: "Kalau dua mata kuliah tidak lulus akan ada peringatan akademik."),
            VocabItem(id: "c43", textZh: "校园活动", textId: "Kegiatan kampus", exampleZh: "今天广场有校园活动。", exampleId: "Hari ini di lapangan ada kegiatan kampus."),
            VocabItem(id: "c44", textZh: "助教", textId: "Asisten dosen", exampleZh: "有问题可以先问助教。", exampleId: "Kalau bingung bisa tanya asisten dosen dulu."),
            VocabItem(id: "c45", textZh: "课程大纲", textId: "Silabus", exampleZh: "老师发了课程大纲。", exampleId: "Dosen sudah kirim silabus."),
            VocabItem(id: "c46", textZh: "学费", textId: "Biaya kuliah", exampleZh: "学费要按时缴。", exampleId: "Biaya kuliah harus dibayar tepat waktu."),
            VocabItem(id: "c47", textZh: "宿舍熄灯", textId: "Jam lampu padam", exampleZh: "十点之后宿舍熄灯。", exampleId: "Setelah jam sepuluh lampu asrama dimatikan."),
            VocabItem(id: "c48", textZh: "午休时间", textId: "Jam istirahat siang", exampleZh: "中午十二点是午休时间。", exampleId: "Jam dua belas siang adalah waktu istirahat."),
            VocabItem(id: "c49", textZh: "校园广播", textId: "Radio kampus", exampleZh: "校园广播每天放音乐。", exampleId: "Radio kampus setiap hari memutar musik."),
            VocabItem(id: "c50", textZh: "毕业照", textId: "Foto kelulusan", exampleZh: "别忘了拍毕业照。", exampleId: "Jangan lupa foto kelulusan."),
            VocabItem(id: "c51", textZh: "辅导课", textId: "Kelas tambahan", exampleZh: "考试前会加一节辅导课。", exampleId: "Sebelum ujian ada kelas tambahan."),
            VocabItem(id: "c52", textZh: "实训基地", textId: "Pusat pelatihan", exampleZh: "学校有自己的实训基地。", exampleId: "Kampus punya pusat pelatihan sendiri.")
        ]
        return VocabCategory(
            id: "campus",
            nameZh: "校园生活",
            nameId: "Kehidupan kampus",
            items: items
        )
    }

    /// 新增：医疗健康
    static var healthCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "h1", textZh: "挂号", textId: "Daftar nomor antrian", exampleZh: "先去前台挂号。", exampleId: "Daftar nomor antrian di loket dulu."),
            VocabItem(id: "h2", textZh: "候诊", textId: "Menunggu giliran", exampleZh: "请在候诊区等一下。", exampleId: "Silakan tunggu di ruang tunggu."),
            VocabItem(id: "h3", textZh: "全科医生", textId: "Dokter umum", exampleZh: "我先看全科医生。", exampleId: "Saya periksa ke dokter umum dulu."),
            VocabItem(id: "h4", textZh: "专科医生", textId: "Dokter spesialis", exampleZh: "严重的话要看专科医生。", exampleId: "Kalau parah harus ke dokter spesialis."),
            VocabItem(id: "h5", textZh: "病历本", textId: "Buku rekam medis", exampleZh: "别忘了带病历本。", exampleId: "Jangan lupa bawa buku rekam medis."),
            VocabItem(id: "h6", textZh: "量体温", textId: "Ukur suhu badan", exampleZh: "护士先帮你量体温。", exampleId: "Perawat akan mengukur suhu badan dulu."),
            VocabItem(id: "h7", textZh: "量血压", textId: "Ukur tekanan darah", exampleZh: "每次复查都要量血压。", exampleId: "Setiap kontrol harus ukur tekanan darah."),
            VocabItem(id: "h8", textZh: "验血", textId: "Tes darah", exampleZh: "医生开了验血检查。", exampleId: "Dokter memberikan rujukan tes darah."),
            VocabItem(id: "h9", textZh: "化验单", textId: "Form hasil lab", exampleZh: "拿着化验单去楼上。", exampleId: "Bawa form hasil lab ke lantai atas."),
            VocabItem(id: "h10", textZh: "处方", textId: "Resep obat", exampleZh: "医生给我开了三种药。", exampleId: "Dokter memberikan tiga jenis obat."),
            VocabItem(id: "h11", textZh: "药房", textId: "Apotek rumah sakit", exampleZh: "拿处方去药房取药。", exampleId: "Bawa resep ke apotek rumah sakit."),
            VocabItem(id: "h12", textZh: "按时吃药", textId: "Minum obat tepat waktu", exampleZh: "记得按时吃药。", exampleId: "Ingat minum obat tepat waktu."),
            VocabItem(id: "h13", textZh: "体检", textId: "Medical check-up", exampleZh: "公司每年组织一次体检。", exampleId: "Perusahaan mengadakan medical check-up tiap tahun."),
            VocabItem(id: "h14", textZh: "疫苗", textId: "Vaksin", exampleZh: "小孩要按时打疫苗。", exampleId: "Anak harus vaksin tepat waktu."),
            VocabItem(id: "h15", textZh: "过敏史", textId: "Riwayat alergi", exampleZh: "有过敏史要提前告诉医生。", exampleId: "Kalau ada riwayat alergi harus beritahu dokter."),
            VocabItem(id: "h16", textZh: "慢性病", textId: "Penyakit kronis", exampleZh: "我有慢性病，需要长期吃药。", exampleId: "Saya punya penyakit kronis, harus minum obat jangka panjang."),
            VocabItem(id: "h17", textZh: "挂急诊", textId: "Masuk IGD", exampleZh: "情况紧急需要挂急诊。", exampleId: "Kondisinya darurat, harus masuk IGD."),
            VocabItem(id: "h18", textZh: "住院", textId: "Rawat inap", exampleZh: "医生建议住院观察。", exampleId: "Dokter menyarankan rawat inap untuk observasi."),
            VocabItem(id: "h19", textZh: "病房", textId: "Kamar pasien", exampleZh: "他在三楼病房。", exampleId: "Dia dirawat di kamar lantai tiga."),
            VocabItem(id: "h20", textZh: "手术", textId: "Operasi", exampleZh: "明天上午安排手术。", exampleId: "Operasi dijadwalkan besok pagi."),
            VocabItem(id: "h21", textZh: "麻醉", textId: "Anestesi", exampleZh: "手术前要先打麻醉。", exampleId: "Sebelum operasi akan diberi anestesi."),
            VocabItem(id: "h22", textZh: "康复", textId: "Pemulihan", exampleZh: "术后需要一段时间康复。", exampleId: "Setelah operasi perlu waktu pemulihan."),
            VocabItem(id: "h23", textZh: "复查", textId: "Kontrol ulang", exampleZh: "下周记得来医院复查。", exampleId: "Minggu depan jangan lupa kontrol ulang."),
            VocabItem(id: "h24", textZh: "挂盐水", textId: "Infus", exampleZh: "他在输液挂盐水。", exampleId: "Dia sedang diinfus."),
            VocabItem(id: "h25", textZh: "体重管理", textId: "Mengontrol berat badan", exampleZh: "医生建议控制体重。", exampleId: "Dokter menyarankan mengontrol berat badan."),
            VocabItem(id: "h26", textZh: "血糖", textId: "Gula darah", exampleZh: "要定期检查血糖。", exampleId: "Perlu cek gula darah secara rutin."),
            VocabItem(id: "h27", textZh: "血压偏高", textId: "Tekanan darah tinggi", exampleZh: "最近血压有点偏高。", exampleId: "Akhir-akhir ini tekanan darah agak tinggi."),
            VocabItem(id: "h28", textZh: "营养均衡", textId: "Gizi seimbang", exampleZh: "注意饮食营养均衡。", exampleId: "Perhatikan pola makan bergizi seimbang."),
            VocabItem(id: "h29", textZh: "多喝水", textId: "Banyak minum air", exampleZh: "感冒时要多喝水。", exampleId: "Kalau flu harus banyak minum air."),
            VocabItem(id: "h30", textZh: "早睡早起", textId: "Tidur cukup", exampleZh: "保持早睡早起的习惯。", exampleId: "Biasakan tidur cukup dan bangun pagi."),
            VocabItem(id: "h31", textZh: "适量运动", textId: "Olahraga secukupnya", exampleZh: "医生建议多做适量运动。", exampleId: "Dokter menyarankan olahraga secukupnya."),
            VocabItem(id: "h32", textZh: "心理咨询", textId: "Konseling psikolog", exampleZh: "可以预约心理咨询。", exampleId: "Bisa membuat janji konseling psikolog."),
            VocabItem(id: "h33", textZh: "睡眠质量", textId: "Kualitas tidur", exampleZh: "最近睡眠质量不好。", exampleId: "Akhir-akhir ini kualitas tidur kurang baik."),
            VocabItem(id: "h34", textZh: "体脂率", textId: "Persentase lemak tubuh", exampleZh: "体脂率有点偏高。", exampleId: "Persentase lemak tubuh agak tinggi."),
            VocabItem(id: "h35", textZh: "健康体检报告", textId: "Laporan medical check-up", exampleZh: "体检报告出来了。", exampleId: "Laporan medical check-up sudah keluar."),
            VocabItem(id: "h36", textZh: "感冒发烧", textId: "Masuk angin dan demam", exampleZh: "他感冒发烧请假在家。", exampleId: "Dia masuk angin dan demam, izin di rumah."),
            VocabItem(id: "h37", textZh: "消毒", textId: "Desinfeksi", exampleZh: "伤口要先消毒再包扎。", exampleId: "Luka harus didesinfeksi sebelum dibalut."),
            VocabItem(id: "h38", textZh: "创可贴", textId: "Plester luka", exampleZh: "小伤口贴个创可贴就行。", exampleId: "Luka kecil cukup pakai plester."),
            VocabItem(id: "h39", textZh: "晕车药", textId: "Obat mabuk perjalanan", exampleZh: "出门前先吃点晕车药。", exampleId: "Sebelum berangkat minum obat mabuk dulu."),
            VocabItem(id: "h40", textZh: "急救电话", textId: "Nomor darurat", exampleZh: "记住当地的急救电话。", exampleId: "Hafalkan nomor darurat setempat."),
            VocabItem(id: "h41", textZh: "挂号费", textId: "Biaya pendaftaran", exampleZh: "挂号费可以用医保报销。", exampleId: "Biaya pendaftaran bisa diganti BPJS."),
            VocabItem(id: "h42", textZh: "医保卡", textId: "Kartu BPJS", exampleZh: "看病记得带医保卡。", exampleId: "Kalau berobat jangan lupa bawa kartu BPJS."),
            VocabItem(id: "h43", textZh: "体温计", textId: "Termometer", exampleZh: "家里常备一支体温计。", exampleId: "Di rumah sebaiknya ada termometer."),
            VocabItem(id: "h44", textZh: "口罩", textId: "Masker", exampleZh: "人多的地方要戴口罩。", exampleId: "Di tempat ramai sebaiknya pakai masker."),
            VocabItem(id: "h45", textZh: "核酸检测", textId: "Tes PCR", exampleZh: "出国前要做核酸检测。", exampleId: "Sebelum ke luar negeri harus tes PCR."),
            VocabItem(id: "h46", textZh: "抗原检测", textId: "Tes antigen", exampleZh: "有症状可以先做抗原检测。", exampleId: "Kalau ada gejala bisa tes antigen dulu."),
            VocabItem(id: "h47", textZh: "恢复期", textId: "Masa pemulihan", exampleZh: "恢复期不要太劳累。", exampleId: "Selama masa pemulihan jangan terlalu capek."),
            VocabItem(id: "h48", textZh: "营养师", textId: "Ahli gizi", exampleZh: "可以咨询营养师调整饮食。", exampleId: "Bisa konsultasi ke ahli gizi untuk atur pola makan."),
            VocabItem(id: "h49", textZh: "理疗", textId: "Terapi fisik", exampleZh: "腰痛需要做一段时间理疗。", exampleId: "Nyeri pinggang perlu terapi fisik."),
            VocabItem(id: "h50", textZh: "健康档案", textId: "Rekam kesehatan", exampleZh: "社区医院会建立健康档案。", exampleId: "Puskesmas akan membuat rekam kesehatan."),
            VocabItem(id: "h51", textZh: "预约挂号", textId: "Daftar online", exampleZh: "可以用手机预约挂号。", exampleId: "Bisa daftar nomor antrian lewat HP."),
            VocabItem(id: "h52", textZh: "慢病随访", textId: "Kontrol rutin penyakit kronis", exampleZh: "社区医生会定期做随访。", exampleId: "Dokter puskesmas akan kontrol rutin.")
        ]
        return VocabCategory(
            id: "health",
            nameZh: "医疗健康",
            nameId: "Kesehatan",
            items: items
        )
    }

    /// 新增：家庭生活
    static var familyCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "fa1", textZh: "做家务", textId: "Mengerjakan pekerjaan rumah", exampleZh: "周末一起做家务。", exampleId: "Akhir pekan kita kerjakan pekerjaan rumah bersama."),
            VocabItem(id: "fa2", textZh: "买菜", textId: "Belanja sayur", exampleZh: "下班顺路去买菜。", exampleId: "Pulang kerja sekalian belanja sayur."),
            VocabItem(id: "fa3", textZh: "做饭", textId: "Masak", exampleZh: "今天晚上谁做饭？", exampleId: "Malam ini siapa yang masak?"),
            VocabItem(id: "fa4", textZh: "洗碗", textId: "Cuci piring", exampleZh: "吃完饭记得洗碗。", exampleId: "Setelah makan jangan lupa cuci piring."),
            VocabItem(id: "fa5", textZh: "打扫卫生", textId: "Bersih-bersih rumah", exampleZh: "周六上午打扫卫生。", exampleId: "Sabtu pagi kita bersih-bersih rumah."),
            VocabItem(id: "fa6", textZh: "拖地", textId: "Pel lantai", exampleZh: "地有点脏，拖一下地。", exampleId: "Lantainya agak kotor, pel sebentar."),
            VocabItem(id: "fa7", textZh: "洗衣服", textId: "Cuci baju", exampleZh: "衣服多了，开机洗衣服。", exampleId: "Bajunya sudah banyak, nyalakan mesin cuci."),
            VocabItem(id: "fa8", textZh: "晾衣服", textId: "Menjemur baju", exampleZh: "洗好的衣服拿去晾。", exampleId: "Baju yang sudah dicuci dijemur."),
            VocabItem(id: "fa9", textZh: "叠衣服", textId: "Melipat baju", exampleZh: "晚上把衣服叠好。", exampleId: "Malam lipat baju yang sudah kering."),
            VocabItem(id: "fa10", textZh: "带孩子", textId: "Mengasuh anak", exampleZh: "周末轮流带孩子。", exampleId: "Akhir pekan kita bergantian mengasuh anak."),
            VocabItem(id: "fa11", textZh: "辅导作业", textId: "Mendampingi PR", exampleZh: "晚上帮孩子辅导作业。", exampleId: "Malam temani anak mengerjakan PR."),
            VocabItem(id: "fa12", textZh: "家庭聚餐", textId: "Makan bersama keluarga", exampleZh: "周日中午家庭聚餐。", exampleId: "Makan siang hari Minggu bersama keluarga."),
            VocabItem(id: "fa13", textZh: "看电视", textId: "Nonton TV", exampleZh: "一家人一起看电视。", exampleId: "Satu keluarga nonton TV bersama."),
            VocabItem(id: "fa14", textZh: "家庭会议", textId: "Rapat keluarga", exampleZh: "有事可以开个家庭会议。", exampleId: "Kalau ada hal penting bisa rapat keluarga."),
            VocabItem(id: "fa15", textZh: "关心父母", textId: "Perhatian kepada orang tua", exampleZh: "多打电话关心父母。", exampleId: "Sering-sering telepon orang tua."),
            VocabItem(id: "fa16", textZh: "接送孩子", textId: "Antar jemput anak", exampleZh: "早上我去接送孩子上学。", exampleId: "Pagi saya antar jemput anak ke sekolah."),
            VocabItem(id: "fa17", textZh: "午睡", textId: "Tidur siang", exampleZh: "吃完饭让孩子午睡一会儿。", exampleId: "Setelah makan biarkan anak tidur siang."),
            VocabItem(id: "fa18", textZh: "哄睡", textId: "Menidurkan anak", exampleZh: "晚上要哄孩子睡觉。", exampleId: "Malam harus menidurkan anak."),
            VocabItem(id: "fa19", textZh: "讲故事", textId: "Menceritakan dongeng", exampleZh: "睡前给孩子讲故事。", exampleId: "Sebelum tidur ceritakan dongeng untuk anak."),
            VocabItem(id: "fa20", textZh: "家庭预算", textId: "Anggaran rumah tangga", exampleZh: "每个月做一次家庭预算。", exampleId: "Setiap bulan buat anggaran rumah tangga."),
            VocabItem(id: "fa21", textZh: "生活费用", textId: "Biaya hidup", exampleZh: "要控制一下生活费用。", exampleId: "Harus mengontrol biaya hidup."),
            VocabItem(id: "fa22", textZh: "水电费", textId: "Tagihan listrik dan air", exampleZh: "水电费要按时缴。", exampleId: "Tagihan listrik dan air harus dibayar tepat waktu."),
            VocabItem(id: "fa23", textZh: "网费", textId: "Biaya internet", exampleZh: "到期前记得交网费。", exampleId: "Sebelum jatuh tempo bayar biaya internet."),
            VocabItem(id: "fa24", textZh: "房租", textId: "Sewa rumah", exampleZh: "房租每三个月一交。", exampleId: "Sewa rumah dibayar tiga bulanan."),
            VocabItem(id: "fa25", textZh: "家庭氛围", textId: "Suasana keluarga", exampleZh: "营造轻松的家庭氛围。", exampleId: "Ciptakan suasana keluarga yang hangat."),
            VocabItem(id: "fa26", textZh: "周末出游", textId: "Jalan-jalan akhir pekan", exampleZh: "周末带家人出去走走。", exampleId: "Akhir pekan ajak keluarga jalan-jalan."),
            VocabItem(id: "fa27", textZh: "家庭照片", textId: "Foto keluarga", exampleZh: "每年拍一张家庭照片。", exampleId: "Setiap tahun ambil foto keluarga."),
            VocabItem(id: "fa28", textZh: "生日聚会", textId: "Pesta ulang tahun", exampleZh: "给孩子办个生日聚会。", exampleId: "Adakan pesta ulang tahun untuk anak."),
            VocabItem(id: "fa29", textZh: "买家具", textId: "Beli perabot", exampleZh: "周末去看一下家具。", exampleId: "Akhir pekan lihat-lihat perabot."),
            VocabItem(id: "fa30", textZh: "换床单", textId: "Ganti seprai", exampleZh: "隔一段时间记得换床单。", exampleId: "Secara berkala ganti seprai."),
            VocabItem(id: "fa31", textZh: "倒垃圾", textId: "Buang sampah", exampleZh: "晚上记得倒垃圾。", exampleId: "Malam jangan lupa buang sampah."),
            VocabItem(id: "fa32", textZh: "浇花", textId: "Menyiram bunga", exampleZh: "每天早上浇一次花。", exampleId: "Setiap pagi siram bunga."),
            VocabItem(id: "fa33", textZh: "养宠物", textId: "Memelihara hewan", exampleZh: "全家一起照顾宠物。", exampleId: "Satu keluarga bersama-sama merawat hewan peliharaan."),
            VocabItem(id: "fa34", textZh: "家庭规则", textId: "Aturan keluarga", exampleZh: "可以一起制定家庭规则。", exampleId: "Bisa membuat aturan keluarga bersama-sama."),
            VocabItem(id: "fa35", textZh: "亲子时间", textId: "Waktu bersama anak", exampleZh: "每天留一点亲子时间。", exampleId: "Setiap hari sisihkan waktu bersama anak."),
            VocabItem(id: "fa36", textZh: "午后茶", textId: "Teh sore", exampleZh: "周末一起喝个午后茶。", exampleId: "Akhir pekan minum teh sore bersama."),
            VocabItem(id: "fa37", textZh: "家庭电影夜", textId: "Malam nonton film keluarga", exampleZh: "周五来个家庭电影夜。", exampleId: "Jumat malam adakan malam nonton film keluarga."),
            VocabItem(id: "fa38", textZh: "修理电器", textId: "Memperbaiki alat listrik", exampleZh: "家里电器坏了要尽快修。", exampleId: "Kalau alat listrik rusak harus cepat diperbaiki."),
            VocabItem(id: "fa39", textZh: "换灯泡", textId: "Ganti lampu", exampleZh: "走廊的灯泡需要换了。", exampleId: "Lampu koridor perlu diganti."),
            VocabItem(id: "fa40", textZh: "收纳整理", textId: "Merapikan barang", exampleZh: "周末做一次收纳整理。", exampleId: "Akhir pekan bereskan dan rapikan barang-barang."),
            VocabItem(id: "fa41", textZh: "节约用水", textId: "Hemat air", exampleZh: "全家一起养成节约用水的习惯。", exampleId: "Satu keluarga biasakan hemat air."),
            VocabItem(id: "fa42", textZh: "节约用电", textId: "Hemat listrik", exampleZh: "不用的电器记得关掉。", exampleId: "Matikan alat listrik yang tidak dipakai."),
            VocabItem(id: "fa43", textZh: "安全用气", textId: "Aman menggunakan gas", exampleZh: "做饭完要关好煤气。", exampleId: "Setelah masak pastikan gas tertutup rapat."),
            VocabItem(id: "fa44", textZh: "备急用药", textId: "Sedia obat darurat", exampleZh: "家里常备一些急用药。", exampleId: "Di rumah sebaiknya ada obat darurat."),
            VocabItem(id: "fa45", textZh: "家庭相册", textId: "Album keluarga", exampleZh: "周末整理一下家庭相册。", exampleId: "Akhir pekan rapikan album keluarga."),
            VocabItem(id: "fa46", textZh: "教育孩子", textId: "Mendidik anak", exampleZh: "教育孩子要有耐心。", exampleId: "Mendidik anak perlu kesabaran."),
            VocabItem(id: "fa47", textZh: "尊重长辈", textId: "Menghormati orang yang lebih tua", exampleZh: "在家要学会尊重长辈。", exampleId: "Di rumah kita belajar menghormati orang yang lebih tua."),
            VocabItem(id: "fa48", textZh: "家庭支出记录", textId: "Catatan pengeluaran keluarga", exampleZh: "可以用表格记家庭支出。", exampleId: "Bisa pakai tabel untuk mencatat pengeluaran keluarga."),
            VocabItem(id: "fa49", textZh: "节日布置", textId: "Dekorasi hari raya", exampleZh: "节日的时候布置一下房间。", exampleId: "Saat hari raya dekorasi rumah sedikit."),
            VocabItem(id: "fa50", textZh: "亲戚走访", textId: "Mengunjungi kerabat", exampleZh: "过年要去走亲戚。", exampleId: "Saat Tahun Baru kita kunjungi kerabat."),
            VocabItem(id: "fa51", textZh: "家庭日", textId: "Hari keluarga", exampleZh: "每个月定一个家庭日。", exampleId: "Setiap bulan tetapkan satu hari keluarga."),
            VocabItem(id: "fa52", textZh: "互相体谅", textId: "Saling mengerti", exampleZh: "家人之间要多互相体谅。", exampleId: "Dalam keluarga harus saling mengerti.")
        ]
        return VocabCategory(
            id: "family",
            nameZh: "家庭生活",
            nameId: "Kehidupan rumah tangga",
            items: items
        )
    }

    /// 新增：金融理财
    static var financeCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "fina1", textZh: "收入", textId: "Pendapatan", exampleZh: "先算一算每月收入。", exampleId: "Hitung dulu pendapatan bulanan."),
            VocabItem(id: "fina2", textZh: "支出", textId: "Pengeluaran", exampleZh: "记录每一笔支出。", exampleId: "Catat setiap pengeluaran."),
            VocabItem(id: "fina3", textZh: "存款", textId: "Tabungan", exampleZh: "每月固定存一部分钱。", exampleId: "Setiap bulan sisihkan uang untuk tabungan."),
            VocabItem(id: "fina4", textZh: "预算", textId: "Anggaran", exampleZh: "我们做一个年度家庭预算。", exampleId: "Kita buat anggaran keluarga tahunan."),
            VocabItem(id: "fina5", textZh: "应急金", textId: "Dana darurat", exampleZh: "建议准备三到六个月的应急金。", exampleId: "Disarankan punya dana darurat tiga sampai enam bulan biaya hidup."),
            VocabItem(id: "fina6", textZh: "理财产品", textId: "Produk investasi", exampleZh: "投资前先了解理财产品的风险。", exampleId: "Sebelum investasi pahami dulu risiko produk."),
            VocabItem(id: "fina7", textZh: "银行账户", textId: "Rekening bank", exampleZh: "工资打到哪一个银行账户？", exampleId: "Gaji ditransfer ke rekening bank yang mana?"),
            VocabItem(id: "fina8", textZh: "信用卡", textId: "Kartu kredit", exampleZh: "使用信用卡要控制消费。", exampleId: "Pakai kartu kredit harus kendalikan belanja."),
            VocabItem(id: "fina9", textZh: "账单日", textId: "Tanggal tagihan", exampleZh: "记住信用卡账单日和还款日。", exampleId: "Ingat tanggal tagihan dan jatuh tempo kartu kredit."),
            VocabItem(id: "fina10", textZh: "分期付款", textId: "Cicilan", exampleZh: "这笔可以做十二期分期。", exampleId: "Pembayaran ini bisa dicicil 12 kali."),
            VocabItem(id: "fina11", textZh: "利息", textId: "Bunga", exampleZh: "要注意贷款利息。", exampleId: "Perhatikan bunga pinjaman."),
            VocabItem(id: "fina12", textZh: "年化收益", textId: "Imbal hasil tahunan", exampleZh: "不要只看年化收益，还要看风险。", exampleId: "Jangan hanya lihat imbal hasil tahunan, tapi juga risikonya."),
            VocabItem(id: "fina13", textZh: "定期存款", textId: "Deposito", exampleZh: "定期存款相对比较安全。", exampleId: "Deposito relatif lebih aman."),
            VocabItem(id: "fina14", textZh: "基金", textId: "Reksa dana", exampleZh: "基金适合长期定投。", exampleId: "Reksa dana cocok untuk investasi rutin jangka panjang."),
            VocabItem(id: "fina15", textZh: "股票", textId: "Saham", exampleZh: "投资股票要接受波动。", exampleId: "Investasi saham harus siap dengan fluktuasi."),
            VocabItem(id: "fina16", textZh: "风险承受能力", textId: "Profil risiko", exampleZh: "先评估自己的风险承受能力。", exampleId: "Nilai dulu profil risiko diri sendiri."),
            VocabItem(id: "fina17", textZh: "资产配置", textId: "Alokasi aset", exampleZh: "合理的资产配置很重要。", exampleId: "Alokasi aset yang seimbang itu penting."),
            VocabItem(id: "fina18", textZh: "现金流", textId: "Arus kas", exampleZh: "保持现金流为正。", exampleId: "Jaga agar arus kas tetap positif."),
            VocabItem(id: "fina19", textZh: "负债", textId: "Utang", exampleZh: "不要过度负债。", exampleId: "Jangan sampai punya utang berlebihan."),
            VocabItem(id: "fina20", textZh: "贷款", textId: "Pinjaman", exampleZh: "申请贷款前要仔细比较。", exampleId: "Sebelum ambil pinjaman bandingkan dulu pilihannya."),
            VocabItem(id: "fina21", textZh: "房贷", textId: "KPR", exampleZh: "房贷占收入的比例不要太高。", exampleId: "Cicilan KPR jangan terlalu besar porsinya dari pendapatan."),
            VocabItem(id: "fina22", textZh: "车贷", textId: "Kredit mobil", exampleZh: "买车前先算好车贷压力。", exampleId: "Sebelum beli mobil hitung dulu cicilannya."),
            VocabItem(id: "fina23", textZh: "保险", textId: "Asuransi", exampleZh: "适当配置一些保险。", exampleId: "Sebaiknya punya asuransi yang cukup."),
            VocabItem(id: "fina24", textZh: "寿险", textId: "Asuransi jiwa", exampleZh: "有家庭责任的人可以考虑寿险。", exampleId: "Yang punya tanggungan keluarga bisa mempertimbangkan asuransi jiwa."),
            VocabItem(id: "fina25", textZh: "医疗险", textId: "Asuransi kesehatan tambahan", exampleZh: "医疗险可以补充医保报销。", exampleId: "Asuransi kesehatan tambahan bisa melengkapi BPJS."),
            VocabItem(id: "fina26", textZh: "投保金额", textId: "Uang pertanggungan", exampleZh: "投保金额要根据家庭情况来定。", exampleId: "Uang pertanggungan disesuaikan dengan kondisi keluarga."),
            VocabItem(id: "fina27", textZh: "理财目标", textId: "Tujuan keuangan", exampleZh: "先写下你的理财目标。", exampleId: "Tulis dulu tujuan keuanganmu."),
            VocabItem(id: "fina28", textZh: "退休规划", textId: "Perencanaan pensiun", exampleZh: "越早做退休规划越好。", exampleId: "Makin cepat merencanakan pensiun makin baik."),
            VocabItem(id: "fina29", textZh: "教育基金", textId: "Dana pendidikan", exampleZh: "给孩子准备一笔教育基金。", exampleId: "Siapkan dana pendidikan untuk anak."),
            VocabItem(id: "fina30", textZh: "记账应用", textId: "Aplikasi pencatat keuangan", exampleZh: "可以用手机记账应用。", exampleId: "Bisa pakai aplikasi pencatat keuangan di HP."),
            VocabItem(id: "fina31", textZh: "通货膨胀", textId: "Inflasi", exampleZh: "长期存现金要考虑通货膨胀。", exampleId: "Kalau simpan uang tunai jangka panjang harus perhitungkan inflasi."),
            VocabItem(id: "fina32", textZh: "汇率", textId: "Kurs", exampleZh: "换外币前看看实时汇率。", exampleId: "Sebelum tukar valuta asing lihat kurs terbaru."),
            VocabItem(id: "fina33", textZh: "资产负债表", textId: "Neraca keuangan pribadi", exampleZh: "列一份自己的资产负债表。", exampleId: "Buat neraca keuangan pribadi."),
            VocabItem(id: "fina34", textZh: "消费观", textId: "Gaya konsumsi", exampleZh: "培养理性的消费观。", exampleId: "Bangun gaya konsumsi yang rasional."),
            VocabItem(id: "fina35", textZh: "记账习惯", textId: "Kebiasaan mencatat keuangan", exampleZh: "坚持一个月你就会养成记账习惯。", exampleId: "Kalau konsisten sebulan, kebiasaan mencatat akan terbentuk."),
            VocabItem(id: "fina36", textZh: "冲动消费", textId: "Belanja impulsif", exampleZh: "避免情绪化冲动消费。", exampleId: "Hindari belanja impulsif karena emosi."),
            VocabItem(id: "fina37", textZh: "理性决策", textId: "Keputusan yang rasional", exampleZh: "理财要做理性决策。", exampleId: "Dalam keuangan harus ambil keputusan dengan rasional."),
            VocabItem(id: "fina38", textZh: "资产增长", textId: "Pertumbuhan aset", exampleZh: "长期目标是让资产稳步增长。", exampleId: "Tujuan jangka panjang adalah membuat aset tumbuh stabil."),
            VocabItem(id: "fina39", textZh: "价值投资", textId: "Value investing", exampleZh: "价值投资更看重公司基本面。", exampleId: "Dalam value investing yang dilihat adalah fundamental perusahaan."),
            VocabItem(id: "fina40", textZh: "止损", textId: "Cut loss", exampleZh: "投资也要学会止损。", exampleId: "Dalam investasi juga harus tahu kapan cut loss."),
            VocabItem(id: "fina41", textZh: "收益率", textId: "Tingkat pengembalian", exampleZh: "比较不同产品的收益率。", exampleId: "Bandingkan tingkat pengembalian berbagai produk."),
            VocabItem(id: "fina42", textZh: "风险分散", textId: "Diversifikasi risiko", exampleZh: "不要把鸡蛋都放在一个篮子里。", exampleId: "Jangan menaruh semua telur dalam satu keranjang."),
            VocabItem(id: "fina43", textZh: "定投", textId: "Investasi rutin", exampleZh: "每月定投可以平滑成本。", exampleId: "Investasi rutin bulanan bisa meratakan harga."),
            VocabItem(id: "fina44", textZh: "短期目标", textId: "Tujuan jangka pendek", exampleZh: "旅行就是我们的短期目标之一。", exampleId: "Liburan adalah salah satu tujuan jangka pendek."),
            VocabItem(id: "fina45", textZh: "中期目标", textId: "Tujuan jangka menengah", exampleZh: "换车可以算作中期目标。", exampleId: "Ganti mobil bisa jadi tujuan jangka menengah."),
            VocabItem(id: "fina46", textZh: "长期目标", textId: "Tujuan jangka panjang", exampleZh: "退休生活是重要的长期目标。", exampleId: "Masa pensiun adalah tujuan jangka panjang yang penting."),
            VocabItem(id: "fina47", textZh: "财务自由", textId: "Kebebasan finansial", exampleZh: "很多人追求财务自由。", exampleId: "Banyak orang mengejar kebebasan finansial."),
            VocabItem(id: "fina48", textZh: "被动收入", textId: "Pendapatan pasif", exampleZh: "增加被动收入能提高安全感。", exampleId: "Menambah pendapatan pasif bisa meningkatkan rasa aman."),
            VocabItem(id: "fina49", textZh: "消费分级", textId: "Prioritas pengeluaran", exampleZh: "先分清必要和非必要消费。", exampleId: "Bedakan dulu pengeluaran penting dan tidak penting."),
            VocabItem(id: "fina50", textZh: "财务记录", textId: "Catatan keuangan", exampleZh: "每年整理一次财务记录。", exampleId: "Setiap tahun rapikan catatan keuangan."),
            VocabItem(id: "fina51", textZh: "利率变动", textId: "Perubahan suku bunga", exampleZh: "贷款利率变动会影响月供。", exampleId: "Perubahan suku bunga pinjaman memengaruhi cicilan bulanan."),
            VocabItem(id: "fina52", textZh: "理财知识", textId: "Pengetahuan finansial", exampleZh: "可以多学习一些理财知识。", exampleId: "Ada baiknya banyak belajar pengetahuan finansial.")
        ]
        return VocabCategory(
            id: "finance",
            nameZh: "金融理财",
            nameId: "Keuangan & investasi",
            items: items
        )
    }

    /// 新增：社交媒体
    static var socialCategory: VocabCategory {
        let items: [VocabItem] = [
            VocabItem(id: "s1", textZh: "点赞", textId: "Like", exampleZh: "这条内容我已经点赞了。", exampleId: "Saya sudah like konten ini."),
            VocabItem(id: "s2", textZh: "评论", textId: "Komentar", exampleZh: "欢迎在下方留言评论。", exampleId: "Silakan tinggalkan komentar di bawah."),
            VocabItem(id: "s3", textZh: "转发", textId: "Bagikan", exampleZh: "觉得有用可以转发给朋友。", exampleId: "Kalau bermanfaat boleh dibagikan ke teman."),
            VocabItem(id: "s4", textZh: "收藏", textId: "Simpan", exampleZh: "这篇干货我先收藏起来。", exampleId: "Konten yang bagus ini saya simpan dulu."),
            VocabItem(id: "s5", textZh: "关注账号", textId: "Follow akun", exampleZh: "喜欢的话可以关注这个账号。", exampleId: "Kalau suka bisa follow akun ini."),
            VocabItem(id: "s6", textZh: "取关", textId: "Unfollow", exampleZh: "不感兴趣就取关吧。", exampleId: "Kalau tidak tertarik bisa unfollow saja."),
            VocabItem(id: "s7", textZh: "私信", textId: "DM / pesan pribadi", exampleZh: "有问题可以私信我。", exampleId: "Kalau ada pertanyaan bisa DM saya."),
            VocabItem(id: "s8", textZh: "群聊", textId: "Grup chat", exampleZh: "我们在群聊里通知。", exampleId: "Kita umumkan di grup chat."),
            VocabItem(id: "s9", textZh: "置顶消息", textId: "Pesan yang dipin", exampleZh: "重要通知已经置顶。", exampleId: "Pengumuman penting sudah dipin."),
            VocabItem(id: "s10", textZh: "直播", textId: "Live streaming", exampleZh: "今晚八点开始直播。", exampleId: "Malam ini live mulai jam delapan."),
            VocabItem(id: "s11", textZh: "弹幕", textId: "Komentar berjalan", exampleZh: "弹幕有点多，看不清画面。", exampleId: "Komentar berjalan terlalu banyak jadi susah lihat layar."),
            VocabItem(id: "s12", textZh: "点赞破万", textId: "Like tembus sepuluh ribu", exampleZh: "这条视频点赞破万了。", exampleId: "Video ini like-nya sudah tembus sepuluh ribu."),
            VocabItem(id: "s13", textZh: "粉丝", textId: "Pengikut", exampleZh: "这个博主有很多粉丝。", exampleId: "Influencer ini punya banyak pengikut."),
            VocabItem(id: "s14", textZh: "博主", textId: "Content creator", exampleZh: "她是一个美食博主。", exampleId: "Dia adalah content creator kuliner."),
            VocabItem(id: "s15", textZh: "头像", textId: "Foto profil", exampleZh: "换一个清晰一点的头像。", exampleId: "Ganti foto profil yang lebih jelas."),
            VocabItem(id: "s16", textZh: "封面图", textId: "Gambar sampul", exampleZh: "给视频选一张好看的封面图。", exampleId: "Pilih gambar sampul yang menarik untuk video."),
            VocabItem(id: "s17", textZh: "话题标签", textId: "Tagar / hashtag", exampleZh: "发帖时加几个话题标签。", exampleId: "Saat posting tambahkan beberapa hashtag."),
            VocabItem(id: "s18", textZh: "热门话题", textId: "Topik trending", exampleZh: "今天的热门话题是什么？", exampleId: "Topik trending hari ini apa?"),
            VocabItem(id: "s19", textZh: "推送通知", textId: "Notifikasi push", exampleZh: "别忘了打开推送通知。", exampleId: "Jangan lupa aktifkan notifikasi."),
            VocabItem(id: "s20", textZh: "屏蔽", textId: "Blokir / mute", exampleZh: "不想看就把它屏蔽掉。", exampleId: "Kalau tidak mau lihat bisa diblokir."),
            VocabItem(id: "s21", textZh: "拉黑", textId: "Block", exampleZh: "恶意骚扰可以直接拉黑。", exampleId: "Kalau ada yang mengganggu bisa langsung diblokir."),
            VocabItem(id: "s22", textZh: "举报", textId: "Laporkan", exampleZh: "违规内容可以举报。", exampleId: "Konten yang melanggar bisa dilaporkan."),
            VocabItem(id: "s23", textZh: "刷视频", textId: "Scroll video pendek", exampleZh: "一刷视频就停不下来。", exampleId: "Kalau scroll video pendek suka susah berhenti."),
            VocabItem(id: "s24", textZh: "沉浸式刷屏", textId: "Scroll tanpa henti", exampleZh: "别长时间沉浸式刷屏。", exampleId: "Jangan terlalu lama scroll tanpa henti."),
            VocabItem(id: "s25", textZh: "限时动态", textId: "Story 24 jam", exampleZh: "发一个限时动态记录一下。", exampleId: "Posting story 24 jam untuk catat momen."),
            VocabItem(id: "s26", textZh: "置顶作品", textId: "Konten yang dipin", exampleZh: "精选内容可以置顶在主页。", exampleId: "Konten terbaik bisa dipin di profil."),
            VocabItem(id: "s27", textZh: "合拍", textId: "Duet video", exampleZh: "这个视频可以拿来合拍。", exampleId: "Video ini cocok untuk duet."),
            VocabItem(id: "s28", textZh: "滤镜", textId: "Filter", exampleZh: "选一个自然一点的滤镜。", exampleId: "Pilih filter yang terlihat natural."),
            VocabItem(id: "s29", textZh: "贴纸", textId: "Stiker", exampleZh: "给照片加几个可爱的贴纸。", exampleId: "Tambahkan beberapa stiker lucu ke foto."),
            VocabItem(id: "s30", textZh: "配乐", textId: "Musik latar", exampleZh: "视频选一段合适的配乐。", exampleId: "Pilih musik latar yang pas untuk video."),
            VocabItem(id: "s31", textZh: "剪辑", textId: "Editing", exampleZh: "发之前先简单剪辑一下。", exampleId: "Sebelum upload edit sebentar dulu."),
            VocabItem(id: "s32", textZh: "封面文案", textId: "Teks sampul", exampleZh: "封面文案要简短有吸引力。", exampleId: "Teks di sampul harus singkat dan menarik."),
            VocabItem(id: "s33", textZh: "标题党", textId: "Judul clickbait", exampleZh: "不要做太夸张的标题党。", exampleId: "Jangan pakai judul clickbait yang berlebihan."),
            VocabItem(id: "s34", textZh: "数据分析", textId: "Analisis data akun", exampleZh: "可以看看后台数据分析。", exampleId: "Bisa lihat analisis data di dashboard."),
            VocabItem(id: "s35", textZh: "曝光量", textId: "Impresi", exampleZh: "这条内容曝光量很高。", exampleId: "Konten ini impresinya tinggi."),
            VocabItem(id: "s36", textZh: "点击率", textId: "CTR", exampleZh: "封面影响点击率。", exampleId: "Sampul memengaruhi CTR."),
            VocabItem(id: "s37", textZh: "完播率", textId: "Completion rate", exampleZh: "前几秒决定完播率。", exampleId: "Beberapa detik pertama menentukan completion rate."),
            VocabItem(id: "s38", textZh: "粉丝互动", textId: "Interaksi dengan pengikut", exampleZh: "多回复评论增加粉丝互动。", exampleId: "Rajin balas komentar untuk meningkatkan interaksi."),
            VocabItem(id: "s39", textZh: "私域流量", textId: "Traffic privat", exampleZh: "建立自己的私域流量池。", exampleId: "Bangun traffic privat sendiri."),
            VocabItem(id: "s40", textZh: "带货", textId: "Live shopping", exampleZh: "他经常在直播间带货。", exampleId: "Dia sering live shopping di siaran langsung."),
            VocabItem(id: "s41", textZh: "链接放在简介", textId: "Link di bio", exampleZh: "详细信息看个人简介里的链接。", exampleId: "Info lengkap ada di link di bio."),
            VocabItem(id: "s42", textZh: "小作文", textId: "Caption panjang", exampleZh: "这条配文写了一篇小作文。", exampleId: "Caption postingan ini panjang sekali."),
            VocabItem(id: "s43", textZh: "表情包", textId: "Stiker ekspresi", exampleZh: "我们做了一个专属表情包。", exampleId: "Kami membuat stiker ekspresi khusus."),
            VocabItem(id: "s44", textZh: "线上活动", textId: "Event online", exampleZh: "周末有个线上抽奖活动。", exampleId: "Akhir pekan ada event undian online."),
            VocabItem(id: "s45", textZh: "粉丝群", textId: "Grup penggemar", exampleZh: "可以加入官方粉丝群。", exampleId: "Bisa gabung grup penggemar resmi."),
            VocabItem(id: "s46", textZh: "精选评论", textId: "Komentar pilihan", exampleZh: "有几条精选评论被置顶。", exampleId: "Beberapa komentar pilihan dipin di atas."),
            VocabItem(id: "s47", textZh: "踢出群聊", textId: "Keluarkan dari grup", exampleZh: "违反规则的人会被踢出群聊。", exampleId: "Yang melanggar aturan akan dikeluarkan dari grup."),
            VocabItem(id: "s48", textZh: "社交成瘾", textId: "Kecanduan media sosial", exampleZh: "要避免社交成瘾。", exampleId: "Harus menghindari kecanduan media sosial."),
            VocabItem(id: "s49", textZh: "屏幕使用时间", textId: "Waktu layar", exampleZh: "可以看看每天的屏幕使用时间。", exampleId: "Bisa cek berapa lama waktu layar per hari."),
            VocabItem(id: "s50", textZh: "隐私设置", textId: "Pengaturan privasi", exampleZh: "记得检查账号隐私设置。", exampleId: "Jangan lupa cek pengaturan privasi akun."),
            VocabItem(id: "s51", textZh: "陌生人消息", textId: "Pesan dari orang tak dikenal", exampleZh: "陌生人消息要谨慎打开。", exampleId: "Hati-hati membuka pesan dari orang tak dikenal."),
            VocabItem(id: "s52", textZh: "账号安全", textId: "Keamanan akun", exampleZh: "开启两步验证保护账号安全。", exampleId: "Aktifkan verifikasi dua langkah untuk keamanan akun.")
        ]
        return VocabCategory(
            id: "social",
            nameZh: "社交媒体",
            nameId: "Media sosial",
            items: items
        )
    }
}
