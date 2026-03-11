import Foundation
import AVFoundation

final class VoicePlaybackService: NSObject, ObservableObject {
    static let shared = VoicePlaybackService()

    @Published var isPlaying = false

    private let edge = EdgeTTSService.shared
    private let systemSynth = AVSpeechSynthesizer()
    private var currentTask: Task<Void, Never>?

    private override init() {
        super.init()
        systemSynth.delegate = self
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        edge.stop()
        systemSynth.stopSpeaking(at: .immediate)
        isPlaying = false
    }

    func speak(text: String, languageHint: String? = nil, onFinish: (() -> Void)? = nil) {
        guard !text.isEmpty else { return }
        if SpeechSettingsStore.shared.playbackMuted { return }
        stop()
        isPlaying = true

        let mode = SpeechSettingsStore.shared.voiceMode
        if mode == "system" {
            speakSystem(text: text, languageHint: languageHint, onFinish: onFinish)
            return
        }

        let chunks = chunkText(text)
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await playChunks(chunks, languageHint: languageHint)
                await MainActor.run {
                    self.isPlaying = false
                    onFinish?()
                }
            } catch {
                await MainActor.run {
                    self.isPlaying = false
                    self.speakSystem(text: text, languageHint: languageHint, onFinish: onFinish)
                }
            }
        }
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

    private func speakSystem(text: String, languageHint: String?, onFinish: (() -> Void)?) {
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

    private func chunkText(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "。！？!?;；\n")
        let parts = text.split(whereSeparator: { separators.contains($0.unicodeScalars.first!) })
        let trimmed = parts.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if trimmed.isEmpty { return [text] }
        return trimmed
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
        if text.range(of: "\\p{Han}", options: .regularExpression) != nil {
            return "zh-CN"
        }
        let lower = text.lowercased()
        let tokens = lower.split { !$0.isLetter }
        let keywords: Set<String> = [
            "yang","dan","tidak","apa","saya","kamu","anda","ini","itu","dengan","untuk",
            "karena","bagaimana","terima","kasih","tolong","bisa","akan","sudah","belum","juga",
            "mohon","sebagai","pada","dari","ke","di","adalah"
        ]
        if tokens.contains(where: { keywords.contains(String($0)) }) {
            return "id-ID"
        }
        return "en-US"
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
