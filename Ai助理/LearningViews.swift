import SwiftUI

struct IndonesianLearningView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel = LearningViewModel()
    @StateObject private var statsStore = LearningStatsStore.shared
    @StateObject private var dailyStore = DailyTaskStore.shared
    @State private var searchText = ""
    @State private var selectedDifficulty: LearningDifficulty = .all
    @State private var showFavoritesOnly = false
    @State private var learningStart: Date? = nil

    private let difficulties = LearningDifficulty.allCases

    private let horizontalPadding: CGFloat = 14
    private let sectionSpacing: CGFloat = 12

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: sectionSpacing) {
                    LearningSearchPanel(
                        searchText: $searchText,
                        selectedDifficulty: $selectedDifficulty,
                        showFavoritesOnly: $showFavoritesOnly,
                        difficulties: difficulties
                    )
                    .padding(.horizontal, horizontalPadding)

                    LearningModeCard(selectedMode: Binding(
                        get: { viewModel.mode },
                        set: { viewModel.setMode($0) }
                    ))
                        .padding(.horizontal, horizontalPadding)

                    LearningOverviewRow(viewModel: viewModel)
                        .padding(.horizontal, horizontalPadding)

                    LearningStatsSummaryCard(
                        practiceSessions: statsStore.practiceSessions,
                        accuracy: statsStore.accuracy,
                        learningMinutes: statsStore.learningMinutes,
                        streakDays: dailyStore.currentStreakDays()
                    )
                    .padding(.horizontal, horizontalPadding)

                    DailyTaskCard(tasks: dailyStore.todayTasks) { task in
                        dailyStore.toggleTask(task.type)
                    }
                    .padding(.horizontal, horizontalPadding)

                    LearningProgressDetailCard(
                        vocabCount: viewModel.masteredCount,
                        lessonCount: viewModel.completedLessonsCount,
                        level: viewModel.learningLevel
                    )
                    .padding(.horizontal, horizontalPadding)

                    LearningResourceSection(
                        categories: viewModel.categories,
                        selectedCategoryId: $viewModel.selectedCategoryId,
                        difficulties: difficulties,
                        selectedDifficulty: $selectedDifficulty,
                        showFavoritesOnly: $showFavoritesOnly,
                        mode: viewModel.mode
                    )
                    .padding(.horizontal, horizontalPadding)

                    VocabularyListSection(
                        items: filteredItems,
                        viewModel: viewModel,
                        difficultyProvider: difficultyForItem,
                        mode: viewModel.mode
                    )
                    .padding(.horizontal, horizontalPadding)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 980, alignment: .top)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)
            .background(
                AppTheme.pageBackground
                    .ignoresSafeArea(edges: .top)
            )
            .hideNavigationBarOnMac()
            .onAppear {
                learningStart = Date()
                dailyStore.refreshTasks(for: Date())
            }
            .onDisappear {
                if let start = learningStart {
                    statsStore.addLearningDuration(Date().timeIntervalSince(start))
                }
                learningStart = nil
            }
        }
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
                || (viewModel.mode == .idToZh && PinyinService.shared.pinyin(for: $0.textZh).localizedCaseInsensitiveContains(searchText))
                || (viewModel.mode == .idToZh && PinyinService.shared.pinyin(for: $0.exampleZh).localizedCaseInsensitiveContains(searchText))
            }

        let difficultyFiltered = selectedDifficulty == .all
            ? searched
            : searched.filter { difficultyForItem($0) == selectedDifficulty }

        if showFavoritesOnly {
            return difficultyFiltered.filter { viewModel.isFavorite($0) }
        }

        return difficultyFiltered
    }

    private func difficultyForItem(_ item: VocabItem) -> LearningDifficulty {
        let digits = item.id.compactMap { Int(String($0)) }
        let value = digits.first ?? 1
        if value <= 2 {
            return .beginner
        } else if value <= 4 {
            return .intermediate
        }
        return .advanced
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
    @Binding var selectedDifficulty: LearningDifficulty
    @Binding var showFavoritesOnly: Bool
    let difficulties: [LearningDifficulty]

    var body: some View {
        VStack(spacing: 10) {
            SearchBar(text: $searchText)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct LearningModeCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Binding var selectedMode: LearningMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageStore.localized("learning_mode_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Picker("", selection: $selectedMode) {
                Text(languageStore.localized("learning_mode_zh_id")).tag(LearningMode.zhToId)
                Text(languageStore.localized("learning_mode_id_zh")).tag(LearningMode.idToZh)
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct LearningStatsSummaryCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let practiceSessions: Int
    let accuracy: Double
    let learningMinutes: Int
    let streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageStore.localized("learning_stats_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 8) {
                ProgressStatCard(title: languageStore.localized("learning_stats_practice"), value: "\(practiceSessions)", color: AppTheme.accentStrong, icon: "checkmark.seal.fill")
                ProgressStatCard(title: languageStore.localized("learning_stats_accuracy"), value: accuracyText, color: AppTheme.brandBlue, icon: "chart.bar.fill")
                ProgressStatCard(title: languageStore.localized("learning_stats_minutes"), value: "\(learningMinutes)", color: AppTheme.accentWarm, icon: "clock.fill")
                ProgressStatCard(title: languageStore.localized("learning_stats_streak"), value: "\(streakDays)", color: AppTheme.success, icon: "flame.fill")
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

struct DailyTaskCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let tasks: [DailyTask]
    var onToggle: (DailyTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(languageStore.localized("daily_task_title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Text("\(tasks.filter { $0.isCompleted }.count)/\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            VStack(spacing: 8) {
                ForEach(tasks, id: \.id) { task in
                    Button {
                        onToggle(task)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? AppTheme.success : AppTheme.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(languageStore.localized(task.titleKey))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(languageStore.localized(task.subtitleKey))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
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

struct LearningProgressDetailCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let vocabCount: Int
    let lessonCount: Int
    let level: LearningLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageStore.localized("learning_progress_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 8) {
                ProgressStatCard(title: languageStore.localized("learning_progress_vocab"), value: "\(vocabCount)", color: AppTheme.accentStrong, icon: "book.fill")
                ProgressStatCard(title: languageStore.localized("learning_progress_lessons"), value: "\(lessonCount)", color: AppTheme.brandBlue, icon: "square.grid.2x2.fill")
                ProgressStatCard(title: languageStore.localized("learning_progress_level"), value: levelText, color: AppTheme.accentWarm, icon: "star.fill")
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private var levelText: String {
        switch level {
        case .beginner: return languageStore.localized("learning_level_beginner")
        case .intermediate: return languageStore.localized("learning_level_intermediate")
        case .advanced: return languageStore.localized("learning_level_advanced")
        }
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
    @EnvironmentObject private var languageStore: AppLanguageStore
    let categories: [VocabCategory]
    @Binding var selectedCategoryId: String?
    let difficulties: [LearningDifficulty]
    @Binding var selectedDifficulty: LearningDifficulty
    @Binding var showFavoritesOnly: Bool
    let mode: LearningMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(languageStore.localized("learning_category_title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(languageStore.localizedFormat("learning_category_subtitle", categories.count))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(difficulties, id: \.self) { item in
                        Button {
                            selectedDifficulty = item
                        } label: {
                            Text(item.label)
                                .font(.caption.weight(selectedDifficulty == item ? .semibold : .medium))
                                .foregroundStyle(selectedDifficulty == item ? .white : AppTheme.textPrimary)
                                .frame(minWidth: 44)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedDifficulty == item ? AppTheme.accentStrong : AppTheme.surfaceMuted)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedDifficulty == item ? AppTheme.accentStrong : AppTheme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                                .font(.caption)
                            Text("仅看收藏")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(showFavoritesOnly ? AppTheme.accentStrong : AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(showFavoritesOnly ? AppTheme.accentStrong.opacity(0.12) : AppTheme.surfaceMuted)
                        )
                        .overlay(
                            Capsule()
                                .stroke(showFavoritesOnly ? AppTheme.accentStrong.opacity(0.6) : AppTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
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
                                isSelected: selectedCategoryId == category.id,
                                mode: mode
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
    let mode: LearningMode

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

            Text(mode == .zhToId ? category.nameZh : category.nameId)
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
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textTertiary)
            TextField(languageStore.localized("learning_search_placeholder"), text: $text)
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
    let difficulties: [LearningDifficulty]
    @Binding var selected: LearningDifficulty
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
                            Text(item.label)
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
    @EnvironmentObject private var languageStore: AppLanguageStore
    let items: [VocabItem]
    @ObservedObject var viewModel: LearningViewModel
    let difficultyProvider: (VocabItem) -> LearningDifficulty
    let mode: LearningMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(languageStore.localized("learning_vocab_section_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(languageStore.localized("learning_vocab_section_subtitle"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Text(languageStore.localizedFormat("learning_vocab_count", items.count))
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
                            difficulty: difficultyProvider(item),
                            mode: mode
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
    let mode: LearningMode

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
                    Text(primaryText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(secondaryText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.accentWarm)
                    if let pinyin = pinyinText, !pinyin.isEmpty {
                        Text(pinyin)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    CircleIconButton(systemImage: "speaker.wave.2") {
                        SpeechService.shared.speak(targetSpeechText, language: targetSpeechLang)
                    }
                    CircleIconButton(systemImage: "doc.on.doc") {
                        ClipboardService.copy(primaryText)
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
                ExampleSentenceRow(
                    title: "中文例句",
                    text: item.exampleZh,
                    language: "zh-CN",
                    pinyin: mode == .idToZh ? PinyinService.shared.pinyin(for: item.exampleZh) : nil,
                    onCopy: { ClipboardService.copy(item.exampleZh) }
                )
                ExampleSentenceRow(
                    title: "印尼语例句",
                    text: item.exampleId,
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

    private var primaryText: String {
        mode == .zhToId ? item.textZh : item.textId
    }

    private var secondaryText: String {
        mode == .zhToId ? item.textId : item.textZh
    }

    private var pinyinText: String? {
        guard mode == .idToZh else { return nil }
        return PinyinService.shared.pinyin(for: item.textZh)
    }

    private var targetSpeechText: String {
        secondaryText
    }

    private var targetSpeechLang: String {
        mode == .zhToId ? "id-ID" : "zh-CN"
    }
}

struct ExampleSentenceRow: View {
    let title: String
    let text: String
    let language: String
    var pinyin: String? = nil
    var onCopy: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                if let pinyin, !pinyin.isEmpty {
                    Text(pinyin)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                CircleIconButton(systemImage: "speaker.wave.2") {
                    SpeechService.shared.speak(text, language: language)
                }
                if let onCopy {
                    CircleIconButton(systemImage: "doc.on.doc") {
                        onCopy()
                    }
                }
            }
        }
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.unifiedButtonBorder)
                .frame(width: 32, height: 32)
                .background(AppTheme.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 0.9))
        }
        .buttonStyle(.plain)
    }
}
