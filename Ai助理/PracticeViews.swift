import SwiftUI

enum PracticeSource {
    case all
    case wrongBook
}

struct PracticeHomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var statsStore = LearningStatsStore.shared
    @StateObject private var wrongStore = WrongBookStore.shared
    @State private var selectedMode: LearningMode = {
        if let saved = UserDefaults.standard.string(forKey: "learning_mode"), let mode = LearningMode(rawValue: saved) {
            return mode
        }
        return .zhToId
    }()
    @State private var selectedCount: Int = 10
    @State private var selectedTypes: Set<PracticeQuestionType> = Set(PracticeQuestionType.allCases)
    @State private var showSession = false
    @State private var sessionSource: PracticeSource = .all

    private let questionCounts = [5, 10, 20]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    PracticeHeaderCard()
                        .padding(.horizontal, 14)

                    PracticeModeCard(
                        selectedMode: $selectedMode,
                        selectedCount: $selectedCount,
                        questionCounts: questionCounts,
                        selectedTypes: $selectedTypes
                    )
                    .padding(.horizontal, 14)

                    PracticeStatsCard(practiceSessions: statsStore.practiceSessions, accuracy: statsStore.accuracy, learningMinutes: statsStore.learningMinutes)
                        .padding(.horizontal, 14)

                    WrongBookEntryCard(count: wrongStore.items.count) {
                        sessionSource = .wrongBook
                        showSession = true
                    }
                    .padding(.horizontal, 14)

                    UnifiedAppButton(
                        title: languageStore.localized("practice_start"),
                        systemImage: "play.fill",
                        style: .primary
                    ) {
                        sessionSource = .all
                        showSession = true
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 980, alignment: .top)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea(edges: .top))
            .navigationTitle(languageStore.localized("practice_title"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedMode) { _, newMode in
                UserDefaults.standard.set(newMode.rawValue, forKey: "learning_mode")
            }
            .navigationDestination(isPresented: $showSession) {
                PracticeSessionView(
                    mode: selectedMode,
                    questionCount: selectedCount,
                    types: Array(selectedTypes),
                    source: sessionSource
                )
            }
        }
    }
}

