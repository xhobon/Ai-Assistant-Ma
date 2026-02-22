import Foundation
import AVFoundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Speech
import Combine
import Vision
import Security
import SwiftUI

/// 服务器配置：固定使用内置生产地址，AI 对话与翻译全部走后端（API Key 在后端配置）
final class ServerConfigStore: ObservableObject {
    static let shared = ServerConfigStore()

    /// 内置生产地址（Vercel 部署的后端，Groq 智能体）
    private static let builtInProductionURL = "https://ai-assistant-mac.vercel.app"

    var baseURL: URL {
        guard let u = URL(string: Self.builtInProductionURL) else {
            return URL(string: "https://ai-assistant-mac.vercel.app")!
        }
        return u
    }

    var baseURLString: String { Self.builtInProductionURL }
}

struct AppConfig {
    static var baseURL: URL { ServerConfigStore.shared.baseURL }
}

struct HealthResponse: Codable {
    let status: String
    let time: String
}

struct AuthResponse: Codable {
    let token: String
    let user: UserDTO
}

struct UserDTO: Codable {
    let id: String
    let email: String?
    let phone: String?
    let displayName: String
}

enum APIClientError: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务响应异常"
        case .serverError(let message):
            return message
        }
    }
}

/// 将网络/连接错误转为用户可读的中文提示
func userFacingMessage(for error: Error) -> String {
    let desc = error.localizedDescription
    #if DEBUG
    if let urlError = error as? URLError {
        print("[APIClient] URLError: code=\(urlError.code.rawValue), host=\(urlError.failingURL?.host ?? "nil")")
    }
    #endif
    let lower = desc.lowercased()
    if lower.contains("connect") || lower.contains("connection") || lower.contains("网络") || lower.contains("无法连接") {
        return "无法连接服务器，请检查网络或稍后重试。若持续失败，请确认后端服务已部署并正常运行。"
    }
    if let urlError = error as? URLError {
        switch urlError.code {
        case .cannotConnectToHost, .notConnectedToInternet, .timedOut:
            return "无法连接服务器，请检查网络与服务器地址。"
        case .cannotFindHost:
            return "无法解析服务器地址，请检查网络。若使用代理或 VPN 可先关闭后重试。"
        default:
            break
        }
    }
    return desc.isEmpty ? "请求失败，请稍后重试" : desc
}

final class TokenStore {
    static let shared = TokenStore()
    private let key = "ai_assistant_token"

    var token: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.setValue(newValue, forKey: key) }
    }

    var isLoggedIn: Bool { token != nil && !(token ?? "").isEmpty }
}

/// 清除本地数据时发送，各页可监听并清空内存数据
extension Notification.Name {
    static let clearLocalData = Notification.Name("ai_assistant_clear_local_data")
}

/// 清除所有本地记录（收藏、翻译历史等）；卸载应用后数据也会清空。登录用户的数据将来可同步至服务器。
final class ClearDataStore: ObservableObject {
    static let shared = ClearDataStore()

    /// 清除本地存储的收藏等；并发送通知让翻译/学习等页面清空内存数据
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: "favorite_vocab_ids")
        NotificationCenter.default.post(name: .clearLocalData, object: nil)
    }
}

/// 外观：跟随系统 / 浅色 / 深色
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()
    private let key = "appearance_mode"

    enum Mode: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"
    }

    var mode: Mode {
        get { Mode(rawValue: UserDefaults.standard.string(forKey: key) ?? "system") ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            objectWillChange.send()
        }
    }

    var colorScheme: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 朗读设置（语速、语音质量、播放静音）
final class SpeechSettingsStore: ObservableObject {
    static let shared = SpeechSettingsStore()
    private let rateKey = "speech_rate"
    private let voiceQualityKey = "speech_voice_quality"
    private let playbackMutedKey = "playback_muted"

