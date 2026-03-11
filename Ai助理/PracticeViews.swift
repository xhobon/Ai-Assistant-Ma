import SwiftUI
import AudioToolbox
import Combine

enum PracticeSource {
    case all
    case wrongBook
}

struct PracticeHomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var statsStore = LearningStatsStore.shared
    @StateObject private var wrongStore = WrongBookStore.shared
    @StateObject private var learningModel = LearningViewModel()
    @AppStorage("learning_mode") private var storedMode: String = LearningMode.zhToId.rawValue
    @State private var lastAppliedLanguage: AppLanguage? = nil
    @State private var selectedType: PracticeQuestionType = .multipleChoice
    @State private var showSession = false
    @State private var sessionSource: PracticeSource = .all
    @State private var selectedDifficulty: LearningDifficulty = .beginner
    @State private var challengeEnabled = false
    @State private var comboEnabled = true
    @State private var timeLimit = 30
    @State private var autoBonusEnabled = true

    private let difficulties: [LearningDifficulty] = [.beginner, .intermediate, .advanced]
    private let timeOptions = [15, 30, 45]

    var body: some View {
        let _ = languageStore.current
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    PracticeHeaderCard()
                        .padding(.horizontal, 14)

                    PracticeModeCard(
                        selectedDifficulty: $selectedDifficulty,
                        difficulties: difficulties,
                        selectedType: $selectedType
                    )
                    .padding(.horizontal, 14)

                    PracticeChallengeCard(
                        isEnabled: $challengeEnabled,
                        timeLimit: $timeLimit,
                        timeOptions: timeOptions,
                        comboEnabled: $comboEnabled,
                        autoBonusEnabled: $autoBonusEnabled
                    )
                    .padding(.horizontal, 14)

                    PracticeStatsCard(practiceSessions: statsStore.practiceSessions, accuracy: statsStore.accuracy, learningMinutes: statsStore.learningMinutes)
                        .padding(.horizontal, 14)

                    WrongBookEntryCard(count: wrongStore.items.count) {
                        sessionSource = .wrongBook
                        showSession = true
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: 980, alignment: .top)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea(edges: .top))
            .navigationTitle(languageStore.localized("practice_title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                applyLanguageDefaultIfNeeded()
            }
            .onChange(of: languageStore.current) { _ in
                applyLanguageDefaultIfNeeded()
            }
            .safeAreaInset(edge: .bottom) {
                PracticeStartBar(
                    wrongBookCount: wrongStore.items.count,
                    onStart: {
                        sessionSource = .all
                        showSession = true
                    },
                    onWrongBook: {
                        sessionSource = .wrongBook
                        showSession = true
                    }
                )
            }
            .navigationDestination(isPresented: $showSession) {
                PracticeSessionView(
                    mode: LearningMode(rawValue: storedMode) ?? .zhToId,
                    questionCount: selectedCount,
                    types: [selectedType],
                    source: sessionSource,
                    sourceItems: filteredItems,
                    allItems: allItems,
                    difficulty: selectedDifficulty,
                    challengeEnabled: challengeEnabled,
                    timeLimit: timeLimit,
                    comboEnabled: challengeEnabled ? comboEnabled : false,
                    autoBonusEnabled: challengeEnabled ? autoBonusEnabled : false
                )
            }
        }
    }

    private var allItems: [VocabItem] {
        learningModel.categories.flatMap { $0.items }
    }

    private var filteredItems: [VocabItem] {
        let base = allItems
        return base.filter { difficultyForItem($0) == selectedDifficulty }
    }

    private var selectedCount: Int {
        switch selectedDifficulty {
        case .beginner: return 5
        case .intermediate: return 10
        case .advanced: return 20
        case .all: return 10
        }
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

    private func applyLanguageDefaultIfNeeded() {
        let currentLanguage = languageStore.current
        guard lastAppliedLanguage != currentLanguage else { return }
        let defaultMode: LearningMode = (currentLanguage == .indonesian) ? .idToZh : .zhToId
        if LearningMode(rawValue: storedMode) != defaultMode {
            storedMode = defaultMode.rawValue
        }
        lastAppliedLanguage = currentLanguage
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
                    Text(languageStore.localized("practice_subtitle"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .appLabelStyle(minScale: 0.8)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct PracticeStartBar: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let wrongBookCount: Int
    let onStart: () -> Void
    let onWrongBook: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                UnifiedAppButton(
                    title: languageStore.localized("wrong_book_action"),
                    systemImage: "book.closed",
                    style: .outline
                ) {
                    onWrongBook()
                }
                .frame(minWidth: 120)
                .disabled(wrongBookCount == 0)
                .opacity(wrongBookCount == 0 ? 0.6 : 1)

                UnifiedAppButton(
                    title: languageStore.localized("practice_start"),
                    systemImage: "play.fill",
                    style: .primary
                ) {
                    onStart()
                }
                .frame(maxWidth: .infinity)
            }

            if wrongBookCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accentWarm)
                    Text(languageStore.localizedFormat("wrong_book_subtitle", wrongBookCount))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .appLabelStyle(minScale: 0.8)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(AppTheme.surface)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1),
            alignment: .top
        )
        .shadow(color: AppTheme.softShadow, radius: 6, x: 0, y: -2)
    }
}


