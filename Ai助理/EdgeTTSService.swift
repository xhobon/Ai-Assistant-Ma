import Foundation
import AVFoundation
import CryptoKit

enum EdgeTTSError: Error {
    case emptyText
    case invalidResponse
    case audioWriteFailed
    case playbackFailed
}

final class EdgeTTSService: NSObject {
    static let shared = EdgeTTSService()

    private let endpoint = URL(string: "https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1")!
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

    func play(text: String, onFinish: (() -> Void)? = nil) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EdgeTTSError.emptyText }
        self.onFinish = onFinish

        let voice = selectVoice(for: trimmed)
        let speed = SpeechSettingsStore.shared.speechSpeed
        let cacheURL = cachedFileURL(text: trimmed, voice: voice, speed: speed)

        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try await playAudio(at: cacheURL)
            return
        }

        let audioData = try await fetchSpeechData(text: trimmed, voice: voice, speed: speed)
        do {
            try audioData.write(to: cacheURL, options: [.atomic])
        } catch {
            throw EdgeTTSError.audioWriteFailed
        }
        try await playAudio(at: cacheURL)
    }

    private func playAudio(at url: URL) async throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true, options: [])
        let data = try Data(contentsOf: url)
        player = try AVAudioPlayer(data: data)
        player?.delegate = self
        player?.prepareToPlay()
        guard player?.play() == true else {
            throw EdgeTTSError.playbackFailed
        }
    }

    private func fetchSpeechData(text: String, voice: String, speed: String) async throws -> Data {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        req.setValue("audio-24khz-48kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.httpBody = buildSSML(text: text, voice: voice, speed: speed).data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
            throw EdgeTTSError.invalidResponse
        }
        return data
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
        if containsChinese(text) { return "zh" }
        if containsIndonesian(text) { return "id" }
        return "en"
    }

    private func containsChinese(_ text: String) -> Bool {
        return text.range(of: "\\p{Han}", options: .regularExpression) != nil
    }

    private func containsIndonesian(_ text: String) -> Bool {
        let lower = text.lowercased()
        let tokens = lower.split { !$0.isLetter }
        let keywords: Set<String> = [
            "yang","dan","tidak","apa","saya","kamu","anda","ini","itu","dengan","untuk",
            "karena","bagaimana","terima","kasih","tolong","bisa","akan","sudah","belum","juga",
            "mohon","sebagai","pada","dari","ke","di","adalah"
        ]
        return tokens.contains { keywords.contains(String($0)) }
    }
}

extension EdgeTTSService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
        onFinish = nil
    }
}