    /// 是否静音（不播放 AI 回复等 TTS）
    var playbackMuted: Bool {
        get { UserDefaults.standard.bool(forKey: playbackMutedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: playbackMutedKey)
            objectWillChange.send()
        }
    }

    /// 语速 0.3（慢）～ 0.6（快），默认 0.48
    var speechRate: Float {
        get {
            guard UserDefaults.standard.object(forKey: rateKey) != nil else { return 0.48 }
            return UserDefaults.standard.float(forKey: rateKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: rateKey)
            objectWillChange.send()
        }
    }

    /// 语音质量：default / enhanced / premium
    var voiceQuality: String {
        get { UserDefaults.standard.string(forKey: voiceQualityKey) ?? "premium" }
        set {
            UserDefaults.standard.set(newValue, forKey: voiceQualityKey)
            objectWillChange.send()
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        body: [String: Any]? = nil,
        authorized: Bool = false
    ) async throws -> T {
        let base = ServerConfigStore.shared.baseURLString
        let pathTrimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: base.hasSuffix("/") ? base + pathTrimmed : base + "/" + pathTrimmed) else {
            throw APIClientError.serverError("无效的请求地址")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token = TokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        #if DEBUG
        print("[APIClient] 请求: \(url.absoluteString)")
        #endif
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error { continuation.resume(throwing: error); return }
                guard let data, let response else {
                    continuation.resume(throwing: APIClientError.invalidResponse)
                    return
                }
                DispatchQueue.main.async { continuation.resume(returning: (data, response)) }
            }
            .resume()
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw APIClientError.serverError(message)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    func health() async throws -> HealthResponse {
        try await request("health", method: "GET")
    }

    func register(email: String, phone: String, password: String, displayName: String) async throws -> AuthResponse {
        var body: [String: Any] = [
            "password": password,
            "displayName": displayName.isEmpty ? "新用户" : displayName
        ]
        if !email.isEmpty {
            body["email"] = email
        }
        if !phone.isEmpty {
            body["phone"] = phone
        }
        return try await request("api/auth/register", method: "POST", body: body)
    }

    func login(account: String, password: String) async throws -> AuthResponse {
        try await request(
            "api/auth/login",
            method: "POST",
            body: [
                "account": account,
                "password": password
            ]
        )
    }

    func socialLogin(provider: String, providerUserId: String, email: String, displayName: String) async throws -> AuthResponse {
        var body: [String: Any] = [
            "provider": provider,
            "providerUserId": providerUserId,
            "displayName": displayName
        ]
        if !email.isEmpty {
            body["email"] = email
        }
        return try await request("api/auth/social", method: "POST", body: body)
    }

    /// 服务器 AI 对话（支持图片）；userContext 为未登录时的本地记忆；localExecution 开启时助理可返回 [CMD]命令[/CMD] 由客户端执行
    func assistantChat(conversationId: String? = nil, message: String? = nil, imageData: Data? = nil, userContext: String? = nil, localExecution: Bool = false) async throws -> (conversationId: String?, reply: String) {
        struct Res: Codable { let conversationId: String?; let reply: String }
        var body: [String: Any] = [:]
        if let msg = message, !msg.isEmpty {
            body["message"] = msg
        }
        if let imgData = imageData {
            let base64Image = imgData.base64EncodedString()
            body["image"] = base64Image
            if message == nil || message?.isEmpty == true {
                body["message"] = "请识别这张图片"
            }
        }
        if let cid = conversationId { body["conversationId"] = cid }
        if let ctx = userContext, !ctx.isEmpty { body["userContext"] = ctx }
        if localExecution { body["localExecution"] = true }
        let res: Res = try await request("api/assistant/chat", method: "POST", body: body, authorized: true)
        return (res.conversationId, res.reply)
    }
    
    /// 服务器 AI 对话（支持文件上传）；userContext 为未登录时的本地记忆摘要
    func assistantChatWithFile(conversationId: String? = nil, message: String, fileData: Data, fileName: String, fileType: String, userContext: String? = nil) async throws -> (conversationId: String?, reply: String) {
        struct Res: Codable { let conversationId: String?; let reply: String }
        let base = ServerConfigStore.shared.baseURLString
        let pathTrimmed = "api/assistant/chat"
        guard let url = URL(string: base.hasSuffix("/") ? base + pathTrimmed : base + "/" + pathTrimmed) else {
            throw APIClientError.serverError("无效的请求地址")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 使用 multipart/form-data 上传文件
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // 添加消息
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"message\"\r\n\r\n".data(using: .utf8)!)
        body.append(message.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加文件名和类型
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"fileName\"\r\n\r\n".data(using: .utf8)!)
        body.append(fileName.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"fileType\"\r\n\r\n".data(using: .utf8)!)
        body.append(fileType.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加会话ID（如果有）
        if let cid = conversationId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"conversationId\"\r\n\r\n".data(using: .utf8)!)
            body.append(cid.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        // 未登录时传入本地记忆作为 userContext
        if let ctx = userContext, !ctx.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"userContext\"\r\n\r\n".data(using: .utf8)!)
            body.append(ctx.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        #if DEBUG
        print("[APIClient] 上传文件: \(fileName), 大小: \(fileData.count) bytes")
        #endif
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error { continuation.resume(throwing: error); return }
                guard let data, let response else {
                    continuation.resume(throwing: APIClientError.invalidResponse)
                    return
                }
                DispatchQueue.main.async { continuation.resume(returning: (data, response)) }
            }
            .resume()
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw APIClientError.serverError("HTTP \(httpResponse.statusCode): \(message)")
        }
        
        let res: Res = try JSONDecoder().decode(Res.self, from: data)
        return (res.conversationId, res.reply)
    }

