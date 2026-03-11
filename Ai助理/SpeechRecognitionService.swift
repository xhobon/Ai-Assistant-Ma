import Foundation
import Speech
import NaturalLanguage
import Combine

final class SpeechRecognitionService: NSObject, ObservableObject {
    private let transcriber = SpeechTranscriber()
    private var currentLocale: Locale = LanguageDetector.defaultLocale()
    private var lastSwitchAt: Date = .distantPast
    private var onResult: ((String, Bool) -> Void)?
    private let supportedLocales: [Locale] = [
        Locale(identifier: "zh-CN"),
        Locale(identifier: "id-ID"),
        Locale(identifier: "en-US")
    ]

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
        let detected = LanguageDetector.detectLocale(from: text)
        guard let target = detected, target.identifier != currentLocale.identifier else { return }
        guard supportedLocales.contains(where: { $0.identifier == target.identifier }) else { return }
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
}
