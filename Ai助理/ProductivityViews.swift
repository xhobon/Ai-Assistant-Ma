import SwiftUI

// MARK: - 写作
struct WritingStudioView: View {
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
    private let topTabs = ["热门", "职场办公", "社媒营销", "文学创作", "生活场景"]
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("AI写作")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    HStack(spacing: 10) {
                        writingTopCard("文案创作", "生活灵感/爆款文案", "doc.text.fill", Color(red: 0.84, green: 0.93, blue: 1.0))
                        writingTopCard("作文写作", "写作思路论点论据", "doc.plaintext.fill", Color(red: 0.99, green: 0.91, blue: 0.84))
                        writingTopCard("长文写作", "分步式万字长文", "book.closed.fill", Color(red: 0.90, green: 0.88, blue: 0.98))
                    }

                    HStack(spacing: 12) {
                        quickAction("润色", "line.3.horizontal.decrease")
                        quickAction("扩写", "square.and.pencil")
                        quickAction("仿写", "line.3.horizontal")
                        quickAction("续写", "film")
                        quickAction("作文批改", "doc.text.magnifyingglass")
                    }
                    .padding(.top, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(topTabs, id: \.self) { tab in
                                Button {
                                    selectedTab = tab
                                } label: {
                                    Text(tab)
                                        .font(.system(size: 22, weight: selectedTab == tab ? .bold : .medium))
                                        .foregroundStyle(selectedTab == tab ? AppTheme.textPrimary : AppTheme.textSecondary)
                                        .overlay(alignment: .bottom) {
                                            if selectedTab == tab {
                                                Capsule()
                                                    .fill(AppTheme.primary)
                                                    .frame(height: 3)
                                                    .offset(y: 9)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            topic = preset
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primary)
                                Text(preset)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 10) {
                    TextEditor(text: $draft)
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .onAppear {
                            if draft.isEmpty { draft = "输入想要的创作内容" }
                        }

                    HStack(spacing: 10) {
                        miniChipInput("上传素材", "arrow.up.doc")
                        Spacer()
                        Button {
                            let cleaned = draft == "输入想要的创作内容" ? "" : draft
                            draft = WritingGenerator.generate(
                                topic: topic.isEmpty ? cleaned : topic,
                                keywords: keywords,
                                style: style,
                                tone: tone,
                                length: length
                            )
                        } label: {
                            Image(systemName: "waveform.circle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }
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
                                let cleaned = draft == "输入想要的创作内容" ? "" : draft
                                guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
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
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: pageMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func writingTopCard(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func quickAction(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption)
        }
        .foregroundStyle(AppTheme.textPrimary)
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

// MARK: - PPT
struct PPTStudioView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var topic = ""
    @State private var audience = ""
    @State private var slideCount = 10
    @State private var style = "商务"
    @State private var outlines: [SlideOutline] = []

    private let styles = ["商务", "科技", "教育", "营销", "极简"]
    private let templates = ["文档转PPT", "课程报告", "活动策划", "图片生成", "改写润色", "有奖招募"]
    @State private var tab = "论文"
    private let bottomTabs = ["论文", "PPT模板", "求职简历", "心得体会", "更多"]
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("AI工具")
                        .font(.system(size: 40, weight: .heavy))
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }
                .foregroundStyle(AppTheme.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI写长文")
                        .font(.system(size: 42, weight: .heavy))
                    Text("单篇可生成1.5万字+参考文献")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                    Button {
                        outlines = PPTGenerator.generate(topic: topic, audience: audience, slideCount: slideCount, style: style)
                    } label: {
                        Text("立即写作")
                            .font(.system(size: 30, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.77, green: 0.86, blue: 1.0), Color(red: 0.81, green: 0.88, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(templates, id: \.self) { t in
                        Button {
                            topic = t
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("生成高级排版")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "doc.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.primary.opacity(0.8))
                            }
                            .padding(12)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(bottomTabs, id: \.self) { item in
                            Button {
                                tab = item
                            } label: {
                                Text(item)
                                    .font(.system(size: 22, weight: tab == item ? .bold : .medium))
                                    .foregroundStyle(tab == item ? AppTheme.textPrimary : AppTheme.textSecondary)
                                    .overlay(alignment: .bottom) {
                                        if tab == item {
                                            Capsule().fill(AppTheme.primary).frame(height: 3).offset(y: 8)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SectionCard {
                    VStack(spacing: 12) {
                        HStack {
                            Text("大纲预览")
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Button("复制大纲") {
                                ClipboardService.copy(outlines.map(\.text).joined(separator: "\n"))
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
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
                        ChipPicker(title: "风格", options: styles, selection: $style)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: pageMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        AppPageScaffold(maxWidth: 960) {
            ProductivityHeader(
                title: "内容总结",
                subtitle: "输入长文本或会议记录，快速提炼重点",
                systemImage: "doc.text.magnifyingglass",
                tint: AppTheme.accentPurple
            )

            SectionCard {
                VStack(spacing: 12) {
                    TextEditorField(title: "原始内容", placeholder: "粘贴需要总结的内容", text: $sourceText, minHeight: 180)
                    ChipPicker(title: "总结方式", options: modes, selection: $mode)
                    ChipPicker(title: "长度", options: lengths, selection: $length)
                    HStack(spacing: 12) {
                        ProductivityActionButton("生成总结", systemImage: "bolt.fill", style: .filled) {
                            result = SummaryGenerator.generate(text: sourceText, mode: mode, length: length)
                        }
                        ProductivityActionButton("复制", systemImage: "doc.on.doc", style: .outline) {
                            ClipboardService.copy(result)
                        }
                        ProductivityActionButton("清空", systemImage: "trash", style: .ghost) {
                            sourceText = ""
                            result = ""
                        }
                    }
                }
            }

            SectionCard {
                VStack(spacing: 12) {
                    SectionTitle("总结结果")
                    if result.isEmpty {
                        EmptyStateRow(text: "生成后显示总结内容")
                    } else {
                        Text(result)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