    // MARK: - 助理长期记忆（仅登录用户，与云端同步）

    /// 获取云端记忆列表
    func getMemories() async throws -> [UserMemoryItem] {
        struct Mem: Codable {
            let id: String
            let content: String
            let category: String
            let createdAt: String
        }
        struct Res: Codable { let memories: [Mem] }
        let res: Res = try await request("api/user/memory", method: "GET", authorized: true)
        let formatter = ISO8601DateFormatter()
        return res.memories.map { m in
            UserMemoryItem(
                id: m.id,
                content: m.content,
                category: m.category,
                createdAt: formatter.date(from: m.createdAt) ?? Date()
            )
        }
    }

    /// 上传记忆到云端（合并，去重）
    func addMemories(_ items: [(content: String, category: String)]) async throws {
        struct Res: Codable { let success: Bool }
        let payload = items.map { ["content": String($0.content.prefix(500)), "category": $0.category] as [String: Any] }
        let _: Res = try await request("api/user/memory", method: "POST", body: ["memories": payload], authorized: true)
    }

    /// 删除一条云端记忆
    func deleteMemory(id: String) async throws {
        struct Res: Codable { let success: Bool }
        let _: Res = try await request("api/user/memory/\(id)", method: "DELETE", authorized: true)
    }

    /// 服务器翻译
    func translate(text: String, sourceLang: String, targetLang: String) async throws -> String {
        struct Res: Codable { let translated: String }
        let res: Res = try await request(
            "api/translate",
            method: "POST",
            body: ["text": text, "sourceLang": sourceLang, "targetLang": targetLang],
            authorized: true
        )
        return res.translated
    }
    
    /// 保存翻译到云端
    func saveTranslation(sourceLang: String, targetLang: String, sourceText: String, targetText: String) async throws {
        struct Res: Codable { let success: Bool }
        let _: Res = try await request(
            "api/translations",
            method: "POST",
            body: [
                "sourceLang": sourceLang,
                "targetLang": targetLang,
                "sourceText": sourceText,
                "targetText": targetText
            ],
            authorized: true
        )
    }
    
