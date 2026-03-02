import SwiftUI

// MARK: - 写作
struct WritingStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var topic = ""
    @State private var keywords = ""
    @State private var style = "通用"
    @State private var tone = "专业"
    @State private var length = "中等"
    @State private var draft = ""
    @State private var drafts: [WritingDraft] = []

    private let styles = ["通用", "营销文案", "工作汇报", "演讲稿", "产品介绍"]
    private let tones = ["专业", "温暖", "简洁", "鼓舞", "正式", "学术"]
    private let lengths = ["短", "中等", "长"]
    private let presets = ["外卖好评神器", "小红书爆款", "模拟面试提问", "社媒文案撰写", "新人部门发言稿", "大学实习自我介绍"]
    @State private var selectedTab = "热门"
    @State private var selectedQuickActionID: String = "polish"
    private let topTabs = ["热门", "职场办公", "社媒营销", "文学创作", "生活场景"]
    private let quickActions: [WritingQuickActionItem] = [
        WritingQuickActionItem(id: "polish", title: "润色", icon: "wand.and.stars", keywords: "润色,表达优化", style: "通用", tone: "专业", length: "中等"),
        WritingQuickActionItem(id: "expand", title: "扩写", icon: "text.badge.plus", keywords: "扩写,细节补充", style: "通用", tone: "温暖", length: "长"),
        WritingQuickActionItem(id: "imitate", title: "仿写", icon: "doc.on.doc", keywords: "仿写,风格对齐", style: "营销文案", tone: "正式", length: "中等"),
        WritingQuickActionItem(id: "continue", title: "续写", icon: "text.append", keywords: "续写,承接上下文", style: "通用", tone: "简洁", length: "长"),
        WritingQuickActionItem(id: "review", title: "作文批改", icon: "checkmark.bubble", keywords: "作文批改,错因分析", style: "工作汇报", tone: "学术", length: "中等")
    ]
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        AppPageScaffold(maxWidth: pageMaxWidth, horizontalPadding: 16, topPadding: 10, bottomPadding: 24, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(AppTheme.TopBar.backIconFont)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: AppTheme.TopBar.backButtonSize, height: AppTheme.TopBar.backButtonSize)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .frame(width: AppTheme.TopBar.sideSlotWidth, alignment: .leading)

                    Color.clear
                        .frame(width: AppTheme.TopBar.sideSlotWidth, height: AppTheme.TopBar.backButtonSize)
                }
                .overlay {
                    Text("AI写作")
                        .font(AppTheme.TopBar.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(height: AppTheme.TopBar.height)

                HStack(spacing: 10) {
                    writingTopCard("文案创作", "生活灵感/爆款文案", "doc.text.fill", Color(red: 0.84, green: 0.93, blue: 1.0))
                    writingTopCard("作文写作", "写作思路论点论据", "doc.plaintext.fill", Color(red: 0.99, green: 0.91, blue: 0.84))
                    writingTopCard("长文写作", "分步式万字长文", "book.closed.fill", Color(red: 0.90, green: 0.88, blue: 0.98))
                }

                quickActionStrip

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(topTabs, id: \.self) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                Text(tab)
                                    .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                                    .foregroundStyle(selectedTab == tab ? AppTheme.textPrimary : AppTheme.textSecondary)
                                    .overlay(alignment: .bottom) {
                                        if selectedTab == tab {
                                            Capsule()
                                                .fill(AppTheme.primary)
                                                .frame(height: 3)
                                                .offset(y: 8)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        topic = preset
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                            Text(preset)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 10) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft)
                        .font(.system(size: 16))
                        .frame(minHeight: 132)
                        .padding(10)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )

                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("输入想要的创作内容")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.inputPlaceholder)
                            .padding(.leading, 22)
                            .padding(.top, 20)
                    }
                }

                HStack(spacing: 10) {
                    miniChipInput("上传素材", "arrow.up.doc")
                    Spacer()
                    Button {
                        generateDraft()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.subheadline.weight(.bold))
                            Text("AI生成")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(AppTheme.unifiedButtonPrimary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            SectionCard {
                VStack(spacing: 10) {
                    HStack {
                        Text("草稿箱")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Button("保存当前草稿") {
                            let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !cleaned.isEmpty else { return }
                            drafts.insert(
                                WritingDraft(
                                    title: topic.isEmpty ? "未命名主题" : topic,
                                    content: cleaned,
                                    style: style,
                                    tone: tone,
                                    length: length,
                                    createdAt: Date()
                                ),
                                at: 0
                            )
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }

                    if drafts.isEmpty {
                        EmptyStateRow(text: "还没有保存草稿")
                    } else {
                        ForEach(drafts.prefix(4)) { item in
                            DraftRow(draft: item) {
                                draft = item.content
                                topic = item.title
                                style = item.style
                                tone = item.tone
                                length = item.length
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func writingTopCard(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var quickActionStrip: some View {
        HStack(spacing: 8) {
            ForEach(quickActions) { item in
                Button {
                    selectedQuickActionID = item.id
                    applyQuickAction(item)
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(selectedQuickActionID == item.id ? AppTheme.primary.opacity(0.18) : AppTheme.surfaceMuted)
                                .frame(width: 34, height: 34)
                            Image(systemName: item.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selectedQuickActionID == item.id ? AppTheme.primary : AppTheme.textSecondary)
                        }
                        Text(item.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedQuickActionID == item.id ? AppTheme.surface : AppTheme.surfaceMuted.opacity(0.88))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selectedQuickActionID == item.id ? AppTheme.primary.opacity(0.35) : AppTheme.border.opacity(0.65), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    private func applyQuickAction(_ item: WritingQuickActionItem) {
        keywords = item.keywords
        style = item.style
        tone = item.tone
        length = item.length
    }

    private func generateDraft() {
        let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = WritingGenerator.generate(
            topic: topic.isEmpty ? cleaned : topic,
            keywords: keywords,
            style: style,
            tone: tone,
            length: length
        )
    }

    private func miniChipInput(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct WritingQuickActionItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let keywords: String
    let style: String
    let tone: String
    let length: String
}

// MARK: - PPT
struct PPTStudioView: View {
    @State private var topic = ""
    @State private var audience = ""
    @State private var slideCount = 10
    @State private var style = "商务"
    @State private var outlines: [SlideOutline] = []

    private let styles = ["商务", "科技", "教育", "营销", "极简"]
    @State private var tab = "论文"
    private let bottomTabs = ["论文", "PPT模板", "求职简历", "心得体会", "更多"]
    private let templateEntries: [TemplateEntry] = [
        TemplateEntry(title: "文档转PPT", subtitle: "生成高级排版", icon: "doc.text", tint: Color(red: 0.93, green: 0.97, blue: 1.0)),
        TemplateEntry(title: "课程报告", subtitle: "教学场景生成", icon: "graduationcap", tint: Color(red: 0.95, green: 0.97, blue: 1.0)),
        TemplateEntry(title: "活动策划", subtitle: "方案结构输出", icon: "calendar", tint: Color(red: 0.95, green: 0.98, blue: 0.97)),
        TemplateEntry(title: "图片生成", subtitle: "图文组合提案", icon: "photo", tint: Color(red: 0.95, green: 0.96, blue: 1.0)),
        TemplateEntry(title: "改写润色", subtitle: "语义优化表达", icon: "wand.and.stars", tint: Color(red: 0.97, green: 0.95, blue: 1.0)),
        TemplateEntry(title: "有奖招募", subtitle: "活动文案模板", icon: "megaphone", tint: Color(red: 0.98, green: 0.96, blue: 0.94))
    ]

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        AppPageScaffold(maxWidth: 780, horizontalPadding: 16, topPadding: 10, bottomPadding: 24, spacing: 14) {
            heroCard

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(templateEntries) { item in
                    Button {
                        topic = item.title
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(item.subtitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: item.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.86))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                        .background(item.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(bottomTabs, id: \.self) { item in
                        Button {
                            tab = item
                        } label: {
                            Text(item)
                                .font(.subheadline.weight(tab == item ? .semibold : .medium))
                                .foregroundStyle(tab == item ? AppTheme.textPrimary : AppTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(tab == item ? AppTheme.surface : AppTheme.surfaceMuted)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(tab == item ? AppTheme.primary.opacity(0.35) : AppTheme.border.opacity(0.6), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            SectionCard {
                VStack(spacing: 12) {
                    HStack {
                        Text("大纲预览")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Button("复制大纲") {
                            ClipboardService.copy(outlines.map(\.text).joined(separator: "\n"))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .disabled(outlines.isEmpty)
                    }

                    if outlines.isEmpty {
                        EmptyStateRow(text: "点击上方“立即写作”后展示大纲")
                    } else {
                        ForEach(outlines.prefix(6)) { outline in
                            SlideOutlineRow(outline: outline)
                        }
                    }

                    HStack(spacing: 10) {
                        LabeledField(title: "主题", placeholder: "例如：AI 助理产品路演", text: $topic)
                        LabeledField(title: "受众", placeholder: "例如：管理层/客户/团队成员", text: $audience)
                    }

                    HStack {
                        Text("页数")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Stepper(value: $slideCount, in: 6...20) {
                            Text("\(slideCount) 页")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .fixedSize()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    ChipPicker(title: "风格", options: styles, selection: $style)
                }
            }
        }
        .navigationTitle("AI工具")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI写长文")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("单篇可生成 1.5 万字 + 参考文献")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                outlines = PPTGenerator.generate(topic: topic, audience: audience, slideCount: slideCount, style: style)
            } label: {
                Text("立即写作")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.80, green: 0.88, blue: 1.0),
                            Color(red: 0.84, green: 0.90, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
        )
    }

    private struct TemplateEntry: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
    }
}

// MARK: - 笔记
struct NotesWorkspaceView: View {
    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var searchText = ""
    @State private var isRecording = false
    @State private var notes: [NoteEntry] = []

    var body: some View {
        AppPageScaffold(maxWidth: 960) {
            ProductivityHeader(
                title: "笔记中心",
                subtitle: "随手记录，支持标签与快速检索",
                systemImage: "note.text",
                tint: AppTheme.accentWarm
            )

            SectionCard {
                VStack(spacing: 12) {
                    LabeledField(title: "标题", placeholder: "例如：会议纪要 / 读书笔记", text: $title)
                    TextEditorField(title: "内容", placeholder: "支持粘贴、语音转写或手动输入", text: $content, minHeight: 160)
                    LabeledField(title: "标签（用逗号分隔）", placeholder: "例如：工作,学习,重要", text: $tags)
                    HStack(spacing: 12) {
                        ProductivityActionButton(isRecording ? "转写中" : "语音转写", systemImage: "mic.fill", style: .outline) {
                            isRecording.toggle()
                        }
                        ProductivityActionButton("保存笔记", systemImage: "tray.and.arrow.down", style: .filled) {
                            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            notes.insert(
                                NoteEntry(
                                    title: title.isEmpty ? "未命名笔记" : title,
                                    content: content,
                                    tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                                    createdAt: Date()
                                ),
                                at: 0
                            )
                            title = ""
                            content = ""
                            tags = ""
                        }
                    }
                }
            }

            SectionCard {
                VStack(spacing: 12) {
                    LabeledField(title: "快速搜索", placeholder: "输入关键字/标签", text: $searchText)
                    if filteredNotes.isEmpty {
                        EmptyStateRow(text: "暂无笔记记录")
                    } else {
                        ForEach(filteredNotes) { note in
                            NoteRow(note: note)
                        }
                    }
                }
            }
        }
        .navigationTitle("笔记中心")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredNotes: [NoteEntry] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return notes }
        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(keyword)
            || note.content.localizedCaseInsensitiveContains(keyword)
            || note.tags.contains(where: { $0.localizedCaseInsensitiveContains(keyword) })
        }
    }
}

// MARK: - 总结
struct SummaryWorkspaceView: View {
    @State private var sourceText = ""
    @State private var mode = "要点"
    @State private var length = "中等"
    @State private var result = ""

    private let modes = ["要点", "行动项", "一句话", "结构化"]
    private let lengths = ["短", "中等", "长"]
    private var wordCount: Int {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count
    }
    private var isSourceEmpty: Bool {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var isResultEmpty: Bool {
        result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        AppPageScaffold(maxWidth: 780, horizontalPadding: 16, topPadding: 10, bottomPadding: 24, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentPurple.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("内容总结")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("输入长文本或会议记录，快速提炼重点")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("原始内容")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $sourceText)
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.inputText)
                            .frame(minHeight: 220)
                            .padding(12)
                            .background(AppTheme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.border.opacity(0.7), lineWidth: 1)
                            )

                        if sourceText.isEmpty {
                            Text("粘贴需要总结的内容")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.inputPlaceholder)
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                        }
                    }

                    HStack {
                        Text("已输入 \(wordCount) 字")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("总结方式")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        summaryOptionChips(options: modes, selection: $mode)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("长度")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        summaryOptionChips(options: lengths, selection: $length)
                    }

                    HStack(spacing: 10) {
                        summaryActionButton(title: "生成总结", systemImage: "bolt.fill", style: .filled) {
                            result = SummaryGenerator.generate(text: sourceText, mode: mode, length: length)
                        }
                        .disabled(isSourceEmpty)

                        summaryActionButton(title: "复制", systemImage: "doc.on.doc", style: .outline) {
                            ClipboardService.copy(result)
                        }
                        .disabled(isResultEmpty)

                        summaryActionButton(title: "清空", systemImage: "trash", style: .ghost) {
                            sourceText = ""
                            result = ""
                        }
                    }
                }
            }

            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("总结结果")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        if !isResultEmpty {
                            Button("复制结果") {
                                ClipboardService.copy(result)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .buttonStyle(.plain)
                        }
                    }

                    if isResultEmpty {
                        EmptyStateRow(text: "生成后显示总结内容")
                    } else {
                        Text(result)
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppTheme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .navigationTitle("内容总结")
        .navigationBarTitleDisplayMode(.inline)
    }

    private enum SummaryButtonStyle {
        case filled
        case outline
        case ghost
    }

    @ViewBuilder
    private func summaryActionButton(
        title: String,
        systemImage: String,
        style: SummaryButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        let foreground: Color = (style == .filled) ? .white : AppTheme.unifiedButtonBorder
        let background: AnyShapeStyle = (style == .filled) ? AnyShapeStyle(AppTheme.unifiedButtonPrimary) : AnyShapeStyle(AppTheme.surface)

        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style == .filled ? Color.clear : AppTheme.unifiedButtonBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func summaryOptionChips(options: [String], selection: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text(option)
                            .font(.system(size: 15, weight: selection.wrappedValue == option ? .semibold : .medium))
                            .foregroundStyle(selection.wrappedValue == option ? AppTheme.textPrimary : AppTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selection.wrappedValue == option ? AppTheme.accent.opacity(0.18) : AppTheme.surfaceMuted)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selection.wrappedValue == option ? AppTheme.primary.opacity(0.35) : AppTheme.border.opacity(0.6), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 组件
private struct ProductivityHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 4)
    }
}

private struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 6, x: 0, y: 3)
    }
}

private struct SectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

private struct LabeledField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct TextEditorField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .foregroundStyle(AppTheme.inputText)
                    .padding(8)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                if text.isEmpty {
                    Text(placeholder)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.inputPlaceholder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
            }
        }
    }
}

private struct ChipPicker: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                        } label: {
                            Text(option)
                                .font(.caption.weight(selection == option ? .semibold : .regular))
                                .foregroundStyle(selection == option ? AppTheme.textPrimary : AppTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selection == option ? AppTheme.accent.opacity(0.15) : AppTheme.surfaceMuted)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct QuickChips: View {
    let title: String
    let options: [String]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            Text(option)
                                .font(.caption)
                                .foregroundStyle(AppTheme.accentStrong)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.accentStrong.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct EmptyStateRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(AppTheme.textTertiary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProductivityActionButton: View {
    enum Style {
        case filled
        case outline
        case ghost
    }

    let title: String
    let systemImage: String?
    let style: Style
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, style: Style = .filled, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.callout.weight(.semibold))
                }
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(border)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        switch style {
        case .filled:
            return AnyView(AppTheme.unifiedButtonPrimary)
        case .outline, .ghost:
            return AnyView(AppTheme.surface)
        }
    }

    private var foreground: Color {
        switch style {
        case .filled:
            return .white
        case .outline, .ghost:
            return AppTheme.unifiedButtonBorder
        }
    }

    private var border: some View {
        switch style {
        case .outline, .ghost:
            return AnyView(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.unifiedButtonBorder, lineWidth: 1)
            )
        case .filled:
            return AnyView(EmptyView())
        }
    }
}

private struct DraftRow: View {
    let draft: WritingDraft
    var onLoad: () -> Void

    var body: some View {
        Button(action: onLoad) {
            VStack(alignment: .leading, spacing: 6) {
                Text(draft.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("风格：\(draft.style) · 语气：\(draft.tone) · 篇幅：\(draft.length)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(draft.content)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SlideOutlineRow: View {
    let outline: SlideOutline

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(outline.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(outline.bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(bullet)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct NoteRow: View {
    let note: NoteEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Text(note.dateText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Text(note.content)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(3)
            if !note.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accentStrong)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentStrong.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - 数据模型
private struct WritingDraft: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let style: String
    let tone: String
    let length: String
    let createdAt: Date
}

private struct SlideOutline: Identifiable {
    let id = UUID()
    let title: String
    let bullets: [String]

    var text: String {
        ([title] + bullets.map { "• \($0)" }).joined(separator: "\n")
    }
}

private struct NoteEntry: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let tags: [String]
    let createdAt: Date

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: createdAt)
    }
}

// MARK: - 生成逻辑
private enum WritingGenerator {
    static func generate(topic: String, keywords: String, style: String, tone: String, length: String) -> String {
        let title = topic.isEmpty ? "未命名主题" : topic
        let keywordsText = keywords.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyLine = keywordsText.isEmpty ? "关键词：无" : "关键词：\(keywordsText)"
        let detailCount: Int = length == "长" ? 4 : (length == "短" ? 2 : 3)
        let bullets = (1...detailCount).map { "核心要点 \($0)：围绕 \(title) 的价值与亮点展开描述。" }
        return """
        标题：\(title)
        风格：\(style) · 语气：\(tone) · 篇幅：\(length)
        \(keyLine)

        开头：用一句清晰有力的引言引出主题，强调核心价值。
        \(bullets.joined(separator: "\n"))

        结尾：提出行动建议或下一步，引导读者继续了解。
        """
    }
}

private enum PPTGenerator {
    static func generate(topic: String, audience: String, slideCount: Int, style: String) -> [SlideOutline] {
        let baseTopic = topic.isEmpty ? "未命名主题" : topic
        let audienceText = audience.isEmpty ? "通用受众" : audience
        let coreSlides = max(6, slideCount)
        let titles = [
            "封面：\(baseTopic)",
            "目录",
            "背景与机会",
            "核心方案",
            "关键价值",
            "实施路径",
            "风险与对策",
            "里程碑与计划",
            "资源与预算",
            "总结与行动"
        ]
        return (0..<coreSlides).map { index in
            let title = titles[index % titles.count]
            return SlideOutline(
                title: title,
                bullets: [
                    "面向 \(audienceText) 的关键观点",
                    "结合 \(style) 风格的内容组织",
                    "数据与案例支持（可选）"
                ]
            )
        }
    }
}

private enum SummaryGenerator {
    static func generate(text: String, mode: String, length: String) -> String {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return "请先输入需要总结的内容。" }
        let header = "总结方式：\(mode) · 长度：\(length)"
        switch mode {
        case "行动项":
            return """
            \(header)
            1. 明确下一步行动与负责人。
            2. 标记关键风险与依赖事项。
            3. 设定时间节点与复盘方式。
            """
        case "一句话":
            return "\(header)\n一句话总结：内容核心是聚焦目标、优化方法并明确落地路径。"
        case "结构化":
            return """
            \(header)
            背景：说明当前问题与机会。
            重点：聚焦 3-5 个关键结论。
            建议：给出可执行的行动与节奏。
            """
        default:
            return """
            \(header)
            - 提炼核心结论与关键数据点。
            - 梳理影响范围与主要挑战。
            - 给出下一步建议与可行方案。
            """
        }
    }
}
