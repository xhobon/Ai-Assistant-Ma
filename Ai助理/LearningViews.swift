import SwiftUI
#if os(macOS)
import AppKit
#endif

struct IndonesianLearningView: View {
    @StateObject private var viewModel = LearningViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var searchText = ""
    @State private var selectedDifficulty = "全部"
    @State private var showFavoritesOnly = false

    private let difficulties = ["全部", "入门", "进阶", "高级"]
    private let horizontalPadding: CGFloat = 14
    private let sectionSpacing: CGFloat = 12
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: sectionSpacing) {
                LearningSearchPanel(
                    searchText: $searchText,
                    selectedDifficulty: $selectedDifficulty,
                    showFavoritesOnly: $showFavoritesOnly,
                    difficulties: difficulties
                )
                .padding(.horizontal, horizontalPadding)

                LearningOverviewRow(viewModel: viewModel)
                    .padding(.horizontal, horizontalPadding)

                LearningResourceSection(
                    categories: viewModel.categories,
                    selectedCategoryId: $viewModel.selectedCategoryId,
                    difficulties: difficulties,
                    selectedDifficulty: $selectedDifficulty,
                    showFavoritesOnly: $showFavoritesOnly
                )
                .padding(.horizontal, horizontalPadding)

                VocabularyListSection(
                    items: filteredItems,
                    viewModel: viewModel,
                    difficultyProvider: difficultyForItem
                )
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.top, 10)
            .padding(.bottom, 28)
            .frame(maxWidth: pageMaxWidth, alignment: .top)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollIndicators(.automatic)
        .background(
            AppTheme.pageBackground
                .ignoresSafeArea(edges: .top)
        )
        .navigationTitle("学习")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredItems: [VocabItem] {
        let base = viewModel.filteredItems
        let searched = searchText.isEmpty
            ? base
            : base.filter {
                $0.textZh.localizedCaseInsensitiveContains(searchText)
                || $0.textId.localizedCaseInsensitiveContains(searchText)
                || $0.exampleZh.localizedCaseInsensitiveContains(searchText)
                || $0.exampleId.localizedCaseInsensitiveContains(searchText)
            }

        let difficultyFiltered = selectedDifficulty == "全部"
            ? searched
            : searched.filter { difficultyForItem($0) == selectedDifficulty }

        if showFavoritesOnly {
            return difficultyFiltered.filter { viewModel.isFavorite($0) }
        }

        return difficultyFiltered
    }

    private func difficultyForItem(_ item: VocabItem) -> String {
        let digits = item.id.compactMap { Int(String($0)) }
        let value = digits.first ?? 1
        if value <= 2 {
            return "入门"
        } else if value <= 4 {
            return "进阶"
        }
        return "高级"
    }

    private var learningHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("学习中心")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("词汇 / 短句 / 场景练习")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "book.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.92, green: 0.96, blue: 1.0))
        )
    }
}

struct PracticeHomeView: View {
    @StateObject private var viewModel = LearningViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("practice_goal_minutes") private var goalMinutes = 20
    @AppStorage("practice_goal_review_words") private var goalReviewWords = 12
    @AppStorage("practice_today_minutes") private var todayMinutes = 0
    @AppStorage("practice_today_reviewed_words") private var todayReviewedWords = 0
    @AppStorage("practice_today_date") private var todayDateKey = ""
    @State private var choiceQuestion: PracticeChoiceQuestion?
    @State private var selectedChoiceId: String?
    @State private var choiceAnswerCorrect: Bool?
    @State private var choiceAnsweredCount = 0
    @State private var choiceCorrectCount = 0

    @State private var tfQuestion: PracticeTrueFalseQuestion?
    @State private var tfAnswered: Bool?
    @State private var tfAnswerCorrect: Bool?
    @State private var tfAnsweredCount = 0
    @State private var tfCorrectCount = 0

