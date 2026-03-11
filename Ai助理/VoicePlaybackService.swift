import Foundation
import Combine
import AVFoundation

final class VoicePlaybackService: NSObject, ObservableObject {
    static let shared = VoicePlaybackService()

    @Published var isPlaying = false

    private let edge = EdgeTTSService.shared
    private let systemSynth = AVSpeechSynthesizer()
    private var currentTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?

    private override init() {
        super.init()
        systemSynth.delegate = self
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        streamTask?.cancel()
        streamTask = nil
        edge.stop()
        systemSynth.stopSpeaking(at: .immediate)
        isPlaying = false
    }

    func speak(
        text: String,
        languageHint: String? = nil,
        onFinish: (() -> Void)? = nil,
        forceOnline: Bool = false,
        allowFallback: Bool = true
    ) {
        guard !text.isEmpty else { return }
        if SpeechSettingsStore.shared.playbackMuted { return }
        stop()
        isPlaying = true
        speakSystem(text: text, languageHint: languageHint, onFinish: onFinish)
    }

    func speakStreaming(
        _ stream: AsyncStream<String>,
        languageHint: String? = nil,
        onFinish: (() -> Void)? = nil,
        forceOnline: Bool = false,
        allowFallback: Bool = true
    ) {
        if SpeechSettingsStore.shared.playbackMuted { return }
        stop()
        isPlaying = true
        streamTask = Task { [weak self] in
            guard let self else { return }
            var full = ""
            for await delta in stream {
                full += delta
            }
            await MainActor.run {
                self.speakSystem(text: full, languageHint: languageHint, onFinish: onFinish)
            }
        }
    }

    func testOnlineVoice(text: String, languageHint: String? = nil) async throws {
        guard !text.isEmpty else { return }
        stop()
        isPlaying = true
        defer { isPlaying = false }
        speakSystem(text: text, languageHint: languageHint, onFinish: nil)
    }

    private func playChunks(_ chunks: [String], languageHint: String?) async throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true, options: [])

        var index = 0
        var nextTask: Task<URL, Error>?

        func makeTask(for chunk: String) -> Task<URL, Error> {
            let voice = selectVoice(for: chunk, languageHint: languageHint)
            let speed = SpeechSettingsStore.shared.speechSpeed
            return Task { try await edge.synthesize(text: chunk, voice: voice, speed: speed) }
        }

        if !chunks.isEmpty {
            nextTask = makeTask(for: chunks[0])
        }

        while index < chunks.count {
            guard let task = nextTask else { break }
            let url = try await task.value
            index += 1
            if index < chunks.count {
                nextTask = makeTask(for: chunks[index])
            } else {
                nextTask = nil
            }
            try await edge.play(url: url)
        }
    }

    private func playStream(_ stream: AsyncStream<String>, languageHint: String?) async throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true, options: [])

        var buffer = ""
        for await delta in stream {
            buffer += delta
            let chunks = drainStreamChunks(&buffer)
            for chunk in chunks {
                let voice = selectVoice(for: chunk, languageHint: languageHint)
                let speed = SpeechSettingsStore.shared.speechSpeed
                let url = try await edge.synthesize(text: chunk, voice: voice, speed: speed)
                try await edge.play(url: url)
            }
        }

        let final = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final.isEmpty {
            let voice = selectVoice(for: final, languageHint: languageHint)
            let speed = SpeechSettingsStore.shared.speechSpeed
            let url = try await edge.synthesize(text: final, voice: voice, speed: speed)
            try await edge.play(url: url)
        }
    }

    private func speakSystem(text: String, languageHint: String?, onFinish: (() -> Void)?) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("System TTS audio session setup failed: \(error.localizedDescription)")
        }
        let lang = detectLanguage(text) ?? languageHint ?? "zh-CN"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        utterance.rate = SpeechSettingsStore.shared.speechRate
        utterance.pitchMultiplier = 1.0
        systemSynth.speak(utterance)
        if let onFinish {
            currentTask = Task { [weak self] in
                guard let self else { return }
                while self.systemSynth.isSpeaking {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
                await MainActor.run { onFinish() }
            }
        }
    }

    private func postTTSNotice(_ message: String) {
        NotificationCenter.default.post(
            name: .ttsPlaybackNotice,
            object: nil,
            userInfo: ["message": message]
        )
    }

    private func chunkText(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "。！？!?;；，,\n")
        let parts = text.split(whereSeparator: { separators.contains($0.unicodeScalars.first!) })
        let trimmed = parts.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if trimmed.isEmpty {
            return chunkByLength(text, maxLength: 140)
        }
        let combined = trimmed.flatMap { chunkByLength($0, maxLength: 140) }
        return combined.isEmpty ? [text] : combined
    }

    private func drainStreamChunks(_ buffer: inout String) -> [String] {
        var chunks: [String] = []
        let separators = CharacterSet(charactersIn: "。！？!?;；\n")
        while let range = buffer.rangeOfCharacter(from: separators) {
            let end = buffer.index(after: range.lowerBound)
            let segment = String(buffer[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = String(buffer[end...])
            if !segment.isEmpty {
                chunks.append(segment)
            }
        }
        if buffer.count > 160 {
            let idx = buffer.index(buffer.startIndex, offsetBy: 160)
            let segment = String(buffer[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = String(buffer[idx...])
            if !segment.isEmpty {
                chunks.append(segment)
            }
        }
        return chunks
    }

    private func selectVoice(for text: String, languageHint: String?) -> String {
        let lang = detectLanguage(text) ?? languageHint ?? "zh-CN"
        let gender = SpeechSettingsStore.shared.voiceGender
        if lang.hasPrefix("zh") {
            return gender == "male" ? "zh-CN-YunxiNeural" : "zh-CN-XiaoxiaoNeural"
        }
        if lang.hasPrefix("id") {
            return gender == "male" ? "id-ID-ArdiNeural" : "id-ID-GadisNeural"
        }
        return gender == "male" ? "en-US-GuyNeural" : "en-US-AriaNeural"
    }

    private func detectLanguage(_ text: String) -> String? {
        return LanguageDetector.detect(from: text)?.localeIdentifier ?? "zh-CN"
    }

    private func chunkByLength(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }
        var chunks: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.count + word.count + 1 > maxLength, !current.isEmpty {
                chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            }
            current += (current.isEmpty ? "" : " ") + word
        }
        if !current.isEmpty {
            chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return chunks.isEmpty ? [text] : chunks
    }
}

extension VoicePlaybackService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
    }
}
