import SwiftUI

// MARK: - 写作
struct WritingStudioView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var topic = ""
    @State private var keywords = ""
    @State private var style = "通用"
    @State private var tone = "专业"
    @State private var length = "中等"
    @State private var draft = ""
    @State private var drafts: [WritingDraft] = []

    private let styles = ["通用", "营销文案", "工作汇报", "演讲稿", "产品介绍"]
    private let tones = ["专业", "温暖", "简洁", "鼓舞", "正式"]
    private let lengths = ["短", "中等", "长"]
    private let presets = ["新品发布文案", "周报总结", "活动邀请函", "招聘海报文案"]

    var body: some View {
        let _ = languageStore.current
        AppPageScaffold(maxWidth: 960) {
            ProductivityHeader(
                title: "写作工作台",
                subtitle: "结构化输入，快速生成可编辑草稿",
                systemImage: "pencil.and.outline",
                tint: AppTheme.accentStrong
            )

            SectionCard {
                VStack(spacing: 12) {
                    LabeledField(title: "写作主题", placeholder: "例如：AI 产品发布文案", text: $topic)
                    LabeledField(title: "关键词（可选）", placeholder: "例如：高效、稳定、低成本", text: $keywords)
                    ChipPicker(title: "风格", options: styles, selection: $style)
                    ChipPicker(title: "语气", options: tones, selection: $tone)
                    ChipPicker(title: "篇幅", options: lengths, selection: $length)
                    QuickChips(title: "模板快捷选题", options: presets) { preset in
                        topic = preset
                    }
                }
            }

            SectionCard {
                VStack(spacing: 12) {
                    TextEditorField(title: "生成草稿", placeholder: "点击下方生成按钮后显示草稿", text: $draft, minHeight: 180)
                    HStack(spacing: 12) {
                        ProductivityActionButton(L("生成草稿"), systemImage: "sparkles", style: .filled) {
                            draft = WritingGenerator.generate(
                                topic: topic,
                                keywords: keywords,
                                style: style,
                                tone: tone,
                                length: length
                            )
                        }
                        ProductivityActionButton(L("保存草稿"), systemImage: "tray.and.arrow.down", style: .outline) {
                            guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            drafts.insert(
                                WritingDraft(
                                    title: topic.isEmpty ? "未命名主题" : topic,
                                    content: draft,
                                    style: style,
                                    tone: tone,
                                    length: length,
                                    createdAt: Date()
                                ),
                                at: 0
                            )
                        }
                        ProductivityActionButton(L("复制"), systemImage: "doc.on.doc", style: .ghost) {
                            ClipboardService.copy(draft)
                        }
                    }
                }
            }

            SectionCard {
                VStack(spacing: 12) {
                    SectionTitle("草稿箱")
                    if drafts.isEmpty {
                        EmptyStateRow(text: "还没有保存草稿")
                    } else {
                        ForEach(drafts) { item in
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
    }
}

// MARK: - PPT
struct PPTStudioView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var topic = ""
    @State private var audience = ""
    @State private var slideCount = 10
    @State private var style = "商务"
    @State private var outlines: [SlideOutline] = []

    private let styles = ["商务", "科技", "教育", "营销", "极简"]
    private let templates = ["产品路演", "季度复盘", "市场调研", "培训课件"]

    var body: some View {
        let _ = languageStore.current
        AppPageScaffold(maxWidth: 960) {
            ProductivityHeader(
                title: "PPT 生成器",
                subtitle: "输入主题与受众，快速生成结构化大纲",
                systemImage: "rectangle.stack.fill",
                tint: AppTheme.brandBlue
            )

            SectionCard {
                VStack(spacing: 12) {
                    LabeledField(title: "主题", placeholder: "例如：AI 助理产品路演", text: $topic)
                    LabeledField(title: "受众", placeholder: "例如：管理层/客户/团队成员", text: $audience)
                    HStack {
                        Text(L("页数"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer(minLength: 0)
                        Stepper("\(slideCount) 页", value: $slideCount, in: 6...30)
                            .labelsHidden()
                    }
                    ChipPicker(title: "风格", options: styles, selection: $style)
                    QuickChips(title: "快速模板", options: templates) { preset in
                        topic = preset
                    }
                }
            }

            SectionCard {
                VStack(spacing: 12) {
                    HStack {
                        SectionTitle("大纲预览")
                        Spacer(minLength: 0)
                        Button(L("复制大纲")) {
                            ClipboardService.copy(outlines.map(\.text).joined(separator: "\n"))
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.accentStrong)
                    }
                    if outlines.isEmpty {
                        EmptyStateRow(text: "点击生成后显示 PPT 大纲")
                    } else {
                        ForEach(outlines) { outline in
                            SlideOutlineRow(outline: outline)
                        }
                    }
                    ProductivityActionButton(L("生成大纲"), systemImage: "wand.and.stars", style: .filled) {
                        outlines = PPTGenerator.generate(
                            topic: topic,
                            audience: audience,
                            slideCount: slideCount,
                            style: style
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 笔记
struct NotesWorkspaceView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    var contentOnly: Bool = false
    @State private var content = ""
    @State private var searchText = ""
    @State private var isRecording = false
    @State private var isGenerating = false
    @State private var alertMessage: String?
    @State private var notes: [NoteEntry] = []
    @State private var aiNote: AINotePayload?
    @State private var aiRawResponse: String?
    private let speechTranscriber = SpeechTranscriber()
    private let tokenStore = TokenStore.shared

    var body: some View {
        if contentOnly {
            notesContent
        } else {
            AppPageScaffold(maxWidth: 960) {
                ProductivityHeader(
                    title: "笔记中心",
                    subtitle: "随手记录，支持标签与快速检索",
                    systemImage: "note.text",
                    tint: AppTheme.accentWarm
                )
                notesContent
            }
        }
    }

    private var notesContent: some View {
        VStack(spacing: 12) {
            SectionCard {
                VStack(spacing: 12) {
                    TextEditorField(title: "内容", placeholder: "只需输入内容，AI 会自动生成标题、标签与分类", text: $content, minHeight: 180)
                    HStack(spacing: 10) {
                        ProductivityActionButton(isRecording ? "转写中" : "语音转写", systemImage: isRecording ? "waveform.circle.fill" : "mic.fill", style: .outline, size: .compact) {
                            toggleNoteRecording()
                        }
                        Spacer(minLength: 0)
                        ProductivityActionButton(isGenerating ? "生成中..." : "AI 整理笔记", systemImage: "sparkles", style: .filled, size: .compact) {
                            Task { await generateAINote() }
                        }
                        .disabled(isGenerating)
                    }
                    .padding(.top, 2)

                    if aiNote != nil {
                        Divider().padding(.vertical, 2)
                        AINoteEditor(note: $aiNote)
                        ProductivityActionButton(L("保存笔记"), systemImage: "tray.and.arrow.down", style: .outline) {
                            saveNoteToLocalAndCloud()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            SectionCard {
                VStack(spacing: 12) {
                    LabeledField(title: "快速搜索", placeholder: "输入关键字/标签/分类", text: $searchText)
                    if filteredNotes.isEmpty {
                        EmptyStateRow(text: "暂无笔记记录")
                    } else {
                        ForEach(filteredNotes) { note in
                            NoteRow(
                                note: note,
                                onMarkDone: { markReminderDone(note: note) },
                                onSnooze: { snoozeReminder(note: note) }
                            )
                        }
                    }
                }
            }
        }
        .alert(L("提示"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(L("确定"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .reminderUpdated)) { _ in
            notes = LocalDataStore.shared.loadNotes()
        }
        .onAppear {
            notes = LocalDataStore.shared.loadNotes()
        }
        .onDisappear {
            if isRecording {
                speechTranscriber.stopTranscribing()
                isRecording = false
            }
        }
    }

    private var filteredNotes: [NoteEntry] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return notes }
        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(keyword)
            || note.content.localizedCaseInsensitiveContains(keyword)
            || note.summary.localizedCaseInsensitiveContains(keyword)
            || note.category.localizedCaseInsensitiveContains(keyword)
            || note.tags.contains(where: { $0.localizedCaseInsensitiveContains(keyword) })
        }
    }

    private func toggleNoteRecording() {
        if isRecording {
            speechTranscriber.stopTranscribing()
            isRecording = false
            return
        }
        Task {
            let granted = await speechTranscriber.requestAuthorization()
            if !granted {
                await MainActor.run { alertMessage = "未获得语音识别权限" }
                return
            }
            await MainActor.run { isRecording = true }
            do {
                try speechTranscriber.startTranscribing(locale: Locale(identifier: "zh-CN")) { text, isFinal in
                    Task { @MainActor in
                        if !text.isEmpty {
                            content = text
                        }
                        if isFinal {
                            isRecording = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isRecording = false
                    alertMessage = Lf("语音转写失败：%@", error.localizedDescription)
                }
            }
        }
    }

    private func generateAINote() async {
        let input = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            await MainActor.run { alertMessage = "请先输入内容" }
            return
        }
        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }

        let prompt = """
        你是专业的中文笔记助手。请基于用户输入生成结构化笔记，并严格返回 JSON，不要包含其它文本。
        如果用户表达了提醒需求（例如“明天3点提醒我…”），请补全提醒字段；没有提醒则为 null。
        JSON 格式：
        {"title":"标题","summary":"总结","category":"分类","tags":["标签1","标签2"],"content":"整理后的正文","reminderAt":"ISO8601 时间或 null","reminderText":"提醒内容或 null","reminderSnoozeHours":3}
        用户输入：
        \(input)
        """
        do {
            let reply = try await APIClient.shared.generateNoteWithAI(prompt: prompt)
            await MainActor.run {
                aiRawResponse = reply
                if let parsed = decodeAINote(from: reply) {
                    var refined = parsed
                    refined.title = refineTitle(
                        raw: parsed.title,
                        fallback: parsed.summary,
                        input: input
                    )
                    aiNote = refined
                } else {
                    aiNote = AINotePayload.fallback(from: input, raw: reply)
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = userFacingMessage(for: error)
            }
        }
    }

    private func decodeAINote(from text: String) -> AINotePayload? {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AINotePayload.self, from: data)
    }

    private func refineTitle(raw: String, fallback: String, input: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if title.isEmpty {
            title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        title = title.replacingOccurrences(of: "\n", with: " ")
        if let range = title.range(of: "提醒") {
            title = String(title[..<range.lowerBound])
        }
        let patterns = [
            "^(请|麻烦|帮忙|帮我|我要|我想|需要)+",
            "^(请帮我|帮我记录|帮我整理|帮我总结|记录|整理|总结)+"
        ]
        for pattern in patterns {
            title = title.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        let timePrefixes = ["明天", "后天", "今天", "今晚", "今早", "上午", "下午", "晚上", "早上", "中午"]
        for prefix in timePrefixes where title.hasPrefix(prefix) {
            title = title.replacingOccurrences(of: prefix, with: "")
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.count > 16 {
            title = String(title.prefix(16))
        }
        return title.isEmpty ? L("未命名笔记") : title
    }

    private func saveNoteToLocalAndCloud() {
        guard let aiNote else { return }
        let entry = NoteEntry(
            id: UUID().uuidString,
            title: aiNote.title.isEmpty ? L("未命名笔记") : aiNote.title,
            summary: aiNote.summary,
            content: aiNote.content,
            tags: aiNote.tags,
            category: aiNote.category,
            reminderAt: aiNote.reminderAt,
            reminderText: aiNote.reminderText,
            reminderSnoozeHours: aiNote.reminderSnoozeHours,
            reminderStatus: aiNote.reminderAt == nil ? .none : .pending,
            createdAt: Date()
        )
        notes.insert(entry, at: 0)
        LocalDataStore.shared.saveNotes(notes)
        let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)
        content = ""
        self.aiNote = nil
        aiRawResponse = nil

        if let reminderAt = entry.reminderAt, entry.reminderStatus == .pending {
            ReminderService.shared.schedule(note: entry, at: reminderAt)
        }

        guard tokenStore.isLoggedIn else { return }
        Task {
            do {
                try await APIClient.shared.saveNoteToCloud(
                    title: entry.title,
                    summary: entry.summary,
                    category: entry.category,
                    tags: entry.tags,
                    content: entry.content,
                    rawText: raw
                )
            } catch {
                await MainActor.run {
                    alertMessage = "云端同步失败，已保存在本地。\(userFacingMessage(for: error))"
                }
            }
        }
    }

    private func markReminderDone(note: NoteEntry) {
        var list = LocalDataStore.shared.loadNotes()
        guard let idx = list.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = list[idx]
        updated.reminderStatus = .done
        updated.reminderAt = nil
        list[idx] = updated
        LocalDataStore.shared.saveNotes(list)
        notes = list
        ReminderService.shared.cancel(note: updated)
    }

    private func snoozeReminder(note: NoteEntry) {
        var list = LocalDataStore.shared.loadNotes()
        guard let idx = list.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = list[idx]
        let hours = max(1, updated.reminderSnoozeHours ?? 3)
        let newDate = Date().addingTimeInterval(Double(hours) * 3600)
        updated.reminderAt = newDate
        updated.reminderStatus = .pending
        list[idx] = updated
        LocalDataStore.shared.saveNotes(list)
        notes = list
        ReminderService.shared.schedule(note: updated, at: newDate)
    }
}

// MARK: - 总结
struct SummaryWorkspaceView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    var contentOnly: Bool = false
    @State private var sourceText = ""
    @State private var searchText = ""
    @State private var isRecording = false
    @State private var isGenerating = false
    @State private var alertMessage: String?
    @State private var summaries: [SummaryEntry] = []
    @State private var aiSummary: AISummaryPayload?
    private let speechTranscriber = SpeechTranscriber()
    private let tokenStore = TokenStore.shared

    var body: some View {
        let _ = languageStore.current
        if contentOnly {
            summaryContent
        } else {
            AppPageScaffold(maxWidth: 960) {
                ProductivityHeader(
                    title: "内容总结",
                    subtitle: "输入长文本或会议记录，快速提炼重点",
                    systemImage: "doc.text.magnifyingglass",
                    tint: AppTheme.accentPurple
                )
                summaryContent
            }
        }
    }

    private var summaryContent: some View {
        VStack(spacing: 12) {
            SectionCard {
                VStack(spacing: 12) {
                    TextEditorField(title: "内容输入", placeholder: "只需输入内容或语音转写，AI 会优化总结并生成标题/标签/分类", text: $sourceText, minHeight: 180)
                    HStack(spacing: 10) {
                        ProductivityActionButton(isRecording ? "转写中" : "语音转写", systemImage: isRecording ? "waveform.circle.fill" : "mic.fill", style: .outline, size: .compact) {
                            toggleSummaryRecording()
                        }
                        Spacer(minLength: 0)
                        ProductivityActionButton(isGenerating ? "生成中..." : "AI 生成总结", systemImage: "sparkles", style: .filled, size: .compact) {
                            Task { await generateAISummary() }
                        }
                        .disabled(isGenerating)
                    }
                    .padding(.top, 2)

                    if aiSummary != nil {
                        Divider().padding(.vertical, 2)
                        AISummaryEditor(summary: $aiSummary)
                        ProductivityActionButton(L("保存"), systemImage: "tray.and.arrow.down", style: .outline) {
                            saveSummaryToLocalAndCloud()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            SectionCard {
                VStack(spacing: 12) {
                    LabeledField(title: "快速搜索", placeholder: "输入关键字/标签/分类", text: $searchText)
                    if filteredSummaries.isEmpty {
                        EmptyStateRow(text: "暂无总结记录")
                    } else {
                        ForEach(filteredSummaries) { summary in
                            SummaryRow(summary: summary)
                        }
                    }
                }
            }
        }
        .alert(L("提示"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(L("确定"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onDisappear {
            if isRecording {
                speechTranscriber.stopTranscribing()
                isRecording = false
            }
        }
        .onAppear {
            summaries = LocalDataStore.shared.loadSummaries()
        }
    }

    private var filteredSummaries: [SummaryEntry] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return summaries }
        return summaries.filter { summary in
            summary.title.localizedCaseInsensitiveContains(keyword)
            || summary.summary.localizedCaseInsensitiveContains(keyword)
            || summary.category.localizedCaseInsensitiveContains(keyword)
            || summary.content.localizedCaseInsensitiveContains(keyword)
            || summary.tags.contains(where: { $0.localizedCaseInsensitiveContains(keyword) })
        }
    }

    private func toggleSummaryRecording() {
        if isRecording {
            speechTranscriber.stopTranscribing()
            isRecording = false
            return
        }
        Task {
            let granted = await speechTranscriber.requestAuthorization()
            if !granted {
                await MainActor.run { alertMessage = "未获得语音识别权限" }
                return
            }
            await MainActor.run { isRecording = true }
            do {
                try speechTranscriber.startTranscribing(locale: Locale(identifier: "zh-CN")) { text, isFinal in
                    Task { @MainActor in
                        if !text.isEmpty {
                            sourceText = text
                        }
                        if isFinal {
                            isRecording = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isRecording = false
                    alertMessage = Lf("语音转写失败：%@", error.localizedDescription)
                }
            }
        }
    }

    private func generateAISummary() async {
        let input = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            await MainActor.run { alertMessage = "请先输入内容" }
            return
        }
        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }

        let prompt = """
        你是专业的中文内容总结助手。请基于用户输入优化总结内容，并生成标题、标签与分类，严格返回 JSON。
        JSON 格式：
        {"title":"标题","summary":"摘要","category":"分类","tags":["标签1","标签2"],"content":"优化后的总结正文"}
        用户输入：
        \(input)
        """
        do {
            let reply = try await APIClient.shared.generateSummaryWithAI(prompt: prompt)
            await MainActor.run {
                if let parsed = decodeAISummary(from: reply) {
                    var refined = parsed
                    refined.title = refineTitle(
                        raw: parsed.title,
                        fallback: parsed.summary,
                        input: input
                    )
                    aiSummary = refined
                } else {
                    aiSummary = AISummaryPayload.fallback(from: input, raw: reply)
                }
            }
        } catch {
            await MainActor.run { alertMessage = userFacingMessage(for: error) }
        }
    }

    private func decodeAISummary(from text: String) -> AISummaryPayload? {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AISummaryPayload.self, from: data)
    }

private func saveSummaryToLocalAndCloud() {
    guard let aiSummary else { return }
    let raw = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    let entry = SummaryEntry(
        id: UUID().uuidString,
        title: aiSummary.title.isEmpty ? "未命名总结" : aiSummary.title,
        summary: aiSummary.summary,
        category: aiSummary.category,
        tags: aiSummary.tags,
        content: aiSummary.content,
        rawText: raw,
        createdAt: Date()
    )
    summaries.insert(entry, at: 0)
    LocalDataStore.shared.addSummary(entry)
    sourceText = ""
    self.aiSummary = nil

    if !tokenStore.isLoggedIn {
        alertMessage = "已保存到本地。"
        return
    }
    Task {
        do {
            try await APIClient.shared.saveSummaryToCloud(
                title: entry.title,
                summary: entry.summary,
                category: entry.category,
                tags: entry.tags,
                content: entry.content,
                rawText: entry.rawText
            )
            await MainActor.run {
                alertMessage = "已保存到云端。"
            }
        } catch {
            await MainActor.run {
                alertMessage = "云端同步失败。\(userFacingMessage(for: error))"
            }
        }
    }
}
}

enum NotesSummaryMode: String, CaseIterable, Identifiable {
    case note = "笔记"
    case summary = "总结"

    var id: String { rawValue }

    var displayName: String { L(rawValue) }
}

struct NotesSummaryWorkspaceView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var mode: NotesSummaryMode
    private let tokenStore = TokenStore.shared
    private let syncedNotesKey = "notes_synced_ids_v1"
    private let syncedSummariesKey = "summaries_synced_ids_v1"

    init(initialMode: NotesSummaryMode = .note) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        let _ = languageStore.current
        AppPageScaffold(maxWidth: 960) {
            VStack(spacing: 12) {
                Picker("模式", selection: $mode) {
                    ForEach(NotesSummaryMode.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 2)

                if mode == .note {
                    ProductivityHeader(
                        title: "笔记中心",
                        subtitle: "随手记录，AI 自动生成标题、标签与分类",
                        systemImage: "note.text",
                        tint: AppTheme.accentWarm
                    )
                    NotesWorkspaceView(contentOnly: true)
                } else {
                    ProductivityHeader(
                        title: "内容总结",
                        subtitle: "输入内容或语音转写，AI 优化总结并生成标题/标签/分类",
                        systemImage: "doc.text.magnifyingglass",
                        tint: AppTheme.accentPurple
                    )
                    SummaryWorkspaceView(contentOnly: true)
                }
            }
        }
        .onReceive(tokenStore.$token) { _ in
            Task { await syncLocalDataIfNeeded() }
        }
    }

    private func syncLocalDataIfNeeded() async {
        guard tokenStore.isLoggedIn else { return }
        await syncLocalNotesToCloud()
        await syncLocalSummariesToCloud()
    }

    private func syncLocalNotesToCloud() async {
        var synced = loadSyncedIds(forKey: syncedNotesKey)
        for note in LocalDataStore.shared.loadNotes() where !synced.contains(note.id) {
            do {
                try await APIClient.shared.saveNoteToCloud(
                    title: note.title,
                    summary: note.summary,
                    category: note.category,
                    tags: note.tags,
                    content: note.content,
                    rawText: note.content
                )
                synced.insert(note.id)
            } catch {
                // ignore single failure; will retry on next login
            }
        }
        saveSyncedIds(synced, forKey: syncedNotesKey)
    }

    private func syncLocalSummariesToCloud() async {
        var synced = loadSyncedIds(forKey: syncedSummariesKey)
        for summary in LocalDataStore.shared.loadSummaries() where !synced.contains(summary.id) {
            do {
                try await APIClient.shared.saveSummaryToCloud(
                    title: summary.title,
                    summary: summary.summary,
                    category: summary.category,
                    tags: summary.tags,
                    content: summary.content,
                    rawText: summary.rawText
                )
                synced.insert(summary.id)
            } catch {
                // ignore single failure; will retry on next login
            }
        }
        saveSyncedIds(synced, forKey: syncedSummariesKey)
    }

    private func loadSyncedIds(forKey key: String) -> Set<String> {
        let list = UserDefaults.standard.array(forKey: key) as? [String] ?? []
        return Set(list)
    }

    private func saveSyncedIds(_ ids: Set<String>, forKey key: String) {
        UserDefaults.standard.set(Array(ids), forKey: key)
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
                Text(L(title))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(L(subtitle))
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
        Text(L(text))
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
            Text(L(title))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            TextField(L(placeholder), text: $text)
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
            Text(L(title))
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
                    Text(L(placeholder))
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
            Text(L(title))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                        } label: {
                            Text(L(option))
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
            Text(L(title))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            Text(L(option))
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
            Text(L(text))
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

    enum Size {
        case regular
        case compact
    }

    let title: String
    let systemImage: String?
    let style: Style
    let size: Size
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, style: Style = .filled, size: Size = .regular, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(iconFont)
                }
                Text(L(title))
                    .font(textFont)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
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

    private var textFont: Font {
        switch size {
        case .regular: return .callout.weight(.semibold)
        case .compact: return .subheadline.weight(.semibold)
        }
    }

    private var iconFont: Font {
        switch size {
        case .regular: return .callout.weight(.semibold)
        case .compact: return .subheadline.weight(.semibold)
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return 12
        case .compact: return 8
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return 18
        case .compact: return 12
        }
    }
}

private struct DraftRow: View {
    let draft: WritingDraft
    var onLoad: () -> Void

    var body: some View {
        Button(action: onLoad) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L(draft.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            Text(Lf("风格：%@ · 语气：%@ · 篇幅：%@", draft.style, draft.tone, draft.length))
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
            Text(L(outline.title))
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
    var onMarkDone: () -> Void = {}
    var onSnooze: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L(note.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Text(note.dateText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            if !note.category.isEmpty {
                Text(note.category)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if !note.summary.isEmpty {
                Text(note.summary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
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
            if note.reminderStatus == .pending, let at = note.reminderAt {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
            Text(Lf("提醒：%@", formatReminderDate(at)))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer(minLength: 0)
                    Button(L("未完成")) {
                        onSnooze()
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.accentStrong)
                    Button(L("已完成")) {
                        onMarkDone()
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func formatReminderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

private struct SummaryRow: View {
    let summary: SummaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L(summary.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Text(summary.dateText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            if !summary.category.isEmpty {
                Text(summary.category)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if !summary.summary.isEmpty {
                Text(summary.summary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Text(summary.content)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(3)
            if !summary.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(summary.tags, id: \.self) { tag in
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

private struct AINotePayload: Codable {
    var title: String
    var summary: String
    var category: String
    var tags: [String]
    var content: String
    var reminderAt: Date?
    var reminderText: String?
    var reminderSnoozeHours: Int?

    init(title: String, summary: String, category: String, tags: [String], content: String, reminderAt: Date?, reminderText: String?, reminderSnoozeHours: Int?) {
        self.title = title
        self.summary = summary
        self.category = category
        self.tags = tags
        self.content = content
        self.reminderAt = reminderAt
        self.reminderText = reminderText
        self.reminderSnoozeHours = reminderSnoozeHours
    }

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case category
        case tags
        case content
        case reminderAt
        case reminderText
        case reminderSnoozeHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        category = (try? container.decode(String.self, forKey: .category)) ?? ""
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        reminderText = try? container.decode(String.self, forKey: .reminderText)
        reminderSnoozeHours = try? container.decode(Int.self, forKey: .reminderSnoozeHours)

        if let raw = try? container.decode(String.self, forKey: .reminderAt) {
            reminderAt = parseReminderDate(raw)
        } else {
            reminderAt = nil
        }
    }

    static func fallback(from input: String, raw: String) -> AINotePayload {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = String(trimmed.prefix(12))
        let summary = String(trimmed.prefix(60))
        return AINotePayload(
            title: title.isEmpty ? "未命名笔记" : title,
            summary: summary,
            category: "未分类",
            tags: [],
            content: trimmed.isEmpty ? raw : trimmed,
            reminderAt: nil,
            reminderText: nil,
            reminderSnoozeHours: nil
        )
    }
}

private struct AISummaryPayload: Codable {
    var title: String
    var summary: String
    var category: String
    var tags: [String]
    var content: String

    static func fallback(from input: String, raw: String) -> AISummaryPayload {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = String(trimmed.prefix(12))
        let summary = String(trimmed.prefix(60))
        return AISummaryPayload(
            title: title.isEmpty ? "未命名总结" : title,
            summary: summary,
            category: "未分类",
            tags: [],
            content: trimmed.isEmpty ? raw : trimmed
        )
    }
}

private struct AINotePreview: View {
    let note: AINotePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(note.title))
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(note.summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                if !note.category.isEmpty {
                    Text(note.category)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textOnPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary.opacity(0.75))
                        .clipShape(Capsule())
                }
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
            Text(note.content)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(4)
        }
        .padding(12)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AINoteEditor: View {
    @Binding var note: AINotePayload?
    @State private var tagsText: String = ""

    var body: some View {
        if let note {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("基础信息")
                NoteSectionCard {
                    LabeledField(title: "标题", placeholder: "AI 生成标题", text: binding(\.title))
                    LabeledField(title: "分类", placeholder: "AI 生成分类", text: binding(\.category))
                    LabeledField(title: "标签（逗号分隔）", placeholder: "AI 生成标签", text: Binding(
                        get: { tagsText.isEmpty ? note.tags.joined(separator: ",") : tagsText },
                        set: { tagsText = $0; self.note?.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                    ))
                }

                SectionTitle("内容")
                NoteSectionCard {
                    TextEditorField(title: "摘要", placeholder: "AI 生成摘要", text: binding(\.summary), minHeight: 80)
                    TextEditorField(title: "正文", placeholder: "AI 生成正文", text: binding(\.content), minHeight: 140)
                }

                SectionTitle("提醒")
                NoteSectionCard {
                    ToggleRow(
                        title: "提醒我",
                        subtitle: "到时间自动提醒",
                        isOn: Binding(
                            get: { note.reminderAt != nil },
                            set: { enabled in
                                if enabled {
                                    self.note?.reminderAt = note.reminderAt ?? Date().addingTimeInterval(3600)
                                    self.note?.reminderSnoozeHours = note.reminderSnoozeHours ?? 3
                                } else {
                                    self.note?.reminderAt = nil
                                }
                            }
                        )
                    )
                    if note.reminderAt != nil {
                        InlineDateTimeRow(
                            title: "提醒时间",
                            selection: Binding(
                                get: { note.reminderAt ?? Date() },
                                set: { self.note?.reminderAt = $0 }
                            )
                        )
                        LabeledField(title: "提醒内容", placeholder: "默认使用摘要", text: Binding(
                            get: { note.reminderText ?? "" },
                            set: { self.note?.reminderText = $0 }
                        ))
                        LabeledField(title: "未完成后延后（小时）", placeholder: "例如：3", text: Binding(
                            get: { String(note.reminderSnoozeHours ?? 3) },
                            set: { self.note?.reminderSnoozeHours = Int($0) ?? 3 }
                        ))
                    }
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AINotePayload, String>) -> Binding<String> {
        Binding(
            get: { note?[keyPath: keyPath] ?? "" },
            set: { newValue in
                if note != nil { note?[keyPath: keyPath] = newValue }
            }
        )
    }
}

private struct NoteSectionCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 6, x: 0, y: 3)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let subtitle {
                    Text(L(subtitle))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct InlineDateTimeRow: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 0)
            DatePicker("", selection: $selection, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AISummaryEditor: View {
    @Binding var summary: AISummaryPayload?
    @State private var tagsText: String = ""

    var body: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("基础信息")
                NoteSectionCard {
                    LabeledField(title: "标题", placeholder: "AI 生成标题", text: binding(\.title))
                    LabeledField(title: "分类", placeholder: "AI 生成分类", text: binding(\.category))
                    LabeledField(title: "标签（逗号分隔）", placeholder: "AI 生成标签", text: Binding(
                        get: { tagsText.isEmpty ? summary.tags.joined(separator: ",") : tagsText },
                        set: { tagsText = $0; self.summary?.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                    ))
                }

                SectionTitle("内容")
                NoteSectionCard {
                    TextEditorField(title: "摘要", placeholder: "AI 生成摘要", text: binding(\.summary), minHeight: 80)
                    TextEditorField(title: "优化后的总结", placeholder: "AI 生成总结内容", text: binding(\.content), minHeight: 140)
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AISummaryPayload, String>) -> Binding<String> {
        Binding(
            get: { summary?[keyPath: keyPath] ?? "" },
            set: { newValue in
                if summary != nil { summary?[keyPath: keyPath] = newValue }
            }
        )
    }
}

private struct AISummaryPreview: View {
    let summary: AISummaryPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(summary.title))
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(summary.summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                if !summary.category.isEmpty {
                    Text(summary.category)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textOnPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary.opacity(0.75))
                        .clipShape(Capsule())
                }
                ForEach(summary.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accentStrong)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentStrong.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Text(summary.content)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(4)
        }
        .padding(12)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private func extractJSON(from text: String) -> String {
    if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
        return String(text[start...end])
    }
    return text
}

private func refineTitle(raw: String, fallback: String, input: String) -> String {
    var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if title.isEmpty {
        title = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if title.isEmpty {
        title = input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    title = title.replacingOccurrences(of: "\n", with: " ")
    if let range = title.range(of: "提醒") { title = String(title[..<range.lowerBound]) }
    let patterns = [
        "^(请|麻烦|帮忙|帮我|我要|我想|需要|请帮我|帮我记录|帮我整理|帮我总结|帮我做个总结|帮我做个|帮我|记录|整理|总结)+",
        "^([我你他她]们?)(想|要|需要|准备|计划|去|做)+"
    ]
    for pattern in patterns {
        title = title.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }
    let timePrefixes = ["明天", "后天", "今天", "今晚", "今早", "上午", "下午", "晚上", "早上", "中午"]
    for prefix in timePrefixes where title.hasPrefix(prefix) {
        title = title.replacingOccurrences(of: prefix, with: "")
    }
    if let split = title.split(whereSeparator: { "，。；、,.!！?？".contains($0) }).first {
        title = String(split)
    }
    title = title.replacingOccurrences(of: "帮我", with: "")
    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if title.count > 14 { title = String(title.prefix(14)) }
    return title.isEmpty ? "未命名笔记" : title
}

private func parseReminderDate(_ raw: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }
    let iso = ISO8601DateFormatter()
    if let d = iso.date(from: trimmed) { return d }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    if let d = formatter.date(from: trimmed) { return d }
    formatter.dateFormat = "MM-dd HH:mm"
    if let d = formatter.date(from: trimmed) {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        if let merged = cal.date(bySetting: .year, value: year, of: d) {
            return merged
        }
        return d
    }
    return nil
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
