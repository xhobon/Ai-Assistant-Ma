import Foundation
import AVFoundation
import CryptoKit

enum EdgeTTSError: Error {
    case emptyText
    case invalidResponse(statusCode: Int, bodyPreview: String?)
    case audioWriteFailed
    case playbackFailed
}

extension EdgeTTSError: CustomStringConvertible {
    var description: String {
        switch self {
        case .emptyText:
            return "empty text"
        case .invalidResponse(let status, let preview):
            if let preview, !preview.isEmpty {
                return "invalid response status=\(status), body=\(preview)"
            }
            return "invalid response status=\(status)"
        case .audioWriteFailed:
            return "audio write failed"
        case .playbackFailed:
            return "playback failed"
        }
    }
}

final class EdgeTTSService: NSObject {
    static let shared = EdgeTTSService()

    private let wsEndpoint = URL(string: "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4")!
    private let session = URLSession(configuration: .default)
    private var player: AVAudioPlayer?
    private var currentTask: Task<Void, Never>?
    private var onFinish: (() -> Void)?

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("edge_tts_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private override init() {
        super.init()
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        player?.stop()
        player = nil
    }

    func synthesize(text: String, voice: String, speed: String) async throws -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EdgeTTSError.emptyText }
        let cacheURL = cachedFileURL(text: trimmed, voice: voice, speed: speed)

        if FileManager.default.fileExists(atPath: cacheURL.path) {
            return cacheURL
        }

        let audioData = try await fetchSpeechData(text: trimmed, voice: voice, speed: speed)
        do {
            try audioData.write(to: cacheURL, options: [.atomic])
        } catch {
            throw EdgeTTSError.audioWriteFailed
        }
        return cacheURL
    }

    func play(url: URL, onFinish: (() -> Void)? = nil) async throws {
        let data = try Data(contentsOf: url)
        self.onFinish = onFinish
        player = try AVAudioPlayer(data: data)
        player?.delegate = self
        player?.prepareToPlay()
        guard player?.play() == true else { throw EdgeTTSError.playbackFailed }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            currentTask?.cancel()
            currentTask = Task { [weak self] in
                guard let self else { return }
                while self.player?.isPlaying == true {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
                continuation.resume()
            }
        }
    }

    private func fetchSpeechData(text: String, voice: String, speed: String) async throws -> Data {
        let ssml = buildSSML(text: text, voice: voice, speed: speed)
        return try await requestSpeechDataWebSocket(ssml: ssml)
    }

    private func requestSpeechDataWebSocket(ssml: String) async throws -> Data {
        var request = URLRequest(url: wsEndpoint)
        request.setValue("https://www.bing.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.bing.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let socket = session.webSocketTask(with: request)
        socket.resume()

        let requestId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let timestamp = edgeTimestamp()

        let configJSON = """
        {"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}
        """
        let configMsg = """
        X-Timestamp:\(timestamp)\r
        Content-Type:application/json; charset=utf-8\r
        Path:speech.config\r
        \r
        \(configJSON)
        """

        let ssmlMsg = """
        X-RequestId:\(requestId)\r
        Content-Type:application/ssml+xml\r
        X-Timestamp:\(timestamp)\r
        Path:ssml\r
        \r
        \(ssml)
        """

        try await socket.send(.string(configMsg))
        try await socket.send(.string(ssmlMsg))

        var audioBuffer = Data()
        var receivedTurnEnd = false

        while !receivedTurnEnd {
            let message = try await socket.receive()
            switch message {
            case .string(let text):
                if text.contains("Path:turn.end") {
                    receivedTurnEnd = true
                }
            case .data(let data):
                if let audio = extractAudioPayload(from: data) {
                    audioBuffer.append(audio)
                }
            @unknown default:
                break
            }
        }

        socket.cancel(with: .normalClosure, reason: nil)

        guard !audioBuffer.isEmpty else {
            throw EdgeTTSError.invalidResponse(statusCode: 404, bodyPreview: "empty audio")
        }
        return audioBuffer
    }

    private func buildSSML(text: String, voice: String, speed: String) -> String {
        let escaped = escapeSSML(text)
        let rate = ratePercent(for: speed)
        let prosody = "<prosody rate=\"\(rate)%\">\(escaped)</prosody>"
        return """
        <speak xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" version="1.0" xml:lang="en-US">
          <voice name="\(voice)">\(prosody)</voice>
        </speak>
        """
    }

    private func edgeTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z"
        let base = formatter.string(from: Date())
        return "\(base) (Coordinated Universal Time)"
    }

    private func extractAudioPayload(from data: Data) -> Data? {
        let delimiter = Data("\r\n\r\n".utf8)
        if let range = data.range(of: delimiter) {
            let payloadStart = range.upperBound
            if payloadStart < data.count {
                return data[payloadStart...]
            }
        }
        return nil
    }

    private func escapeSSML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func cachedFileURL(text: String, voice: String, speed: String) -> URL {
        let key = "\(voice)|\(speed)|\(text)"
        let hash = sha256(key)
        return cacheDir.appendingPathComponent(hash + ".mp3")
    }

    private func sha256(_ text: String) -> String {
        if let data = text.data(using: .utf8) {
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString
    }

    private func ratePercent(for speed: String) -> Int {
        switch speed {
        case "slow": return -10
        case "fast": return 10
        default: return 0
        }
    }

    private func selectVoice(for text: String) -> String {
        let lang = detectLanguage(for: text)
        let gender = SpeechSettingsStore.shared.voiceGender
        switch (lang, gender) {
        case ("zh", "male"):
            return "zh-CN-YunxiNeural"
        case ("zh", _):
            return "zh-CN-XiaoxiaoNeural"
        case ("id", "male"):
            return "id-ID-ArdiNeural"
        case ("id", _):
            return "id-ID-GadisNeural"
        case ("en", "male"):
            return "en-US-GuyNeural"
        default:
            return "en-US-AriaNeural"
        }
    }

    private func detectLanguage(for text: String) -> String {
        guard let lang = LanguageDetector.detect(from: text) else { return "zh" }
        return lang.rawValue
    }
}

extension EdgeTTSService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
        onFinish = nil
    }
}