    /// 获取翻译历史
    func getTranslationHistory() async throws -> [TranslationEntry] {
        struct CloudTranslation: Codable {
            let id: String
            let sourceLang: String
            let targetLang: String
            let sourceText: String
            let targetText: String
            let createdAt: String
        }
        struct Res: Codable {
            let translations: [CloudTranslation]
        }
        let res: Res = try await request("api/translations", method: "GET", authorized: true)
        return res.translations.map { cloud in
            let sourceLang = LanguageOption.all.first { $0.code == cloud.sourceLang } ?? .chinese
            let targetLang = LanguageOption.all.first { $0.code == cloud.targetLang } ?? .indonesian
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: cloud.createdAt) ?? Date()
            return TranslationEntry(
                id: cloud.id,
                sourceText: cloud.sourceText,
                targetText: cloud.targetText,
                sourceLang: sourceLang,
                targetLang: targetLang,
                createdAt: date
            )
        }
    }
}

final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()
    @Published var isPlaying = false
    private let synthesizer = AVSpeechSynthesizer()
    private var onlinePlayer: AVPlayer?
    private var onlinePlayerItem: AVPlayerItem?
    private var onlinePlayerObserver: NSObjectProtocol?
    private var currentTempURL: URL?
    private var lastOnlineText: String?
    private var lastOnlineLang: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 优先使用增强/优质发音，语速与音调更自然；静音时不播放。若为「在线」则用免费 Edge TTS。
    func speak(_ text: String, language: String) {
        guard !text.isEmpty else { return }
        if SpeechSettingsStore.shared.playbackMuted { return }
        // 停止当前播放
        stopSpeaking()
        isPlaying = true
        if SpeechSettingsStore.shared.voiceQuality == "online" {
            playOnlineTTS(text: text, language: language)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice(for: language)
        utterance.rate = SpeechSettingsStore.shared.speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.08
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    /// 在线 TTS（Edge 免费语音，更自然）
    private func playOnlineTTS(text: String, language: String) {
        let base = ServerConfigStore.shared.baseURLString
        let urlString = base.hasSuffix("/") ? base + "api/tts" : base + "/api/tts"
        guard let url = URL(string: urlString) else { speakLocal(text: text, language: language); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["text": text, "lang": language]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            let statusOK = (response as? HTTPURLResponse)?.statusCode == 200
            let hasData = data != nil && !data!.isEmpty
            if error != nil || !statusOK || !hasData {
                DispatchQueue.main.async { self.speakLocal(text: text, language: language) }
                return
            }
            let textCopy = text
            let dataCopy = data!
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                lastOnlineText = textCopy
                lastOnlineLang = language
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".webm")
                do {
                    try dataCopy.write(to: fileURL)
                    currentTempURL = fileURL
                    playWithAVPlayer(url: fileURL) { [weak self] in
                        self?.removeTempTTSFile()
                    }
                } catch {
                    lastOnlineText = nil
                    lastOnlineLang = nil
                    speakLocal(text: textCopy, language: language)
                }
            }
        }.resume()
    }

    private func speakLocal(text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice(for: language)
        utterance.rate = SpeechSettingsStore.shared.speechRate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    private func playWithAVPlayer(url: URL, onFinish: @escaping () -> Void) {
        let item = AVPlayerItem(url: url)
        onlinePlayerItem = item
        let player = AVPlayer(playerItem: item)
        onlinePlayer = player

        onlinePlayerObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.cleanupOnlinePlayer()
            onFinish()
        }
        item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        player.play()
    }

    private func cleanupOnlinePlayer() {
        if let item = onlinePlayerItem {
            item.removeObserver(self, forKeyPath: "status", context: nil)
        }
        onlinePlayerItem = nil
        onlinePlayer?.pause()
        onlinePlayer = nil
        if let ob = onlinePlayerObserver {
            NotificationCenter.default.removeObserver(ob)
            onlinePlayerObserver = nil
        }
        removeTempTTSFile()
        lastOnlineText = nil
        lastOnlineLang = nil
        isPlaying = false
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem, item === onlinePlayerItem, item.status == .failed {
            let text = lastOnlineText
            let lang = lastOnlineLang ?? "zh-CN"
            DispatchQueue.main.async { [weak self] in
                self?.cleanupOnlinePlayer()
                if let t = text, !t.isEmpty { self?.speakLocal(text: t, language: lang) }
            }
        }
    }

    private func removeTempTTSFile() {
        if let url = currentTempURL {
            try? FileManager.default.removeItem(at: url)
            currentTempURL = nil
        }
    }

    /// 立即停止朗读（用户打断或开始说话时调用）
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        // 确保停止在线播放
        onlinePlayer?.pause()
        onlinePlayer?.replaceCurrentItem(with: nil)
        cleanupOnlinePlayer()
        isPlaying = false
    }

    /// 优先选择 Premium（最接近真人），其次 Enhanced，无则退回系统默认
    private func preferredVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let quality = SpeechSettingsStore.shared.voiceQuality
        guard quality != "default", #available(iOS 16.0, *) else {
            return AVSpeechSynthesisVoice(language: language)
        }
        let langPrefix = String(language.prefix(2))
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(langPrefix) }
        // Premium 最自然，优先使用
        if let premium = voices.first(where: { $0.quality == .premium }) { return premium }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) { return enhanced }
        return AVSpeechSynthesisVoice(language: language)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
    }
}