struct PracticeHeaderCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accentWarm.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentWarm)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(languageStore.localized("practice_title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(languageStore.localized("practice_subtitle"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct PracticeModeCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Binding var selectedMode: LearningMode
    @Binding var selectedCount: Int
    let questionCounts: [Int]
    @Binding var selectedTypes: Set<PracticeQuestionType>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageStore.localized("practice_mode_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Picker("", selection: $selectedMode) {
                Text(languageStore.localized("learning_mode_zh_id")).tag(LearningMode.zhToId)
                Text(languageStore.localized("learning_mode_id_zh")).tag(LearningMode.idToZh)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                ForEach(questionCounts, id: \.self) { count in
                    Button {
                        selectedCount = count
                    } label: {
                        Text("\(count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedCount == count ? .white : AppTheme.textPrimary)
                            .frame(minWidth: 44)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selectedCount == count ? AppTheme.accentStrong : AppTheme.surfaceMuted)
                            )
                            .overlay(
                                Capsule().stroke(selectedCount == count ? AppTheme.accentStrong : AppTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(languageStore.localized("practice_type_title"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                    ForEach(PracticeQuestionType.allCases, id: \.self) { type in
                        PracticeTypeChip(
                            title: label(for: type),
                            isSelected: selectedTypes.contains(type)
                        ) {
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private func label(for type: PracticeQuestionType) -> String {
        switch type {
        case .multipleChoice: return languageStore.localized("practice_type_choice")
        case .matching: return languageStore.localized("practice_type_match")
        case .fillBlank: return languageStore.localized("practice_type_blank")
        case .translation: return languageStore.localized("practice_type_translate")
        case .listening: return languageStore.localized("practice_type_listening")
        case .sentenceOrder: return languageStore.localized("practice_type_order")
        }
    }
}

struct PracticeStatsCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let practiceSessions: Int
    let accuracy: Double
    let learningMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageStore.localized("practice_stats_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 8) {
                PracticeStatBlock(title: languageStore.localized("practice_stats_sessions"), value: "\(practiceSessions)", color: AppTheme.accentStrong)
                PracticeStatBlock(title: languageStore.localized("practice_stats_accuracy"), value: accuracyText, color: AppTheme.brandBlue)
                PracticeStatBlock(title: languageStore.localized("practice_stats_minutes"), value: "\(learningMinutes)", color: AppTheme.accentWarm)
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private var accuracyText: String {
        let percent = Int(accuracy * 100)
        return "\(percent)%"
    }
}

struct PracticeStatBlock: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct WrongBookEntryCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let count: Int
    var onReview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.brandBlue.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.brandBlue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(languageStore.localized("wrong_book_title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(languageStore.localizedFormat("wrong_book_subtitle", count))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            UnifiedAppButton(title: languageStore.localized("wrong_book_action"), systemImage: nil, style: .secondary) {
                onReview()
            }
            .frame(width: 90)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct PracticeTypeChip: View {
    let title: String
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? AppTheme.accentStrong : AppTheme.surfaceMuted)
                )
                .overlay(
                    Capsule().stroke(isSelected ? AppTheme.accentStrong : AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PracticeSessionView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var statsStore = LearningStatsStore.shared
    @StateObject private var wrongStore = WrongBookStore.shared
    @StateObject private var dailyStore = DailyTaskStore.shared

    let mode: LearningMode
    let questionCount: Int
    let types: [PracticeQuestionType]
    let source: PracticeSource

    @State private var questions: [PracticeQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var answered = false
    @State private var isCorrect = false
    @State private var selectedOption: String? = nil
    @State private var matchSelections: [String: String] = [:]
    @State private var fillBlankText = ""
    @State private var translationText = ""
    @State private var orderedWords: [String] = []
    @State private var availableWords: [String] = []
    @State private var results: [PracticeResultItem] = []
    @State private var startTime = Date()
    @State private var showSummary = false
    @State private var answerDetail = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if questions.isEmpty {
                    PracticeEmptyStateView()
                } else if showSummary {
                    PracticeResultView(results: results) {
                        dismiss()
                    }
                } else {
                    PracticeProgressCard(current: currentIndex + 1, total: questions.count)
                    questionCard
                    actionButtons
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(languageStore.localized("practice_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadQuestions()
        }
    }

    private var questionCard: some View {
        let question = questions[currentIndex]
        return VStack(alignment: .leading, spacing: 12) {
            Text(questionTitle(for: question))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            questionBody(for: question)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if answered {
                UnifiedAppButton(
                    title: languageStore.localized(currentIndex == questions.count - 1 ? "practice_finish" : "practice_next"),
                    systemImage: nil,
                    style: .primary
                ) {
                    goNext()
                }
            } else {
                UnifiedAppButton(
                    title: languageStore.localized("practice_submit"),
                    systemImage: nil,
                    style: .primary
                ) {
                    submitCurrent()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func questionTitle(for question: PracticeQuestion) -> String {
        switch question.payload {
        case .multipleChoice(let sourceText, _, _, let targetLanguage):
            if targetLanguage == "zh" {
                return languageStore.localizedFormat("practice_prompt_to_zh", sourceText)
            }
            return languageStore.localizedFormat("practice_prompt_to_id", sourceText)
        case .matching:
            return languageStore.localized("practice_matching_title")
        case .fillBlank:
            return languageStore.localized("practice_fill_blank_title")
        case .translation(let sourceText, _, let targetLanguage):
            if targetLanguage == "zh" {
                return languageStore.localizedFormat("practice_translate_to_zh", sourceText)
            }
            return languageStore.localizedFormat("practice_translate_to_id", sourceText)
        case .listening:
            return languageStore.localized("practice_listening_title")
        case .sentenceOrder:
            return languageStore.localized("practice_sentence_order_title")
        }
    }

    @ViewBuilder
    private func questionBody(for question: PracticeQuestion) -> some View {
        switch question.payload {
        case .multipleChoice(_, let options, _, _):
            VStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    PracticeOptionButton(title: option, isSelected: selectedOption == option) {
                        selectedOption = option
                    }
                }
            }
        case .matching(let left, let right, let pairs):
            VStack(spacing: 10) {
                ForEach(left, id: \.self) { leftItem in
                    HStack {
                        Text(leftItem)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Menu {
                            ForEach(right, id: \.self) { option in
                                Button(option) {
                                    matchSelections[leftItem] = option
                                }
                            }
                        } label: {
                            Text(matchSelections[leftItem] ?? languageStore.localized("practice_select"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.surfaceMuted)
                                .clipShape(Capsule())
                        }
                    }
                }
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
        case .fillBlank(let prompt, _):
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                TextField(languageStore.localized("practice_fill_blank_placeholder"), text: $fillBlankText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
        case .translation:
            VStack(alignment: .leading, spacing: 8) {
                TextField(languageStore.localized("practice_translation_placeholder"), text: $translationText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
        case .listening(let audioText, let options, _, _, let audioLanguage):
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    UnifiedAppButton(title: languageStore.localized("practice_listening_play"), systemImage: "speaker.wave.2", style: .secondary) {
                        SpeechService.shared.speak(audioText, language: audioLanguage)
                    }
                    Text(languageStore.localized("practice_listening_hint"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ForEach(options, id: \.self) { option in
                    PracticeOptionButton(title: option, isSelected: selectedOption == option) {
                        selectedOption = option
                    }
                }
            }
            .onAppear {
                SpeechService.shared.speak(audioText, language: audioLanguage)
            }
        case .sentenceOrder(let words, _, _):
            VStack(alignment: .leading, spacing: 10) {
                Text(languageStore.localized("practice_sentence_order_hint"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(availableWords, id: \.self) { word in
                        PracticeWordChip(title: word, style: .secondary) {
                            availableWords.removeAll { $0 == word }
                            orderedWords.append(word)
                        }
                    }
                }
                Divider()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(orderedWords, id: \.self) { word in
                        PracticeWordChip(title: word, style: .primary) {
                            orderedWords.removeAll { $0 == word }
                            availableWords.append(word)
                        }
                    }
                }
            }
            .onAppear {
                if availableWords.isEmpty {
                    availableWords = words
                    orderedWords = []
                }
            }
        }
    }

    private func submitCurrent() {
        let question = questions[currentIndex]
        var correct = false
        var detail = ""

        switch question.payload {
        case .multipleChoice(_, _, let answer, _):
            correct = normalized(selectedOption) == normalized(answer)
            detail = answer
        case .matching(_, _, let pairs):
            correct = pairs.allSatisfy { pair in
                normalized(matchSelections[pair.left]) == normalized(pair.right)
            }
            detail = matchingDetail(pairs: pairs)
        case .fillBlank(_, let answer):
            correct = normalized(fillBlankText) == normalized(answer)
            detail = answer
        case .translation(_, let answer, _):
            correct = normalized(translationText) == normalized(answer)
            detail = answer
        case .listening(_, _, let answer, _, _):
            correct = normalized(selectedOption) == normalized(answer)
            detail = answer
        case .sentenceOrder(_, let answer, _):
            let combined = orderedWords.joined(separator: " ")
            correct = normalized(combined) == normalized(answer)
            detail = answer
        }

        isCorrect = correct
        answered = true
        answerDetail = detail
        results.append(PracticeResultItem(question: question, isCorrect: correct))
        if !correct {
            wrongStore.addWrong(itemId: question.itemId, mode: question.mode, type: question.type)
        }
    }

    private func goNext() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            resetState()
            answered = false
            isCorrect = false
        } else {
            finalizeSession()
        }
    }

    private func finalizeSession() {
        let correctCount = results.filter { $0.isCorrect }.count
        let duration = Date().timeIntervalSince(startTime)
        statsStore.recordPracticeSession(correct: correctCount, total: results.count, duration: duration)
        dailyStore.markCompleted(.practice)
        if source == .wrongBook {
            dailyStore.markCompleted(.review)
        }
        showSummary = true
    }

    private func resetState() {
        selectedOption = nil
        matchSelections = [:]
        fillBlankText = ""
        translationText = ""
        orderedWords = []
        availableWords = []
        answerDetail = ""
    }

    private func loadQuestions() {
        let items = SampleData.vocabCategories.flatMap { $0.items }
        if source == .wrongBook {
            let wrongItems = wrongStore.items.filter { $0.mode == mode }
            questions = PracticeGenerator.generateQuestions(from: wrongItems, allItems: items)
        } else {
            questions = PracticeGenerator.generateQuestions(mode: mode, count: questionCount, types: types, sourceItems: items)
        }
        startTime = Date()
        resetState()
        answered = false
        isCorrect = false
        results = []
        showSummary = questions.isEmpty
    }

    private func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func matchingDetail(pairs: [PracticeMatchPair]) -> String {
        pairs.map { "\($0.left) → \($0.right)" }.joined(separator: " · ")
    }
}

struct PracticeProgressCard: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(current)/\(total)")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            ProgressView(value: Double(current), total: Double(total))
                .tint(AppTheme.accentStrong)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct PracticeOptionButton: View {
    let title: String
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accentStrong)
                }
            }
            .padding(12)
            .background(isSelected ? AppTheme.accentStrong.opacity(0.12) : AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PracticeWordChip: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let style: Style
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(style == .primary ? AppTheme.accentWarm.opacity(0.18) : AppTheme.surfaceMuted)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PracticeAnswerStateView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let isCorrect: Bool
    let detail: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isCorrect ? AppTheme.success : AppTheme.error)
            Text(isCorrect ? languageStore.localized("practice_correct") : languageStore.localized("practice_wrong"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCorrect ? AppTheme.success : AppTheme.error)
            if !isCorrect {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(8)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PracticeResultItem: Identifiable {
    let id = UUID().uuidString
    let question: PracticeQuestion
    let isCorrect: Bool
}

struct PracticeResultView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let results: [PracticeResultItem]
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageStore.localized("practice_result_title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(results.filter { $0.isCorrect }.count) / \(results.count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.accentStrong)

            VStack(alignment: .leading, spacing: 8) {
                Text(languageStore.localized("practice_result_correct"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(results.filter { $0.isCorrect }) { item in
                    Text(resultLabel(for: item.question))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(languageStore.localized("practice_result_wrong"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(results.filter { !$0.isCorrect }) { item in
                    Text(resultLabel(for: item.question))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }

            UnifiedAppButton(title: languageStore.localized("practice_done"), systemImage: nil, style: .primary) {
                onDone()
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private func resultLabel(for question: PracticeQuestion) -> String {
        switch question.payload {
        case .multipleChoice(let sourceText, _, _, _):
            return sourceText
        case .matching(let left, _, _):
            return left.joined(separator: ", ")
        case .fillBlank(let prompt, _):
            return prompt
        case .translation(let sourceText, _, _):
            return sourceText
        case .listening(let audioText, _, _, _, _):
            return audioText
        case .sentenceOrder(_, let answer, _):
            return answer
        }
    }
}

struct PracticeEmptyStateView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(AppTheme.textTertiary)
            Text(languageStore.localized("practice_empty_title"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(languageStore.localized("practice_empty_subtitle"))
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}
