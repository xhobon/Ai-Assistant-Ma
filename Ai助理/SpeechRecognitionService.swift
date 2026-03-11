import Foundation
import Speech
import NaturalLanguage
import Combine

final class SpeechRecognitionService: NSObject, ObservableObject {
    private let transcriber = SpeechTranscriber()
    private var currentLocale: Locale = Locale(identifier: "zh-CN")
    private var lastSwitchAt: Date = .distantPast
    private var onResult: ((String, Bool) -> Void)?

    func requestAuthorization() async -> Bool {
        await transcriber.requestAuthorization()
    }

    func start(onResult: @escaping (String, Bool) -> Void) throws {
        self.onResult = onResult
        try startTranscribing()
    }

    func stop() {
        transcriber.stopTranscribing()
    }

    private func maybeSwitchLocale(with text: String) {
        let detected = detectLanguage(text)
        guard let target = detected, target.identifier != currentLocale.identifier else { return }
        let now = Date()
        if now.timeIntervalSince(lastSwitchAt) < 1.0 { return }
        lastSwitchAt = now
        currentLocale = target
        try? startTranscribing()
    }

    private func startTranscribing() throws {
        let handler = onResult
        try transcriber.startTranscribing(locale: currentLocale) { [weak self] text, isFinal in
            guard let self else { return }
            handler?(text, isFinal)
            self.maybeSwitchLocale(with: text)
        }
    }

    private func detectLanguage(_ text: String) -> Locale? {
        if text.range(of: "\\p{Han}", options: .regularExpression) != nil {
            return Locale(identifier: "zh-CN")
        }
        let lower = text.lowercased()
        let tokens = lower.split { !$0.isLetter }
        let keywords: Set<String> = [
            "yang","dan","tidak","apa","saya","kamu","anda","ini","itu","dengan","untuk",
            "karena","bagaimana","terima","kasih","tolong","bisa","akan","sudah","belum","juga",
            "mohon","sebagai","pada","dari","ke","di","adalah"
        ]
        if tokens.contains(where: { keywords.contains(String($0)) }) {
            return Locale(identifier: "id-ID")
        }
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Locale(identifier: "en-US")
        }
        return nil
    }
}