    @State private var flashcardItem: VocabItem?
    @State private var flashcardRevealed = false
    @State private var flashcardMasteredCount = 0
    @State private var searchText = ""
    @State private var selectedDifficulty = "全部"
    @State private var showFavoritesOnly = false
    @State private var selectedMode: PracticeMode = .choice
    @State private var listeningQuestion: PracticeListeningQuestion?
    @State private var selectedListeningOptionId: String?
    @State private var listeningAnswerCorrect: Bool?
    @State private var listeningAnsweredCount = 0
    @State private var listeningCorrectCount = 0
    @State private var spellingQuestion: VocabItem?
    @State private var spellingInput = ""
    @State private var spellingAnswerCorrect: Bool?
    @State private var spellingAnsweredCount = 0
    @State private var spellingCorrectCount = 0
    @State private var reorderQuestion: PracticeReorderQuestion?
    @State private var reorderPickedWords: [String] = []
    @State private var reorderAnswerCorrect: Bool?
    @State private var reorderAnsweredCount = 0
    @State private var reorderCorrectCount = 0
    @State private var streakInSession = 0
    @State private var bestStreakInSession = 0
    @State private var heartsLeft = 3
    @State private var xp = 0
    @State private var showGoalEditor = false

    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }
    private var allItems: [VocabItem] {
        viewModel.categories.flatMap { $0.items }
    }
    private var categoryItems: [VocabItem] {
        guard let selected = viewModel.selectedCategoryId,
              let category = viewModel.categories.first(where: { $0.id == selected }) else {
            return allItems
        }
        return category.items
    }
    private var practiceItems: [VocabItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = keyword.isEmpty ? categoryItems : categoryItems.filter {
            $0.textZh.localizedCaseInsensitiveContains(keyword)
            || $0.textId.localizedCaseInsensitiveContains(keyword)
            || $0.exampleZh.localizedCaseInsensitiveContains(keyword)
            || $0.exampleId.localizedCaseInsensitiveContains(keyword)
        }
        let byDifficulty = selectedDifficulty == "全部"
            ? searched
            : searched.filter { difficultyForItem($0) == selectedDifficulty }
        if showFavoritesOnly {
            return byDifficulty.filter { viewModel.isFavorite($0) }
        }
        return byDifficulty
    }
    private var pendingCountText: String {
        "\(max(0, goalReviewWords - todayReviewedWords))词"
    }
    private var todayTargetText: String {
        "\(todayMinutes)/\(goalMinutes)分钟"
    }
    private var streakText: String {
        "\(max(viewModel.activeDaysCount, 1))天"
    }
    private var overallAnswered: Int {
        choiceAnsweredCount + tfAnsweredCount + listeningAnsweredCount + spellingAnsweredCount + reorderAnsweredCount + flashcardMasteredCount
    }
    private var overallCorrect: Int {
        choiceCorrectCount + tfCorrectCount + listeningCorrectCount + spellingCorrectCount + reorderCorrectCount
    }
    private var accuracyText: String {
        guard overallAnswered > 0 else { return "0%" }
        let percent = Int((Double(overallCorrect) / Double(max(1, overallAnswered))) * 100)
        return "\(percent)%"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                LearningSearchPanel(
                    searchText: $searchText,
                    selectedDifficulty: $selectedDifficulty,
                    showFavoritesOnly: $showFavoritesOnly,
                    difficulties: ["全部", "入门", "进阶", "高级"]
                )
                .padding(.horizontal, 14)

                LearningPlanCard(
                    title: "练习目标",
                    todayTargetText: todayTargetText,
                    pendingReviewText: pendingCountText,
                    streakText: streakText,
                    actionTitle: "自定义",
                    action: { showGoalEditor = true }
                )
                    .padding(.horizontal, 14)

                practiceChallengeCard
                    .padding(.horizontal, 14)

                practiceOverviewCard
                    .padding(.horizontal, 14)

                practiceCategorySection
                    .padding(.horizontal, 14)

                practiceModeSection
                    .padding(.horizontal, 14)
            }
            .padding(.top, 10)
            .padding(.bottom, 28)
            .frame(maxWidth: pageMaxWidth, alignment: .top)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollIndicators(.automatic)
        .background(
            AppTheme.pageBackground
                .ignoresSafeArea(edges: .top)
        )
        .navigationTitle("练习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshDailyBucketIfNeeded()
            if viewModel.selectedCategoryId == nil {
                viewModel.selectedCategoryId = viewModel.categories.first?.id
            }
            if choiceQuestion == nil { generateChoiceQuestion() }
            if tfQuestion == nil { generateTrueFalseQuestion() }
            if flashcardItem == nil { generateFlashcard() }
            if listeningQuestion == nil { generateListeningQuestion() }
            if spellingQuestion == nil { generateSpellingQuestion() }
            if reorderQuestion == nil { generateReorderQuestion() }
        }
        .onChange(of: viewModel.selectedCategoryId) { _, _ in
            regenerateAllQuestions()
        }
        .onChange(of: searchText) { _, _ in
            regenerateAllQuestions()
        }
        .sheet(isPresented: $showGoalEditor) {
            PracticeGoalEditorSheet(
                goalMinutes: $goalMinutes,
                goalReviewWords: $goalReviewWords
            )
            .presentationDetents([.medium])
        }
    }

    private var practiceOverviewCard: some View {
        HStack(spacing: 8) {
            practiceStatItem(title: "总练习", value: "\(overallAnswered)", subtitle: "已完成")
            practiceStatItem(title: "正确率", value: accuracyText, subtitle: "综合")
            practiceStatItem(title: "连击", value: "\(bestStreakInSession)", subtitle: "本次最佳")
        }
        .padding(10)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var practiceChallengeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日挑战")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("Lv.\(xp / 100 + 1) · XP \(xp)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            HStack(spacing: 8) {
                Label("\(heartsLeft)/3", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(heartsLeft > 0 ? Color.red : AppTheme.textTertiary)
                ProgressView(value: Double(xp % 100), total: 100)
                    .tint(AppTheme.primary)
                Text("下一级")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if heartsLeft == 0 {
                Button("恢复体力并继续练习") {
                    heartsLeft = 3
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private func practiceStatItem(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var practiceCategorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("练习主题")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("按学习分类选择练习场景")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.categories) { category in
                        let selected = viewModel.selectedCategoryId == category.id
                        Button {
                            viewModel.selectedCategoryId = category.id
                        } label: {
                            Text(category.nameZh)
                                .font(.caption.weight(selected ? .semibold : .medium))
                                .foregroundStyle(selected ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selected ? AppTheme.accentStrong : AppTheme.surface)
                                )
                        }
                        .buttonStyle(.plain)
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

    private var practiceModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("练习模式")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PracticeMode.allCases) { mode in
                        let selected = selectedMode == mode
                        Button {
                            selectedMode = mode
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: mode.icon)
                                Text(mode.title)
                            }
                            .font(.caption.weight(selected ? .semibold : .medium))
                            .foregroundStyle(selected ? .white : AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? AppTheme.accentStrong : AppTheme.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Group {
                switch selectedMode {
                case .choice: practiceChoiceCard
                case .trueFalse: practiceTrueFalseCard
                case .flashcard: practiceFlashcardCard
                case .listening: practiceListeningCard
                case .spelling: practiceSpellingCard
                case .reorder: practiceReorderCard
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private var practiceChoiceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("词汇四选一")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("正确 \(choiceCorrectCount)/\(choiceAnsweredCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            if let question = choiceQuestion {
                Text("“\(question.promptZh)” 的印尼语是：")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                VStack(spacing: 8) {
                    ForEach(question.options) { option in
                        Button {
                            submitChoice(option.id, for: question)
                        } label: {
                            HStack {
                                Text(option.textId)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if selectedChoiceId == option.id {
                                    Image(systemName: option.id == question.correctId ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(option.id == question.correctId ? Color.green : Color.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedChoiceId != nil)
                    }
                }

                if let correct = choiceAnswerCorrect {
                    Text(correct ? "答对了，继续保持！" : "答错了，正确答案已标记。")
                        .font(.caption)
                        .foregroundStyle(correct ? Color.green : AppTheme.accentWarm)
                }

                Button("下一题") {
                    generateChoiceQuestion()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }
        }
    }

    private var practiceTrueFalseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("对错判断")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("正确 \(tfCorrectCount)/\(tfAnsweredCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            if let question = tfQuestion {
                Text("“\(question.promptZh)” 的印尼语是 “\(question.shownId)”")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 10) {
                    Button("正确") { submitTrueFalse(true, for: question) }
                        .buttonStyle(.bordered)
                        .disabled(tfAnswered != nil)

                    Button("错误") { submitTrueFalse(false, for: question) }
                        .buttonStyle(.bordered)
                        .disabled(tfAnswered != nil)
                }

                if let correct = tfAnswerCorrect {
                    Text(correct ? "判断正确！" : "判断错误，继续加油。")
                        .font(.caption)
                        .foregroundStyle(correct ? Color.green : AppTheme.accentWarm)
                }

                Button("下一题") {
                    generateTrueFalseQuestion()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }
        }
    }

    private var practiceFlashcardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("闪卡记忆")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("已掌握 \(flashcardMasteredCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            if let item = flashcardItem {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        flashcardRevealed.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(flashcardRevealed ? item.textId : item.textZh)
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(flashcardRevealed ? item.exampleId : "点卡片翻面查看印尼语")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button("还没记住") {
                        generateFlashcard()
                    }
                    .buttonStyle(.bordered)

                    Button("记住了") {
                        flashcardMasteredCount += 1
                        registerPracticeResult(correct: true, minutes: 2, reviewedWords: 1)
                        viewModel.registerActiveDayIfNeeded()
                        generateFlashcard()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                }
            }
        }
    }

    private var practiceListeningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("听力选择")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("正确 \(listeningCorrectCount)/\(listeningAnsweredCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            if let question = listeningQuestion {
                Button {
                    SpeechService.shared.speak(question.promptId, language: "id-ID")
                } label: {
                    Label("播放单词发音", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    ForEach(question.options) { option in
                        Button {
                            submitListening(option.id, for: question)
                        } label: {
                            HStack {
                                Text(option.textZh)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if selectedListeningOptionId == option.id {
                                    Image(systemName: option.id == question.correctId ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(option.id == question.correctId ? Color.green : Color.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedListeningOptionId != nil)
                    }
                }

                if let correct = listeningAnswerCorrect {
                    Text(correct ? "听力正确！" : "再听一遍会更容易记住。")
                        .font(.caption)
                        .foregroundStyle(correct ? Color.green : AppTheme.accentWarm)
                }

                Button("下一题") { generateListeningQuestion() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
            }
        }
    }

    private var practiceSpellingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("拼写挑战")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("正确 \(spellingCorrectCount)/\(spellingAnsweredCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            if let question = spellingQuestion {
                Text("把这句中文写成印尼语词汇：\(question.textZh)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                TextField("输入印尼语答案", text: $spellingInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 10) {
                    Button("检查答案") {
                        submitSpelling(for: question)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(spellingInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || spellingAnswerCorrect != nil)

                    Button("换一题") {
                        generateSpellingQuestion()
                    }
                    .buttonStyle(.bordered)
                }

                if let correct = spellingAnswerCorrect {
                    Text(correct ? "拼写正确！" : "正确答案：\(question.textId)")
                        .font(.caption)
                        .foregroundStyle(correct ? Color.green : AppTheme.accentWarm)
                }
            }
        }
    }

    private var practiceReorderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("句子重组")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("正确 \(reorderCorrectCount)/\(reorderAnsweredCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            if let question = reorderQuestion {
                Text("把这句中文重组成正确印尼语：\(question.promptZh)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(reorderPickedWords.joined(separator: " "))
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                FlexibleWordWrap(words: question.shuffledWords) { word in
                    let matchedCount = reorderPickedWords.filter { $0 == word }.count
                    let allowedCount = question.targetWords.filter { $0 == word }.count
                    guard matchedCount < allowedCount else { return }
                    reorderPickedWords.append(word)
                }

                HStack(spacing: 10) {
                    Button("清空") { reorderPickedWords.removeAll() }
                        .buttonStyle(.bordered)
                    Button("检查") { submitReorder(for: question) }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                    Button("下一题") { generateReorderQuestion() }
                        .buttonStyle(.bordered)
                }

                if let correct = reorderAnswerCorrect {
                    Text(correct ? "顺序完全正确！" : "正确答案：\(question.targetWords.joined(separator: " "))")
                        .font(.caption)
                        .foregroundStyle(correct ? Color.green : AppTheme.accentWarm)
                }
            }
        }
    }

    private func generateChoiceQuestion() {
        guard practiceItems.count >= 4, let correct = practiceItems.randomElement() else { return }
        let wrongs = practiceItems.filter { $0.id != correct.id }.shuffled().prefix(3)
        let options = ([correct] + Array(wrongs)).shuffled()
        choiceQuestion = PracticeChoiceQuestion(
            promptZh: correct.textZh,
            correctId: correct.id,
            options: options
        )
        selectedChoiceId = nil
        choiceAnswerCorrect = nil
    }

    private func submitChoice(_ optionId: String, for question: PracticeChoiceQuestion) {
        guard heartsLeft > 0 else { return }
        guard selectedChoiceId == nil else { return }
        selectedChoiceId = optionId
        let correct = optionId == question.correctId
        choiceAnswerCorrect = correct
        choiceAnsweredCount += 1
        if correct { choiceCorrectCount += 1 }
        registerPracticeResult(correct: correct, minutes: 2, reviewedWords: 1)
        viewModel.registerActiveDayIfNeeded()
    }

    private func generateTrueFalseQuestion() {
        guard practiceItems.count >= 2, let base = practiceItems.randomElement() else { return }
        let isTrue = Bool.random()
        let shown: String
        if isTrue {
            shown = base.textId
        } else {
            shown = practiceItems.filter { $0.id != base.id }.randomElement()?.textId ?? base.textId
        }
        tfQuestion = PracticeTrueFalseQuestion(
            promptZh: base.textZh,
            shownId: shown,
            isTrueStatement: shown == base.textId
        )
        tfAnswered = nil
        tfAnswerCorrect = nil
    }

    private func submitTrueFalse(_ answer: Bool, for question: PracticeTrueFalseQuestion) {
        guard heartsLeft > 0 else { return }
        guard tfAnswered == nil else { return }
        tfAnswered = answer
        let correct = answer == question.isTrueStatement
        tfAnswerCorrect = correct
        tfAnsweredCount += 1
        if correct { tfCorrectCount += 1 }
        registerPracticeResult(correct: correct, minutes: 2, reviewedWords: 1)
        viewModel.registerActiveDayIfNeeded()
    }

    private func generateFlashcard() {
        flashcardItem = practiceItems.randomElement() ?? allItems.randomElement()
        flashcardRevealed = false
    }

    private func generateListeningQuestion() {
        guard practiceItems.count >= 4, let correct = practiceItems.randomElement() else { return }
        let wrongs = practiceItems.filter { $0.id != correct.id }.shuffled().prefix(3)
        listeningQuestion = PracticeListeningQuestion(
            promptId: correct.textId,
            correctId: correct.id,
            options: ([correct] + Array(wrongs)).shuffled()
        )
        selectedListeningOptionId = nil
        listeningAnswerCorrect = nil
    }

    private func submitListening(_ optionId: String, for question: PracticeListeningQuestion) {
        guard heartsLeft > 0 else { return }
        guard selectedListeningOptionId == nil else { return }
        selectedListeningOptionId = optionId
        let correct = optionId == question.correctId
        listeningAnswerCorrect = correct
        listeningAnsweredCount += 1
        if correct { listeningCorrectCount += 1 }
        registerPracticeResult(correct: correct, minutes: 2, reviewedWords: 1)
        viewModel.registerActiveDayIfNeeded()
    }

    private func generateSpellingQuestion() {
        spellingQuestion = practiceItems.randomElement() ?? allItems.randomElement()
        spellingInput = ""
        spellingAnswerCorrect = nil
    }

    private func submitSpelling(for question: VocabItem) {
        guard heartsLeft > 0 else { return }
        guard spellingAnswerCorrect == nil else { return }
        let input = spellingInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let answer = question.textId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let correct = input == answer
        spellingAnswerCorrect = correct
        spellingAnsweredCount += 1
        if correct { spellingCorrectCount += 1 }
        registerPracticeResult(correct: correct, minutes: 3, reviewedWords: 1)
        viewModel.registerActiveDayIfNeeded()
    }

    private func generateReorderQuestion() {
        guard let item = (practiceItems.randomElement() ?? allItems.randomElement()) else { return }
        let words = item.textId
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "." || $0 == "?" || $0 == "!" })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard words.count >= 2 else {
            reorderQuestion = PracticeReorderQuestion(promptZh: item.textZh, targetWords: [item.textId], shuffledWords: [item.textId])
            reorderPickedWords = []
            reorderAnswerCorrect = nil
            return
        }
        reorderQuestion = PracticeReorderQuestion(
            promptZh: item.textZh,
            targetWords: words,
            shuffledWords: words.shuffled()
        )
        reorderPickedWords = []
        reorderAnswerCorrect = nil
    }

    private func submitReorder(for question: PracticeReorderQuestion) {
        guard heartsLeft > 0 else { return }
        guard !reorderPickedWords.isEmpty else { return }
        let correct = reorderPickedWords == question.targetWords
        reorderAnswerCorrect = correct
        reorderAnsweredCount += 1
        if correct { reorderCorrectCount += 1 }
        registerPracticeResult(correct: correct, minutes: 3, reviewedWords: 1)
        viewModel.registerActiveDayIfNeeded()
    }

    private func regenerateAllQuestions() {
        generateChoiceQuestion()
        generateTrueFalseQuestion()
        generateFlashcard()
        generateListeningQuestion()
        generateSpellingQuestion()
        generateReorderQuestion()
    }

    private func difficultyForItem(_ item: VocabItem) -> String {
        let digits = item.id.compactMap { Int(String($0)) }
        let value = digits.first ?? 1
        if value <= 2 { return "入门" }
        if value <= 4 { return "进阶" }
        return "高级"
    }

    private func refreshDailyBucketIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        if todayDateKey != today {
            todayDateKey = today
            todayMinutes = 0
            todayReviewedWords = 0
        }
    }

    private func addPracticeProgress(minutes: Int, reviewedWords: Int) {
        refreshDailyBucketIfNeeded()
        todayMinutes += max(0, minutes)
        todayReviewedWords += max(0, reviewedWords)
    }

    private func registerPracticeResult(correct: Bool, minutes: Int, reviewedWords: Int) {
        addPracticeProgress(minutes: minutes, reviewedWords: reviewedWords)
        if !correct {
            heartsLeft = max(0, heartsLeft - 1)
        } else {
            xp += 12
        }
        if correct {
            streakInSession += 1
            bestStreakInSession = max(bestStreakInSession, streakInSession)
        } else {
            streakInSession = 0
        }
    }
}

private struct LearningPlanCard: View {
    var title: String? = nil
    var todayTargetText: String = "20分钟"
    var pendingReviewText: String = "12词"
    var streakText: String = "5天"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if (title?.isEmpty == false) || action != nil {
                HStack {
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Spacer()
                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                planItem("今日目标", value: todayTargetText, icon: "timer")
                planItem("待复习", value: pendingReviewText, icon: "arrow.clockwise")
                planItem("连胜天数", value: streakText, icon: "flame.fill")
            }
        }
        .padding(10)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func planItem(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PracticeChoiceQuestion {
    let promptZh: String
    let correctId: String
    let options: [VocabItem]
}

private struct PracticeTrueFalseQuestion {
    let promptZh: String
    let shownId: String
    let isTrueStatement: Bool
}

private struct PracticeListeningQuestion {
    let promptId: String
    let correctId: String
    let options: [VocabItem]
}

private struct PracticeReorderQuestion {
    let promptZh: String
    let targetWords: [String]
    let shuffledWords: [String]
}

private enum PracticeMode: String, CaseIterable, Identifiable {
    case choice
    case trueFalse
    case flashcard
    case listening
    case spelling
    case reorder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .choice: return "选择"
        case .trueFalse: return "判断"
        case .flashcard: return "闪卡"
        case .listening: return "听力"
        case .spelling: return "拼写"
        case .reorder: return "重组"
        }
    }

    var icon: String {
        switch self {
        case .choice: return "checkmark.circle"
        case .trueFalse: return "questionmark.circle"
        case .flashcard: return "rectangle.on.rectangle"
        case .listening: return "speaker.wave.2"
        case .spelling: return "pencil.and.outline"
        case .reorder: return "text.line.first.and.arrowtriangle.forward"
        }
    }
}

private struct FlexibleWordWrap: View {
    let words: [String]
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 70), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Button(word) { onTap(word) }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppTheme.surfaceMuted)
                    .foregroundStyle(AppTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .buttonStyle(.plain)
            }
        }
    }
}