// MARK: - 本机执行（内置，无需用户安装 OpenClaw）

/// 内置「本机命令执行」：与后端 localExecution 模式配合，解析 [CMD]...[/CMD] 并在用户确认后执行
final class OpenClawService: ObservableObject {
    static let shared = OpenClawService()
    private init() {}

    /// 是否启用「使用本机执行」；存 UserDefaults。未配置时默认 true，首页对话框可直接发指令操作电脑，无需先去设置里打开
    var useOpenClawForAssistant: Bool {
        get {
            if !UserDefaults.standard.bool(forKey: "openclaw_use_for_assistant_configured") {
                return true  // 默认开启，首页对话即可用
            }
            return UserDefaults.standard.bool(forKey: "openclaw_use_for_assistant")
        }
        set {
            UserDefaults.standard.set(true, forKey: "openclaw_use_for_assistant_configured")
            UserDefaults.standard.set(newValue, forKey: "openclaw_use_for_assistant")
            objectWillChange.send()
        }
    }

    /// 从助理回复中解析 [CMD]...[/CMD]，返回展示文案与待执行命令（无则 command 为 nil）
    static func parseCommand(from reply: String) -> (displayText: String, command: String?) {
        let pattern = "\\[CMD\\]([\\s\\S]*?)\\[/CMD\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: reply, range: NSRange(reply.startIndex..., in: reply)),
              let range = Range(match.range(at: 1), in: reply) else {
            return (reply.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let command = String(reply[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        let display = reply.replacingOccurrences(of: regex.pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (display.isEmpty ? "正在请求执行命令…" : display, command.isEmpty ? nil : command)
    }

    /// 是否允许执行该命令（白名单 + 危险命令拦截，保护用户资料与隐私）
    static func isCommandAllowed(_ command: String) -> Bool {
        let c = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.isEmpty { return false }
        let lower = c.lowercased()
        let dangerous = ["rm ", "rm -", "mv ", ">", ">>", "dd ", "format", "mkfs", "chmod", "chown", "sudo ", "passwd", "curl |", "wget |", "eval ", "base64", "openssl ", "nc ", "ncat ", "bash -i", "python -c", "ruby -e", "perl -e", "php ", "source ", "cat /etc", "cat ~/.ssh", "cat ~/.aws", "id_rsa", "credentials", ".pem", "history", "pbcopy", "pbpaste", "clipboard"]
        if dangerous.contains(where: { lower.contains($0) }) { return false }
        let first = lower.split(separator: " ").first.map(String.init) ?? lower
        if ["pwd", "date", "whoami"].contains(first) { return true }
        if first.hasPrefix("ls") || first.hasPrefix("df") || first.hasPrefix("uname") { return true }
        if first == "echo", !c.contains("`"), !c.contains("$(") { return true }
        // 允许 macOS 打开应用：open -a "AppName"，禁止 URL/管道/分号等
        if first == "open", lower.contains("-a"),
           !lower.contains("http"), !lower.contains("|"), !c.contains(";"), !c.contains("&&") { return true }
        return false
    }

    /// 在本机执行一条 Shell 命令（仅允许通过 isCommandAllowed 的命令），返回 stdout+stderr
    func runLocalCommand(_ command: String) async -> String {
        guard Self.isCommandAllowed(command) else {
            return "出于安全与隐私保护，该命令未被允许执行。仅支持：ls、pwd、date、whoami、df、uname、echo 等只读类命令。"
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]
                process.standardInput = nil
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                do {
                    try process.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let out = String(data: outData, encoding: .utf8) ?? ""
                    let err = String(data: errData, encoding: .utf8) ?? ""
                    let combined = out + (err.isEmpty ? "" : "\n" + err)
                    continuation.resume(returning: combined.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    continuation.resume(returning: "执行失败：\(error.localizedDescription)")
                }
            }
        }
    }

    /// 状态文案：已集成，无需安装
    func fetchStatus() async -> String {
        "已集成在应用内，打开「使用本机执行」即可使用，无需单独安装。"
    }
}

struct ClipboardService {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

final class KeychainStore {
    static let shared = KeychainStore()
    private init() {}

    func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class SpeechTranscriber: NSObject {
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    /// 是否已安装 tap，避免在未安装时 removeTap 或重复操作
    private var hasInstalledTap = false

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing(locale: Locale, onResult: @escaping (String, Bool) -> Void) throws {
        assert(Thread.isMainThread, "AVAudioEngine 必须在主线程访问，请从主线程调用 startTranscribing")
        try startTranscribingOnMainThread(locale: locale, onResult: onResult)
    }

    /// 必须在主线程调用；AVAudioEngine 及其 inputNode 仅能在主线程访问
    private func startTranscribingOnMainThread(locale: Locale, onResult: @escaping (String, Bool) -> Void) throws {
        stopTranscribing()

        audioEngine.stop()
        audioEngine.reset()
        audioEngine = AVAudioEngine()

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw NSError(domain: "Speech", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频会话初始化失败"])
        }
        #endif
        // macOS: AVAudioEngine 无需 AVAudioSession

        recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "Speech", code: -1, userInfo: [NSLocalizedDescriptionKey: "语音识别暂不可用"])
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        hasInstalledTap = true

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                onResult(result.bestTranscription.formattedString, result.isFinal)
            }
            if error != nil {
                onResult("", true)
            }
        }
    }

    func stopTranscribing() {
        assert(Thread.isMainThread, "AVAudioEngine 必须在主线程访问，请从主线程调用 stopTranscribing")
        stopTranscribingOnMainThread()
    }

    private func stopTranscribingOnMainThread() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}

final class VisionService {
    static let shared = VisionService()

    func recognizeText(from data: Data) async throws -> String {
        let cgImage: CGImage?
        #if os(iOS)
        guard let image = UIImage(data: data), let img = image.cgImage else { return "" }
        cgImage = img
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return "" }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let img = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return "" }
        cgImage = img
        #endif
        return try await recognizeText(fromCGImage: cgImage!)
    }

    private func recognizeText(fromCGImage cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let texts = (request.results as? [VNRecognizedTextObservation])?.compactMap {
                    $0.topCandidates(1).first?.string
                } ?? []
                continuation.resume(returning: texts.joined(separator: "\n"))
            }
            request.recognitionLanguages = ["zh-Hans", "id-ID", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