struct PracticeModeCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Binding var selectedDifficulty: LearningDifficulty
    let difficulties: [LearningDifficulty]
    @Binding var selectedType: PracticeQuestionType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageStore.localized("practice_type_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .appLabelStyle(minScale: 0.8)

            HStack {
                if difficulties.indices.contains(0) {
                    difficultyButton(for: difficulties[0])
                }
                Spacer(minLength: 8)
                if difficulties.indices.contains(1) {
                    difficultyButton(for: difficulties[1])
                }
                Spacer(minLength: 8)
                if difficulties.indices.contains(2) {
                    difficultyButton(for: difficulties[2])
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(PracticeQuestionType.allCases.enumerated()), id: \.element) { index, type in
                            let tint = tintForIndex(index)
                            Button {
                                selectedType = type
                            } label: {
                                PracticeTypeCard(
                                    title: label(for: type),
                                    systemImage: icon(for: type),
                                    tint: tint,
                                    isSelected: selectedType == type
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    private func label(for type: PracticeQuestionType) -> String {
        switch type {
        case .multipleChoice: return languageStore.localized("practice_type_choice")
        case .trueFalse: return languageStore.localized("practice_type_true_false")
        case .matching: return languageStore.localized("practice_type_match")
        case .fillBlank: return languageStore.localized("practice_type_blank")
        case .wordBuild: return languageStore.localized("practice_type_word_build")
        case .translation: return languageStore.localized("practice_type_translate")
        case .listening: return languageStore.localized("practice_type_listening")
        case .sentenceOrder: return languageStore.localized("practice_type_order")
        case .dictation: return languageStore.localized("practice_type_dictation")
        case .shadowing: return languageStore.localized("practice_type_shadowing")
        }
    }

    private func icon(for type: PracticeQuestionType) -> String {
        switch type {
        case .multipleChoice: return "list.bullet.rectangle"
        case .trueFalse: return "checkmark.circle"
        case .matching: return "arrow.left.arrow.right"
        case .fillBlank: return "rectangle.and.pencil.and.ellipsis"
        case .wordBuild: return "square.grid.3x3"
        case .translation: return "character.bubble"
        case .listening: return "ear"
        case .sentenceOrder: return "arrow.up.arrow.down"
        case .dictation: return "mic.fill"
        case .shadowing: return "waveform"
        }
    }

    private func tintForIndex(_ index: Int) -> Color {
        let tints: [Color] = [
            AppTheme.accentStrong,
            AppTheme.accentWarm,
            AppTheme.brandBlue,
            .purple,
            .green,
            Color(red: 0.35, green: 0.34, blue: 0.84)
        ]
        return tints[index % tints.count]
    }

    @ViewBuilder
    private func difficultyButton(for difficulty: LearningDifficulty) -> some View {
        Button {
            selectedDifficulty = difficulty
        } label: {
            Text(languageStore.localized(difficulty.labelKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedDifficulty == difficulty ? .white : AppTheme.textPrimary)
                .appButtonLabelStyle(minScale: 0.7)
                .frame(minWidth: 52)
                .frame(height: 32)
                .padding(.horizontal, 6)
                .background(
                    Capsule().fill(selectedDifficulty == difficulty ? AppTheme.accentStrong : AppTheme.surfaceMuted)
                )
                .overlay(
                    Capsule().stroke(selectedDifficulty == difficulty ? AppTheme.accentStrong : AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PracticeCategorySection: View {
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
                Text(languageStore.localized("practice_category_title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .appLabelStyle(minScale: 0.8)
                Text(languageStore.localizedFormat("practice_category_subtitle", categories.count))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appLabelStyle(minScale: 0.8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(difficulties, id: \.self) { item in
                        Button {
                            selectedDifficulty = item
                        } label: {
                            Text(languageStore.localized(item.labelKey))
                                .font(.caption.weight(selectedDifficulty == item ? .semibold : .medium))
                                .foregroundStyle(selectedDifficulty == item ? .white : AppTheme.textPrimary)
                                .appButtonLabelStyle(minScale: 0.7)
                                .frame(minWidth: 44)
                                .frame(height: 44)
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
                            Text(languageStore.localized("learning_filter_favorites"))
                                .font(.caption.weight(.semibold))
                                .appButtonLabelStyle(minScale: 0.7)
                        }
                        .foregroundStyle(showFavoritesOnly ? AppTheme.accentStrong : AppTheme.textSecondary)
                        .frame(height: 44)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct PracticeChallengeCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Binding var isEnabled: Bool
    @Binding var timeLimit: Int
    let timeOptions: [Int]
    @Binding var comboEnabled: Bool
    @Binding var autoBonusEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(languageStore.localized("practice_challenge_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .appLabelStyle(minScale: 0.8)
                    Text(languageStore.localized("practice_challenge_subtitle"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .appLabelStyle(minScale: 0.8)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(languageStore.localized("practice_challenge_time"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appLabelStyle(minScale: 0.8)
                HStack(spacing: 8) {
                    if timeOptions.indices.contains(0) {
                        timeButton(for: timeOptions[0])
                    }
                    Spacer(minLength: 8)
                    if timeOptions.indices.contains(1) {
                        timeButton(for: timeOptions[1])
                    }
                    Spacer(minLength: 8)
                    if timeOptions.indices.contains(2) {
                        timeButton(for: timeOptions[2])
                    }
                }
            }

            Button {
                comboEnabled.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: comboEnabled ? "flame.fill" : "flame")
                        .foregroundStyle(comboEnabled ? AppTheme.accentWarm : AppTheme.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageStore.localized("practice_challenge_combo"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .appButtonLabelStyle(minScale: 0.7)
                        Text(languageStore.localized("practice_challenge_combo_subtitle"))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .appButtonLabelStyle(minScale: 0.7)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: comboEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(comboEnabled ? AppTheme.accentStrong : AppTheme.textTertiary)
                }
                .frame(height: 44)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.5)
            .disabled(!isEnabled)

            Button {
                autoBonusEnabled.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: autoBonusEnabled ? "sparkles" : "sparkle")
                        .foregroundStyle(autoBonusEnabled ? AppTheme.brandBlue : AppTheme.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageStore.localized("practice_challenge_bonus"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .appButtonLabelStyle(minScale: 0.7)
                        Text(languageStore.localized("practice_challenge_bonus_subtitle"))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .appButtonLabelStyle(minScale: 0.7)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: autoBonusEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(autoBonusEnabled ? AppTheme.accentStrong : AppTheme.textTertiary)
                }
                .frame(height: 44)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.5)
            .disabled(!isEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func timeButton(for option: Int) -> some View {
        Button {
            timeLimit = option
        } label: {
            Text(languageStore.localizedFormat("practice_challenge_seconds", option))
                .font(.caption.weight(.semibold))
                .foregroundStyle(timeLimit == option ? .white : AppTheme.textPrimary)
                .appButtonLabelStyle(minScale: 0.7)
                .frame(minWidth: 52)
                .frame(height: 32)
                .padding(.horizontal, 6)
                .background(
                    Capsule().fill(timeLimit == option ? AppTheme.accentStrong : AppTheme.surfaceMuted)
                )
                .overlay(
                    Capsule().stroke(timeLimit == option ? AppTheme.accentStrong : AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
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
                .appLabelStyle(minScale: 0.8)
            HStack(spacing: 8) {
                ProgressStatCard(title: languageStore.localized("practice_stats_sessions"), value: "\(practiceSessions)", color: AppTheme.accentStrong, icon: "checkmark.seal.fill")
                ProgressStatCard(title: languageStore.localized("practice_stats_accuracy"), value: accuracyText, color: AppTheme.brandBlue, icon: "chart.bar.fill")
                ProgressStatCard(title: languageStore.localized("practice_stats_minutes"), value: "\(learningMinutes)", color: AppTheme.accentWarm, icon: "clock.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .appLabelStyle(minScale: 0.8)
                Text(languageStore.localizedFormat("wrong_book_subtitle", count))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appLabelStyle(minScale: 0.8)
            }
            Spacer(minLength: 0)
            UnifiedAppButton(title: languageStore.localized("wrong_book_action"), systemImage: nil, style: .outline) {
                onReview()
            }
            .frame(minWidth: 90)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.6 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct PracticeTypePill: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

struct PracticeTypeCard: View {
    let title: String
    let systemImage: String
    let tint: Color
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

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .appButtonLabelStyle(minScale: 0.7)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 84)
        .padding(.vertical, 8)
        .background(isSelected ? tint.opacity(0.12) : AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(isSelected ? 0.5 : 0.2), lineWidth: 1)
        )
    }
}

struct PracticeSessionView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var statsStore = LearningStatsStore.shared
    @StateObject private var wrongStore = WrongBookStore.shared
    @StateObject private var dailyStore = DailyTaskStore.shared
    private let speechTranscriber = SpeechTranscriber()

    let mode: LearningMode
    let questionCount: Int
    let types: [PracticeQuestionType]
    let source: PracticeSource
    let sourceItems: [VocabItem]
    let allItems: [VocabItem]
    let difficulty: LearningDifficulty
    let challengeEnabled: Bool
    let timeLimit: Int
    let comboEnabled: Bool
    let autoBonusEnabled: Bool

    @State private var questions: [PracticeQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var answered = false
    @State private var isCorrect = false
    @State private var selectedOption: String? = nil
    @State private var matchSelections: [String: String] = [:]
    @State private var fillBlankText = ""
    @State private var translationText = ""
    @State private var dictationText = ""
    @State private var trueFalseSelection: Bool? = nil
    @State private var orderedWords: [PracticeWordToken] = []
    @State private var availableWords: [PracticeWordToken] = []
    @State private var buildSelection: [PracticeToken] = []
    @State private var buildOptions: [PracticeToken] = []
    @State private var shadowingText = ""
    @State private var shadowingScore: Double? = nil
    @State private var isShadowingRecording = false
    @State private var shadowingError: String? = nil
    @State private var timeRemaining: Int = 0
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0
    @State private var timeBoosts: Int = 0
    @State private var comboBurstValue: Int = 0
    @State private var showComboBurst = false
    @State private var showCorrectPulse = false
    @State private var showWrongShake = false
    @State private var results: [PracticeResultItem] = []
    @State private var startTime = Date()
    @State private var showSummary = false
    @State private var answerDetail = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                    PracticeProgressCard(
                        current: currentIndex + 1,
                        total: questions.count,
                        timeRemaining: challengeEnabled ? timeRemaining : nil,
                        currentStreak: comboEnabled ? currentStreak : nil,
                        bestStreak: comboEnabled ? bestStreak : nil
                    )
                    if challengeEnabled {
                        PracticePowerUpRow(
                            boosts: timeBoosts,
                            isDisabled: answered,
                            onBoost: { applyTimeBoost() }
                        )
                    }
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
        .overlay(alignment: .top) {
            if showComboBurst {
                ComboBurstView(value: comboBurstValue)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 8)
            }
        }
        .alert(languageStore.localized("practice_alert_title"), isPresented: Binding(
            get: { shadowingError != nil },
            set: { if !$0 { shadowingError = nil } }
        )) {
            Button(languageStore.localized("practice_alert_ok"), role: .cancel) {}
        } message: {
            Text(shadowingError ?? "")
        }
        .onAppear {
            loadQuestions()
        }
        .onDisappear {
            if isShadowingRecording {
                speechTranscriber.stopTranscribing()
                isShadowingRecording = false
            }
        }
        .onReceive(timer) { _ in
            guard challengeEnabled, !showSummary, !questions.isEmpty, !answered else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
            if timeRemaining == 0 {
                timeoutCurrentQuestion()
            }
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
        .scaleEffect(showCorrectPulse ? 1.02 : 1.0)
        .offset(x: showWrongShake ? -6 : 0)
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
        case .trueFalse:
            return languageStore.localized("practice_true_false_title")
        case .matching:
            return languageStore.localized("practice_matching_title")
        case .fillBlank:
            return languageStore.localized("practice_fill_blank_title")
        case .wordBuild:
            return languageStore.localized("practice_word_build_title")
        case .translation(let sourceText, _, let targetLanguage):
            if targetLanguage == "zh" {
                return languageStore.localizedFormat("practice_translate_to_zh", sourceText)
            }
            return languageStore.localizedFormat("practice_translate_to_id", sourceText)
        case .listening:
            return languageStore.localized("practice_listening_title")
        case .sentenceOrder:
            return languageStore.localized("practice_sentence_order_title")
        case .dictation:
            return languageStore.localized("practice_dictation_title")
        case .shadowing:
            return languageStore.localized("practice_shadowing_title")
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
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
        case .trueFalse(let sourceText, let candidateText, _, _, _):
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(languageStore.localized("practice_true_false_source"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                        .appLabelStyle(minScale: 0.8)
                    Text(sourceText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(languageStore.localized("practice_true_false_candidate"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                        .appLabelStyle(minScale: 0.8)
                    Text(candidateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                HStack(spacing: 10) {
                    PracticeBinaryButton(
                        title: languageStore.localized("practice_true_false_true"),
                        systemImage: "checkmark.circle.fill",
                        tint: AppTheme.success,
                        isSelected: trueFalseSelection == true
                    ) {
                        trueFalseSelection = true
                    }
                    PracticeBinaryButton(
                        title: languageStore.localized("practice_true_false_false"),
                        systemImage: "xmark.circle.fill",
                        tint: AppTheme.error,
                        isSelected: trueFalseSelection == false
                    ) {
                        trueFalseSelection = false
                    }
                }
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
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
        case .wordBuild(let prompt, let tokens, _, _, _):
            VStack(alignment: .leading, spacing: 10) {
                Text(prompt)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(languageStore.localized("practice_word_build_hint"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appLabelStyle(minScale: 0.8)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(buildOptions) { token in
                        PracticeWordChip(title: token.value, style: .secondary) {
                            if let index = buildOptions.firstIndex(of: token) {
                                buildOptions.remove(at: index)
                                buildSelection.append(token)
                            }
                        }
                    }
                }
                Divider()
                HStack(spacing: 6) {
                    ForEach(buildSelection) { token in
                        Button {
                            if let index = buildSelection.firstIndex(of: token) {
                                buildSelection.remove(at: index)
                                buildOptions.append(token)
                            }
                        } label: {
                            Text(token.value)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .appButtonLabelStyle(minScale: 0.7)
                                .frame(height: 44)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.accentWarm.opacity(0.18))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
            .onAppear {
                if buildOptions.isEmpty {
                    buildOptions = tokens.map { PracticeToken(value: $0) }
                    buildSelection = []
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
                    UnifiedAppButton(title: languageStore.localized("practice_listening_play"), systemImage: "speaker.wave.2", style: .outline) {
                        SpeechService.shared.speak(audioText, language: audioLanguage)
                    }
                    Text(languageStore.localized("practice_listening_hint"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .appLabelStyle(minScale: 0.8)
                }
                ForEach(options, id: \.self) { option in
                    PracticeOptionButton(title: option, isSelected: selectedOption == option) {
                        selectedOption = option
                    }
                }
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
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
                    .appLabelStyle(minScale: 0.8)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(availableWords) { token in
                        PracticeWordChip(title: token.word, style: .secondary) {
                            availableWords.removeAll { $0.id == token.id }
                            orderedWords.append(token)
                        }
                    }
                }
                Divider()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(orderedWords) { token in
                        PracticeWordChip(title: token.word, style: .primary) {
                            orderedWords.removeAll { $0.id == token.id }
                            availableWords.append(token)
                        }
                    }
                }
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
            .onAppear {
                if availableWords.isEmpty {
                    availableWords = words.map { PracticeWordToken(word: $0) }
                    orderedWords = []
                }
            }
        case .dictation(let audioText, _, _, let audioLanguage):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    UnifiedAppButton(title: languageStore.localized("practice_dictation_play"), systemImage: "speaker.wave.2", style: .outline) {
                        SpeechService.shared.speak(audioText, language: audioLanguage)
                    }
                    Text(languageStore.localized("practice_dictation_hint"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .appLabelStyle(minScale: 0.8)
                }
                TextField(languageStore.localized("practice_dictation_placeholder"), text: $dictationText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
            .onAppear {
                SpeechService.shared.speak(audioText, language: audioLanguage)
            }
        case .shadowing(let audioText, let answer, let targetLanguage, let audioLanguage):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    UnifiedAppButton(title: languageStore.localized("practice_shadowing_play"), systemImage: "speaker.wave.2", style: .outline) {
                        SpeechService.shared.speak(audioText, language: audioLanguage)
                    }
                    UnifiedAppButton(
                        title: languageStore.localized(isShadowingRecording ? "practice_shadowing_stop" : "practice_shadowing_record"),
                        systemImage: isShadowingRecording ? "stop.fill" : "mic.fill",
                        style: isShadowingRecording ? .primary : .outline
                    ) {
                        toggleShadowingRecording(answer: answer, audioLanguage: audioLanguage)
                    }
                }
                Text(languageStore.localized("practice_shadowing_hint"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appLabelStyle(minScale: 0.8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(languageStore.localized("practice_shadowing_recognized"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                        .appLabelStyle(minScale: 0.8)
                    Text(shadowingText.isEmpty ? languageStore.localized("practice_shadowing_placeholder") : shadowingText)
                        .font(.subheadline)
                        .foregroundStyle(shadowingText.isEmpty ? AppTheme.textTertiary : AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !shadowingText.isEmpty {
                    ShadowingAlignmentView(
                        expected: answer,
                        recognized: shadowingText,
                        targetLanguage: targetLanguage
                    )
                }

                if let shadowingScore {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(languageStore.localizedFormat("practice_shadowing_score", Int(shadowingScore * 100)))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .appLabelStyle(minScale: 0.8)
                            Spacer()
                            Text(shadowingFeedback(for: shadowingScore))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                                .appLabelStyle(minScale: 0.8)
                        }
                        ProgressView(value: shadowingScore)
                            .tint(shadowingScore >= 0.75 ? AppTheme.success : AppTheme.accentWarm)
                    }
                }

                if answered {
                    PracticeAnswerStateView(isCorrect: isCorrect, detail: answerDetail)
                }
            }
            .onAppear {
                shadowingText = ""
                shadowingScore = nil
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
        case .trueFalse(_, _, let correctText, let answer, _):
            correct = (trueFalseSelection == answer)
            detail = correctText
        case .matching(_, _, let pairs):
            correct = pairs.allSatisfy { pair in
                normalized(matchSelections[pair.left]) == normalized(pair.right)
            }
            detail = matchingDetail(pairs: pairs)
        case .fillBlank(_, let answer):
            correct = normalized(fillBlankText) == normalized(answer)
            detail = answer
        case .wordBuild(_, _, let answer, let separator, _):
            let combined = buildSelection.map(\.value).joined(separator: separator)
            correct = normalized(combined) == normalized(answer)
            detail = answer
        case .translation(_, let answer, _):
            correct = normalized(translationText) == normalized(answer)
            detail = answer
        case .listening(_, _, let answer, _, _):
            correct = normalized(selectedOption) == normalized(answer)
            detail = answer
        case .sentenceOrder(_, let answer, _):
            let combined = orderedWords.map { $0.word }.joined(separator: " ")
            correct = normalized(combined) == normalized(answer)
            detail = answer
        case .dictation(_, let answer, _, _):
            correct = normalized(dictationText) == normalized(answer)
            detail = answer
        case .shadowing(_, let answer, _, _):
            let score = shadowingScore ?? similarityScore(shadowingText, answer)
            correct = score >= 0.75
            detail = "\(answer) · \(languageStore.localizedFormat("practice_shadowing_score", Int(score * 100)))"
        }

        isCorrect = correct
        answered = true
        answerDetail = detail
        results.append(PracticeResultItem(question: question, isCorrect: correct))
        if !correct {
            wrongStore.addWrong(itemId: question.itemId, mode: question.mode, type: question.type)
        }
        applyFeedback(correct: correct)
        applyTimeBonusIfNeeded(correct: correct)
        updateStreak(correct: correct)
    }

    private func goNext() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            resetState()
            answered = false
            isCorrect = false
            resetTimer()
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
        dictationText = ""
        trueFalseSelection = nil
        orderedWords = []
        availableWords = []
        buildSelection = []
        buildOptions = []
        shadowingText = ""
        shadowingScore = nil
        if isShadowingRecording {
            speechTranscriber.stopTranscribing()
            isShadowingRecording = false
        }
        answerDetail = ""
    }

    private func loadQuestions() {
        if source == .wrongBook {
            let wrongItems = wrongStore.items.filter { $0.mode == mode }
            questions = PracticeGenerator.generateQuestions(from: wrongItems, allItems: allItems)
        } else {
            questions = PracticeGenerator.generateQuestions(mode: mode, count: questionCount, types: types, sourceItems: sourceItems, difficulty: difficulty)
        }
        startTime = Date()
        resetState()
        answered = false
        isCorrect = false
        results = []
        showSummary = questions.isEmpty
        currentIndex = 0
        currentStreak = 0
        bestStreak = 0
        timeBoosts = challengeEnabled ? 2 : 0
        resetTimer()
    }

    private func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func matchingDetail(pairs: [PracticeMatchPair]) -> String {
        pairs.map { "\($0.left) → \($0.right)" }.joined(separator: " · ")
    }

    private func resetTimer() {
        timeRemaining = challengeEnabled ? timeLimit : 0
    }

    private func timeoutCurrentQuestion() {
        guard !answered, currentIndex < questions.count else { return }
        let question = questions[currentIndex]
        isCorrect = false
        answered = true
        let detail = correctAnswerDetail(for: question)
        answerDetail = "\(languageStore.localized("practice_timeout")) · \(detail)"
        results.append(PracticeResultItem(question: question, isCorrect: false))
        wrongStore.addWrong(itemId: question.itemId, mode: question.mode, type: question.type)
        applyFeedback(correct: false)
        updateStreak(correct: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if !showSummary {
                goNext()
            }
        }
    }

    private func correctAnswerDetail(for question: PracticeQuestion) -> String {
        switch question.payload {
        case .multipleChoice(_, _, let answer, _):
            return answer
        case .trueFalse(_, _, let correctText, _, _):
            return correctText
        case .matching(_, _, let pairs):
            return matchingDetail(pairs: pairs)
        case .fillBlank(_, let answer):
            return answer
        case .wordBuild(_, _, let answer, _, _):
            return answer
        case .translation(_, let answer, _):
            return answer
        case .listening(_, _, let answer, _, _):
            return answer
        case .sentenceOrder(_, let answer, _):
            return answer
        case .dictation(_, let answer, _, _):
            return answer
        case .shadowing(_, let answer, _, _):
            return answer
        }
    }

    private func updateStreak(correct: Bool) {
        guard comboEnabled else { return }
        if correct {
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            if currentStreak >= 2 {
                comboBurstValue = currentStreak
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showComboBurst = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showComboBurst = false
                    }
                }
            }
        } else {
            currentStreak = 0
        }
    }

    private func applyTimeBonusIfNeeded(correct: Bool) {
        guard challengeEnabled, autoBonusEnabled, correct else { return }
        let bonus = 3
        timeRemaining = min(timeRemaining + bonus, timeLimit + 5)
    }

    private func applyTimeBoost() {
        guard challengeEnabled, timeBoosts > 0 else { return }
        timeBoosts -= 1
        timeRemaining = min(timeRemaining + 5, timeLimit + 10)
        HapticFeedback.light()
        playFeedbackSound(.boost)
    }

    private func applyFeedback(correct: Bool) {
        if correct {
            HapticFeedback.success()
            playFeedbackSound(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCorrectPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCorrectPulse = false
                }
            }
        } else {
            HapticFeedback.error()
            playFeedbackSound(.error)
            withAnimation(.easeInOut(duration: 0.08)) {
                showWrongShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) {
                    showWrongShake = false
                }
            }
        }
    }

    private func playFeedbackSound(_ type: PracticeFeedbackSound) {
        guard !SpeechSettingsStore.shared.playbackMuted else { return }
        AudioServicesPlaySystemSound(type.soundId)
    }

    private func toggleShadowingRecording(answer: String, audioLanguage: String) {
        if isShadowingRecording {
            speechTranscriber.stopTranscribing()
            isShadowingRecording = false
            shadowingScore = similarityScore(shadowingText, answer)
            return
        }

        Task {
            let granted = await speechTranscriber.requestAuthorization()
            if !granted {
                await MainActor.run { shadowingError = languageStore.localized("practice_speech_permission_denied") }
                return
            }
            await MainActor.run {
                shadowingText = ""
                shadowingScore = nil
                isShadowingRecording = true
            }
            do {
                try speechTranscriber.startTranscribing(locale: Locale(identifier: audioLanguage)) { text, isFinal in
                    Task { @MainActor in
                        if !text.isEmpty {
                            shadowingText = text
                        }
                        if isFinal {
                            isShadowingRecording = false
                            shadowingScore = similarityScore(shadowingText, answer)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isShadowingRecording = false
                    shadowingError = languageStore.localizedFormat("practice_speech_failed", error.localizedDescription)
                }
            }
        }
    }

    private func similarityScore(_ source: String, _ target: String) -> Double {
        let a = normalizeForSimilarity(source)
        let b = normalizeForSimilarity(target)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let distance = levenshteinDistance(a, b)
        let maxLen = max(a.count, b.count)
        if maxLen == 0 { return 0 }
        return max(0, 1.0 - Double(distance) / Double(maxLen))
    }

    private func normalizeForSimilarity(_ text: String) -> [Character] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let filtered = lowered.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
        return Array(filtered.filter { !$0.isWhitespace })
    }

    private func levenshteinDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var costs = Array(0...b.count)
        for i in 1...a.count {
            var last = i - 1
            costs[0] = i
            for j in 1...b.count {
                let newLast = costs[j]
                if a[i - 1] == b[j - 1] {
                    costs[j] = last
                } else {
                    costs[j] = min(last, costs[j - 1], costs[j]) + 1
                }
                last = newLast
            }
        }
        return costs[b.count]
    }

    private func shadowingFeedback(for score: Double) -> String {
        if score >= 0.9 { return languageStore.localized("practice_shadowing_feedback_great") }
        if score >= 0.75 { return languageStore.localized("practice_shadowing_feedback_good") }
        if score >= 0.6 { return languageStore.localized("practice_shadowing_feedback_ok") }
        return languageStore.localized("practice_shadowing_feedback_retry")
    }
}

struct PracticeProgressCard: View {
    let current: Int
    let total: Int
    let timeRemaining: Int?
    let currentStreak: Int?
    let bestStreak: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(current)/\(total)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    if let timeRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text("\(timeRemaining)s")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(timeRemaining <= 5 ? AppTheme.error : AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(Capsule())
                    }
                    if let currentStreak, let bestStreak {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.accentWarm)
                            Text("\(currentStreak)")
                                .font(.caption2.weight(.semibold))
                            Text("/\(bestStreak)")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(Capsule())
                    }
                }
            }
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
                    .appButtonLabelStyle(minScale: 0.7)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accentStrong)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(12)
            .background(isSelected ? AppTheme.accentStrong.opacity(0.12) : AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PracticeBinaryButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .appButtonLabelStyle(minScale: 0.7)
            }
            .foregroundStyle(isSelected ? .white : tint)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? tint : tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(isSelected ? 0.8 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PracticePowerUpRow: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let boosts: Int
    let isDisabled: Bool
    let onBoost: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(languageStore.localized("practice_powerup_title"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .appLabelStyle(minScale: 0.8)
            Spacer(minLength: 0)
            Button(action: onBoost) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text(languageStore.localizedFormat("practice_powerup_time", boosts))
                        .font(.caption.weight(.semibold))
                        .appButtonLabelStyle(minScale: 0.7)
                }
                .foregroundStyle(boosts > 0 ? AppTheme.brandBlue : AppTheme.textTertiary)
                .frame(height: 44)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.surfaceMuted)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(boosts == 0 || isDisabled)
            .opacity((boosts == 0 || isDisabled) ? 0.5 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}

struct ComboBurstView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(AppTheme.accentWarm)
            Text("+\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .appLabelStyle(minScale: 0.8)
            Text(languageStore.localized("practice_combo"))
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .appLabelStyle(minScale: 0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.surface)
        .clipShape(Capsule())
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct ShadowingAlignmentView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    let expected: String
    let recognized: String
    let targetLanguage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(languageStore.localized("practice_shadowing_align_title"))
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
            let tokens = alignedTokens(expected: expected, recognized: recognized, targetLanguage: targetLanguage)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
                ForEach(tokens) { token in
                    Text(token.value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(token.isMatch ? AppTheme.success : AppTheme.error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((token.isMatch ? AppTheme.success : AppTheme.error).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func alignedTokens(expected: String, recognized: String, targetLanguage: String) -> [ShadowingToken] {
        let expectedTokens = tokenize(text: expected, targetLanguage: targetLanguage)
        let recognizedTokens = tokenize(text: recognized, targetLanguage: targetLanguage)
        var result: [ShadowingToken] = []
        for (index, token) in expectedTokens.enumerated() {
            let normalized = token.lowercased()
            let match = index < recognizedTokens.count && normalized == recognizedTokens[index].lowercased()
            result.append(ShadowingToken(value: token, isMatch: match))
        }
        return result
    }

    private func tokenize(text: String, targetLanguage: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if targetLanguage == "zh" {
            return trimmed.map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return trimmed.split(separator: " ").map(String.init)
    }
}

struct ShadowingToken: Identifiable {
    let id = UUID()
    let value: String
    let isMatch: Bool
}

enum PracticeFeedbackSound {
    case success
    case error
    case boost

    var soundId: SystemSoundID {
        switch self {
        case .success:
            return 1104
        case .error:
            return 1103
        case .boost:
            return 1057
        }
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
                .appButtonLabelStyle(minScale: 0.7)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(style == .primary ? AppTheme.accentWarm.opacity(0.18) : AppTheme.surfaceMuted)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PracticeWordToken: Identifiable, Hashable {
    let id: String
    let word: String

    init(id: String = UUID().uuidString, word: String) {
        self.id = id
        self.word = word
    }
}

struct PracticeToken: Identifiable, Hashable {
    let id: UUID
    let value: String

    init(value: String) {
        self.id = UUID()
        self.value = value
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
                .appLabelStyle(minScale: 0.8)
            if !isCorrect {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appLabelStyle(minScale: 0.8)
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
                .appLabelStyle(minScale: 0.8)
            Text("\(results.filter { $0.isCorrect }.count) / \(results.count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.accentStrong)

            VStack(alignment: .leading, spacing: 8) {
                Text(languageStore.localized("practice_result_correct"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .appLabelStyle(minScale: 0.8)
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
                    .appLabelStyle(minScale: 0.8)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .trueFalse(let sourceText, _, _, _, _):
            return sourceText
        case .matching(let left, _, _):
            return left.joined(separator: ", ")
        case .fillBlank(let prompt, _):
            return prompt
        case .wordBuild(let prompt, _, _, _, _):
            return prompt
        case .translation(let sourceText, _, _):
            return sourceText
        case .listening(let audioText, _, _, _, _):
            return audioText
        case .sentenceOrder(_, let answer, _):
            return answer
        case .dictation(let audioText, _, _, _):
            return audioText
        case .shadowing(let audioText, _, _, _):
            return audioText
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
                .appLabelStyle(minScale: 0.8)
            Text(languageStore.localized("practice_empty_subtitle"))
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .appLabelStyle(minScale: 0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}