private struct PracticeGoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var goalMinutes: Int
    @Binding var goalReviewWords: Int

    var body: some View {
        NavigationStack {
            Form {
                Stepper(value: $goalMinutes, in: 5...180, step: 5) {
                    HStack {
                        Text("每日目标时长")
                        Spacer()
                        Text("\(goalMinutes) 分钟")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Stepper(value: $goalReviewWords, in: 1...200, step: 1) {
                    HStack {
                        Text("每日复习词数")
                        Spacer()
                        Text("\(goalReviewWords) 词")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("自定义目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}


struct LearningHeroHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            UnifiedHeroHeader(
                systemImage: "book.fill",
                title: "印尼语学习",
                subtitle: "词汇、短句、口语场景",
                badgeText: "今日 20 分钟",
                headline: "开启高效学习节奏",
                subheadline: "为你推荐高频词汇与场景短句"
            )
            HStack(spacing: 12) {
                LearningStatBadge(title: "已掌握", value: "126")
                LearningStatBadge(title: "连续学习", value: "5 天")
                LearningStatBadge(title: "今日完成", value: "8/20")
            }
            .padding(.horizontal, 20)
        }
    }
}

// 学习页紧凑页头（高对比、省空间）
struct LearningPageCompactHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                Text("印尼语学习")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text("开启高效学习节奏 · 高频词汇与场景短句")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                LearningStatBadge(title: "已掌握", value: "126")
                LearningStatBadge(title: "连续学习", value: "5 天")
                LearningStatBadge(title: "今日完成", value: "8/20")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

struct LearningStatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct LearningSearchPanel: View {
    @Binding var searchText: String
    @Binding var selectedDifficulty: String
    @Binding var showFavoritesOnly: Bool
    let difficulties: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SearchBar(text: $searchText)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct LearningInsightCard: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accentWarm.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accentWarm)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct LearningOverviewRow: View {
    @ObservedObject var viewModel: LearningViewModel

    var body: some View {
        VStack(spacing: 10) {
            LearningProgressCard(
                completedText: progressCompletedText,
                daysText: "\(viewModel.activeDaysCount) 天",
                masteredText: "\(viewModel.masteredCount)"
            )
        }
        .onAppear {
            viewModel.registerActiveDayIfNeeded()
        }
    }

    private var progressCompletedText: String {
        let total = viewModel.totalVocabCount
        let mastered = viewModel.masteredCount
        guard total > 0 else { return "0/0" }
        return "\(mastered)/\(total)"
    }
}

struct LearningResourceSection: View {
    let categories: [VocabCategory]
    @Binding var selectedCategoryId: String?
    let difficulties: [String]
    @Binding var selectedDifficulty: String
    @Binding var showFavoritesOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("学习主题")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("按主题浏览高频词汇与场景 · 共 \(categories.count) 类")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                    ForEach(difficulties, id: \.self) { item in
                        Button {
                            selectedDifficulty = item
                        } label: {
                            Text(item)
                                .font(.caption.weight(selectedDifficulty == item ? .semibold : .medium))
                                .foregroundStyle(selectedDifficulty == item ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(minWidth: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedDifficulty == item ? AppTheme.accentStrong : AppTheme.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            Text("仅看收藏")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(showFavoritesOnly ? AppTheme.accentStrong : AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(showFavoritesOnly ? AppTheme.accentStrong.opacity(0.15) : AppTheme.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        let tint = tintForIndex(index)
                        Button {
                            selectedCategoryId = category.id
                        } label: {
                            LearningResourceCard(
                                category: category,
                                tint: tint,
                                systemImage: iconForIndex(index),
                                isSelected: selectedCategoryId == category.id
                            )
                        }
                        .buttonStyle(.plain)
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

    private func iconForIndex(_ index: Int) -> String {
        let icons = ["bolt.fill", "leaf.fill", "airplane", "cart.fill", "face.smiling", "curlybraces"]
        return icons[index % icons.count]
    }

    private func tintForIndex(_ index: Int) -> Color {
        let tints: [Color] = [AppTheme.accentStrong, AppTheme.accentWarm, AppTheme.brandBlue, .purple, .green, Color(red: 0.35, green: 0.34, blue: 0.84)]
        return tints[index % tints.count]
    }
}

struct LearningResourceCard: View {
    let category: VocabCategory
    let tint: Color
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tint)
            }

            Text(category.nameZh)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 72)
        .padding(.vertical, 8)
        .background(isSelected ? tint.opacity(0.12) : AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(isSelected ? 0.5 : 0.2), lineWidth: 1)
        )
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textTertiary)
            TextField("搜索词汇/短句/例句", text: $text)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FilterRow: View {
    let difficulties: [String]
    @Binding var selected: String
    @Binding var showFavoritesOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("难度筛选")
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(difficulties, id: \.self) { item in
                        Button {
                            selected = item
                        } label: {
                            Text(item)
                                .font(.caption.weight(selected == item ? .semibold : .regular))
                                .foregroundStyle(selected == item ? AppTheme.textPrimary : AppTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selected == item ? AppTheme.accent.opacity(0.2) : AppTheme.surface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            Text("仅看收藏")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(showFavoritesOnly ? AppTheme.accentStrong : AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showFavoritesOnly ? AppTheme.accentStrong.opacity(0.15) : AppTheme.surface)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct LearningProgressCard: View {
    let completedText: String
    let daysText: String
    let masteredText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("学习进度")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 8) {
                ProgressStatCard(title: "完成", value: completedText, color: AppTheme.accentStrong, icon: "checkmark.seal.fill")
                ProgressStatCard(title: "坚持", value: daysText, color: AppTheme.brandBlue, icon: "flame.fill")
                ProgressStatCard(title: "掌握", value: masteredText, color: AppTheme.accentWarm, icon: "bookmark.fill")
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct ProgressStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
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

struct TodayPlanCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日计划")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Text("3 项")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            HStack(spacing: 8) {
                PlanBlock(title: "10 个高频词", status: "进行中", tint: AppTheme.accentWarm)
                PlanBlock(title: "旅行场景短句", status: "待开始", tint: AppTheme.brandBlue)
                PlanBlock(title: "跟读 5 分钟", status: "已完成", tint: .green)
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

/// 今日计划横向单格（与学习进度三格样式一致）
struct PlanBlock: View {
    let title: String
    let status: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
            Text(status)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PlanRow: View {
    let title: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct VocabularyListSection: View {
    let items: [VocabItem]
    @ObservedObject var viewModel: LearningViewModel
    let difficultyProvider: (VocabItem) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("短句练习")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("双语对照 · 语音播放/复制/收藏")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Text("\(items.count) 条")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("暂无匹配内容")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("试试更换分类、难度或关键词")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        VocabularyCard(
                            item: item,
                            viewModel: viewModel,
                            difficulty: difficultyProvider(item)
                        )
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
}

struct VocabularyCard: View {
    let item: VocabItem
    @ObservedObject var viewModel: LearningViewModel
    let difficulty: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentWarm.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Text(String(item.textZh.prefix(1)))
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentWarm)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.textZh)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(item.textId)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.accentWarm)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    CircleIconButton(systemImage: "speaker.wave.2") {
                        SpeechService.shared.speak(item.textId, language: "id-ID")
                    }
                    CircleIconButton(systemImage: "doc.on.doc") {
                        ClipboardService.copy(item.textId)
                    }
                    CircleIconButton(systemImage: viewModel.isFavorite(item) ? "heart.fill" : "heart") {
                        viewModel.toggleFavorite(item)
                    }
                }

                VStack(alignment: .trailing, spacing: 6) {
                    DifficultyTag(text: difficulty)
                    if viewModel.isFavorite(item) {
                        Text("已收藏")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accentWarm)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("例句")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ExampleSentenceRow(
                    text: "中文：\(item.exampleZh)",
                    language: "zh-CN",
                    onCopy: { ClipboardService.copy(item.exampleZh) }
                )
                ExampleSentenceRow(
                    text: "印尼文：\(item.exampleId)",
                    language: "id-ID",
                    onCopy: { ClipboardService.copy(item.exampleId) }
                )
            }
            .padding(8)
            .background(AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct ExampleSentenceRow: View {
    let text: String
    let language: String
    var onCopy: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                CircleIconButton(systemImage: "speaker.wave.2") {
                    SpeechService.shared.speak(text, language: language)
                }
                if let onCopy {
                    CircleIconButton(systemImage: "doc.on.doc") {
                        onCopy()
                    }
                }
            }
            .frame(width: 60, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct DifficultyTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.accentStrong)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.accentStrong.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct CircleIconButton: View {
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 28, height: 28)
                .background(AppTheme.primary.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.primary.opacity(0.7), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}
