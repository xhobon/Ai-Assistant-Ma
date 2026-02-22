import SwiftUI
#if os(macOS)
import AppKit
#endif

struct IndonesianLearningView: View {
    @StateObject private var viewModel = LearningViewModel()
    @State private var searchText = ""
    @State private var selectedDifficulty = "全部"
    @State private var showFavoritesOnly = false

    private let difficulties = ["全部", "入门", "进阶", "高级"]

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

                    LearningInsightCard(
                        title: "今日目标",
                        subtitle: "完成 15 个高频词 + 3 句口语",
                        detail: "连续学习 5 天可解锁进阶场景"
                    )
                    .padding(.horizontal, horizontalPadding)

                    LearningOverviewRow()
                        .padding(.horizontal, horizontalPadding)

                    LearningResourceSection(
                        categories: viewModel.categories,
                        selectedCategoryId: $viewModel.selectedCategoryId
                    )
                    .padding(.horizontal, horizontalPadding)

                    VocabularyListSection(
                        items: filteredItems,
                        viewModel: viewModel,
                        difficultyProvider: difficultyForItem
                    )
                    .padding(.horizontal, horizontalPadding)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.automatic)
            .background(
                AppTheme.pageBackground
                    .ignoresSafeArea(edges: .top)
            )
            .hideNavigationBarOnMac()
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
        VStack(spacing: 10) {
            SearchBar(text: $searchText)
            FilterRow(
                difficulties: difficulties,
                selected: $selectedDifficulty,
                showFavoritesOnly: $showFavoritesOnly
            )
            HStack {
                Text("筛选：\(selectedDifficulty)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer(minLength: 0)
                Button {
                    searchText = ""
                    selectedDifficulty = "全部"
                    showFavoritesOnly = false
                } label: {
                    Text("重置")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
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
    var body: some View {
        VStack(spacing: 10) {
            LearningProgressCard()
            TodayPlanCard()
        }
    }
}

struct LearningResourceSection: View {
    let categories: [VocabCategory]
    @Binding var selectedCategoryId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("学习主题")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("按主题浏览高频词汇与场景")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Text("共 \(categories.count) 类")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("学习进度")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 8) {
                ProgressStatCard(title: "完成", value: "8/20", color: AppTheme.accentStrong, icon: "checkmark.seal.fill")
                ProgressStatCard(title: "坚持", value: "5 天", color: AppTheme.brandBlue, icon: "flame.fill")
                ProgressStatCard(title: "掌握", value: "126", color: AppTheme.accentWarm, icon: "bookmark.fill")
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

                HStack(spacing: 8) {
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
                ExampleSentenceRow(title: "中文例句", text: item.exampleZh, language: "zh-CN")
                ExampleSentenceRow(title: "印尼语例句", text: item.exampleId, language: "id-ID")
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
    let title: String
    let text: String
    let language: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            Button {
                SpeechService.shared.speak(text, language: language)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentWarm)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accentWarm.opacity(0.12))
                    .clipShape(Circle())
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
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.unifiedButtonBorder)
                .frame(width: 36, height: 36)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
