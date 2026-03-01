import SwiftUI
import UniformTypeIdentifiers

struct AIAssistantDesignedHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSearch = false
    @State private var showHistory = false
    @State private var showQuickStart = false
    @State private var showAudioImporter = false
    @State private var showVideoImporter = false
    @State private var showTranslateFromImport = false
    @State private var showWritingStudio = false
    @State private var showPPTStudio = false
    @State private var showNotesWorkspace = false
    @State private var showSummaryWorkspace = false
    @State private var showRealtimeTranslate = false
    @State private var showTranslateHome = false
    @State private var showLearningHome = false
    @State private var showAssistantChat = false
    @State private var isImportingMedia = false
    @State private var importStatusText: String?
    @State private var importAlertMessage: String?
    @State private var showStackChanDialog = false

    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                topBar
                quickStartCardButton
                creationSection
                languageSection
                importSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: pageMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $showSearch) {
            AssistantServiceSearchView()
        }
        .navigationDestination(isPresented: $showHistory) {
            AssistantHistoryView()
        }
        .navigationDestination(isPresented: $showQuickStart) {
            AssistantQuickStartView()
        }
        .navigationDestination(isPresented: $showTranslateFromImport) {
            AITranslateHomeView()
        }
        .navigationDestination(isPresented: $showWritingStudio) {
            WritingStudioView()
        }
        .navigationDestination(isPresented: $showPPTStudio) {
            PPTStudioView()
        }
        .navigationDestination(isPresented: $showNotesWorkspace) {
            NotesWorkspaceView()
        }
        .navigationDestination(isPresented: $showSummaryWorkspace) {
            SummaryWorkspaceView()
        }
        .navigationDestination(isPresented: $showRealtimeTranslate) {
            RealTimeTranslationView()
        }
        .navigationDestination(isPresented: $showTranslateHome) {
            AITranslateHomeView()
        }
        .navigationDestination(isPresented: $showLearningHome) {
            IndonesianLearningView()
        }
        .navigationDestination(isPresented: $showAssistantChat) {
            AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
        }
        .alert("导入失败", isPresented: Binding(
            get: { importAlertMessage != nil },
            set: { if !$0 { importAlertMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(importAlertMessage ?? "")
        }
        .fileImporter(
            isPresented: $showAudioImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await handleImportedMedia(url: url, isVideo: false) }
        }
        .fileImporter(
            isPresented: $showVideoImporter,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await handleImportedMedia(url: url, isVideo: true) }
        }
        .overlay(alignment: .bottomTrailing) {
            StackChanFloatingButton {
                showStackChanDialog = true
            }
            .padding(.trailing, 14)
            .padding(.bottom, 90)
        }
        .fullScreenCover(isPresented: $showStackChanDialog) {
            StackChanDialogView()
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI小酱")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("剩余：5000字")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 10) {
                iconTopButton(system: "magnifyingglass", label: "搜索") { showSearch = true }
                iconTopButton(system: "clock", label: "历史") { showHistory = true }
            }
        }
    }

    private func iconTopButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var quickStartCardButton: some View {
        Button {
            showQuickStart = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.74, green: 0.83, blue: 1.0))
                            .frame(width: 46, height: 46)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(red: 0.26, green: 0.38, blue: 0.93))
                    }
                    Text("你好，我是小酱问问～")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    tagPill("学习问答")
                    tagPill("模拟面试")
                    tagPill("文章创作")
                }

                HStack(spacing: 10) {
                    Text("点击输入聊天内容")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 38, height: 38)
                        .background(Color(red: 0.92, green: 0.95, blue: 1.0))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.37, green: 0.36, blue: 0.95), lineWidth: 1.8)
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.81, green: 0.88, blue: 1.0),
                                Color(red: 0.82, green: 0.92, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())
    }

    private var creationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("创作与办公")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button {
                    showWritingStudio = true
                } label: {
                    quickToolCard(title: "写作创作", subtitle: "文章生成、润色、扩写", icon: "square.and.pencil", tint: Color(red: 0.85, green: 0.93, blue: 1.0))
                }
                .buttonStyle(.plain)

                Button {
                    showPPTStudio = true
                } label: {
                    quickToolCard(title: "PPT 生成", subtitle: "大纲与页面结构生成", icon: "rectangle.on.rectangle.angled", tint: Color(red: 0.90, green: 0.95, blue: 1.0))
                }
                .buttonStyle(.plain)

                Button {
                    showNotesWorkspace = true
                } label: {
                    quickToolCard(title: "笔记整理", subtitle: "记录整理与结构化输出", icon: "note.text", tint: Color(red: 0.89, green: 0.96, blue: 1.0))
                }
                .buttonStyle(.plain)

                Button {
                    showSummaryWorkspace = true
                } label: {
                    quickToolCard(title: "总结归纳", subtitle: "会议与文档摘要提炼", icon: "list.bullet.clipboard", tint: Color(red: 0.92, green: 0.93, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
        }
        .sectionContainerStyle
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("对话与学习")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button {
                    showAssistantChat = true
                } label: {
                    quickToolCard(title: "AI 对话", subtitle: "问答、任务、场景协助", icon: "message.fill", tint: Color(red: 0.86, green: 0.94, blue: 1.0))
                }
                .buttonStyle(.plain)

                Button {
                    showRealtimeTranslate = true
                } label: {
                    quickToolCard(title: "实时翻译", subtitle: "双语对话实时输出", icon: "waveform.badge.mic", tint: Color(red: 0.88, green: 0.92, blue: 1.0))
                }
                .buttonStyle(.plain)

                Button {
                    showTranslateHome = true
                } label: {
                    quickToolCard(title: "翻译主页", subtitle: "文本与语音翻译", icon: "character.bubble.fill", tint: Color(red: 0.89, green: 0.95, blue: 1.0))
                }
                .buttonStyle(.plain)

                Button {
                    showLearningHome = true
                } label: {
                    quickToolCard(title: "学习中心", subtitle: "词汇短句与场景学习", icon: "book.fill", tint: Color(red: 0.91, green: 0.95, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
        }
        .sectionContainerStyle
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("素材导入")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 10) {
                Button {
                    showAudioImporter = true
                } label: {
                    importCard(title: "导入音频", subtitle: "本地音频转写", icon: "music.note")
                }
                .buttonStyle(.plain)

                Button {
                    showVideoImporter = true
                } label: {
                    importCard(title: "导入视频", subtitle: "视频音轨转写", icon: "video.fill")
                }
                .buttonStyle(.plain)
            }

            if isImportingMedia {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(importStatusText ?? "处理中...")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .sectionContainerStyle
    }

    private func quickToolCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(10)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func importCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.89, green: 0.95, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func handleImportedMedia(url: URL, isVideo: Bool) async {
        await MainActor.run {
            isImportingMedia = true
            importStatusText = isVideo ? "正在提取视频音频并转写..." : "正在转写音频..."
        }

        do {
            let secured = url.startAccessingSecurityScopedResource()
            defer {
                if secured { url.stopAccessingSecurityScopedResource() }
            }

            let tempURL = try copyToTemp(url)
            let transcript = try await MediaSpeechTranscriber.transcribe(
                from: tempURL,
                localeIdentifier: "zh-CN",
                isVideo: isVideo
            )

            await MainActor.run {
                isImportingMedia = false
                importStatusText = nil
                MediaImportCoordinator.shared.pendingText = transcript
                showTranslateFromImport = true
            }
        } catch {
            await MainActor.run {
                isImportingMedia = false
                importStatusText = nil
                importAlertMessage = error.localizedDescription
            }
        }
    }

    private func copyToTemp(_ sourceURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let ext = sourceURL.pathExtension.isEmpty ? "tmp" : sourceURL.pathExtension
        let target = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: sourceURL, to: target)
        return target
    }
}

private struct StackChanFloatingButton: View {
    let onTap: () -> Void
    @AppStorage("stack_chan_daily_event_date") private var dailyEventDate = ""
    @AppStorage("stack_chan_daily_event_done") private var dailyEventDone = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private var hasPendingEvent: Bool {
        let today = StackChanDateUtil.todayString()
        if dailyEventDate != today { return true }
        return !dailyEventDone
    }

    var body: some View {
        Button(action: onTap) {
            StackChanFloatingIcon(isSpeaking: false, emotion: .happy)
                .scaleEffect(isDragging ? 1.06 : 1.0)
                .offset(dragOffset)
                .overlay(alignment: .topTrailing) {
                    if hasPendingEvent {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDragging = false
                        dragOffset = .zero
                    }
                }
        )
        .accessibilityLabel("打开 Stack-chan 助手")
    }
}

private struct StackChanFloatingIcon: View {
    let isSpeaking: Bool
    let emotion: StackChanEmotion
    @State private var blink = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 58, height: 58)
                .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 5)

            VStack(spacing: 7) {
                HStack(spacing: 10) {
                    eye
                    eye
                }
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(emotion == .happy ? 0.95 : 0.8))
                    .frame(width: isSpeaking ? 13 : 9, height: isSpeaking ? 4 : 2)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Int.random(in: 1_700_000_000...3_300_000_000)))
                withAnimation(.easeInOut(duration: 0.1)) { blink = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeInOut(duration: 0.1)) { blink = false }
            }
        }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white)
            .frame(width: 11, height: blink ? 2.4 : 11)
    }
}

private enum StackChanEmotion {
    case neutral
    case happy
    case thinking
    case listening
}

private enum StackChanSkin: String, CaseIterable, Identifiable {
    case classic
    case mint
    case sunset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "经典"
        case .mint: return "薄荷"
        case .sunset: return "晚霞"
        }
    }

    var faceBackground: Color {
        switch self {
        case .classic: return .black
        case .mint: return Color(red: 0.08, green: 0.24, blue: 0.22)
        case .sunset: return Color(red: 0.24, green: 0.11, blue: 0.17)
        }
    }

    var accent: Color {
        switch self {
        case .classic: return AppTheme.primary
        case .mint: return Color(red: 0.11, green: 0.66, blue: 0.56)
        case .sunset: return Color(red: 0.96, green: 0.47, blue: 0.31)
        }
    }
}

private struct StackChanDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var speechService = SpeechService.shared
    @AppStorage("stack_chan_pet_points") private var petPoints = 0
    @AppStorage("stack_chan_pet_name") private var petName = "豆豆"
    @AppStorage("stack_chan_favorite_topic") private var favoriteTopic = "聊天"
    @AppStorage("stack_chan_streak_days") private var streakDays = 1
    @AppStorage("stack_chan_last_active_date") private var lastActiveDate = ""
    @AppStorage("stack_chan_daily_chat_count") private var dailyChatCount = 0
    @AppStorage("stack_chan_daily_task_date") private var dailyTaskDate = ""
    @AppStorage("stack_chan_badge_chat_novice") private var badgeChatNovice = false
    @AppStorage("stack_chan_badge_streak_7") private var badgeStreak7 = false
    @AppStorage("stack_chan_badge_pet_lover") private var badgePetLover = false
    @AppStorage("stack_chan_daily_event_date") private var dailyEventDate = ""
    @AppStorage("stack_chan_daily_event_id") private var dailyEventId = ""
    @AppStorage("stack_chan_daily_event_done") private var dailyEventDone = false
    @AppStorage("stack_chan_message_cache") private var messageCache = ""
    @AppStorage("stack_chan_input_locale") private var inputLocaleCode = "zh-CN"
    @AppStorage("stack_chan_output_locale") private var outputLocaleCode = "zh-CN"
    @AppStorage("stack_chan_skin") private var skinRawValue = StackChanSkin.classic.rawValue
    @AppStorage("stack_chan_last_greeting_date") private var lastGreetingDate = ""

    @State private var messages: [StackChanMessage] = [
        StackChanMessage(role: .assistant, text: "嗨，我是豆豆机器人。今天也一起玩吧。")
    ]
    @State private var inputText = ""
    @State private var isSending = false
    @State private var isListening = false
    @State private var errorMessage: String?
    @State private var conversationId: String?
    private let transcriber = SpeechTranscriber()

    @State private var emotion: StackChanEmotion = .happy
    @State private var blink = false
    @State private var mouthOpen = false
    @State private var gazeX: CGFloat = 0
    @State private var showPetRoom = false
    @State private var showMemoryEditor = false
    @State private var currentEvent: StackChanPetEvent?

    private let quickPrompts = ["给我一个鼓励", "陪我练口语", "今天做什么", "讲个冷笑话"]
    private let dailyGoal = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                petHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { message in
                                bubble(message)
                            }
                            if isSending {
                                thinkingBubble
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: messages.count) { _, _ in
                        guard let last = messages.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }

                quickPromptRow
                eventCard

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }

                composer
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        SpeechService.shared.stopSpeaking()
                        stopListening()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            clearConversation()
                        } label: {
                            Image(systemName: "trash")
                        }
                        Button {
                            showMemoryEditor = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        Button {
                            showPetRoom = true
                        } label: {
                            Image(systemName: "house.fill")
                        }
                    }
                }
            }
            .task {
                loadCachedMessages()
                resetDailyTaskIfNeeded()
                prepareDailyEventIfNeeded()
                updateDailyStreak()
                appendDailyGreetingIfNeeded()
                await runIdleFaceAnimation()
            }
            .onChange(of: speechService.isPlaying) { _, isPlaying in
                if isPlaying {
                    emotion = .happy
                    Task { await runMouthAnimation() }
                } else {
                    mouthOpen = false
                }
            }
            .fullScreenCover(isPresented: $showPetRoom) {
                StackChanPetRoomView(
                    petName: $petName,
                    favoriteTopic: $favoriteTopic,
                    petPoints: $petPoints,
                    streakDays: $streakDays,
                    dailyChatCount: $dailyChatCount,
                    dailyGoal: dailyGoal,
                    badgeChatNovice: $badgeChatNovice,
                    badgeStreak7: $badgeStreak7,
                    badgePetLover: $badgePetLover,
                    skinRawValue: $skinRawValue
                )
            }
            .sheet(isPresented: $showMemoryEditor) {
                NavigationStack {
                    Form {
                        Section("关系记忆") {
                            TextField("机器人昵称", text: $petName)
                            TextField("你更想聊的话题", text: $favoriteTopic)
                        }
                        Section("语音设置") {
                            Picker("输入语言", selection: $inputLocaleCode) {
                                ForEach(StackChanLanguageOption.allCases) { option in
                                    Text(option.title).tag(option.localeCode)
                                }
                            }
                            Picker("播报语言", selection: $outputLocaleCode) {
                                ForEach(StackChanLanguageOption.allCases) { option in
                                    Text(option.title).tag(option.localeCode)
                                }
                            }
                        }
                    }
                    .navigationTitle("豆豆记忆")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { showMemoryEditor = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var petHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.93, blue: 1.0), Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 8) {
                    StackChanFacePanel(emotion: emotion, blink: blink, mouthOpen: mouthOpen, gazeX: gazeX, skin: currentSkin)
                    Text("\(petName)机器人 · 亲密度 \(petPoints) · 连续 \(streakDays) 天")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 12)
            }
            .frame(height: 150)
            .padding(.horizontal, 16)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("今日互动任务")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(dailyChatCount)/\(dailyGoal)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.surfaceMuted)
                            .frame(height: 8)
                        Capsule()
                            .fill(AppTheme.primary)
                            .frame(width: geo.size.width * min(Double(dailyChatCount) / Double(dailyGoal), 1), height: 8)
                    }
                }
                .frame(height: 8)

                HStack(spacing: 8) {
                    badgePill("新手聊天", unlocked: badgeChatNovice)
                    badgePill("7日陪伴", unlocked: badgeStreak7)
                    badgePill("宠物达人", unlocked: badgePetLover)
                }
            }
            .padding(12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private func badgePill(_ title: String, unlocked: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: unlocked ? "medal.fill" : "lock.fill")
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(unlocked ? Color.orange : AppTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background((unlocked ? Color.orange.opacity(0.12) : AppTheme.surfaceMuted))
        .clipShape(Capsule())
    }

    private var quickPromptRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(prompt) {
                        inputText = prompt
                        Task { await sendMessage() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var eventCard: some View {
        if let event = currentEvent {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("今日事件")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    if dailyEventDone {
                        Text("已完成")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }

                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 8) {
                    Button {
                        completeEvent(event)
                    } label: {
                        Text(dailyEventDone ? "已领取奖励" : "完成事件 +\(event.reward)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(dailyEventDone ? Color.gray : AppTheme.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(dailyEventDone)

                    Button("换一个") {
                        switchEvent()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Button {
                toggleListening()
            } label: {
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(isListening ? Color.red : AppTheme.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            TextField("和豆豆机器人说点什么...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Menu {
                ForEach(StackChanLanguageOption.allCases) { option in
                    Button {
                        inputLocaleCode = option.localeCode
                    } label: {
                        if inputLocaleCode == option.localeCode {
                            Label(option.shortTitle, systemImage: "checkmark")
                        } else {
                            Text(option.shortTitle)
                        }
                    }
                }
            } label: {
                Text(activeInputLanguage.shortTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(Circle())
            }

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(isSending ? Color.gray : AppTheme.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSending)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func bubble(_ message: StackChanMessage) -> some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 44) }
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.role == .assistant ? Color.white : AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .trailing : .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(message.role == .assistant ? AppTheme.primary : AppTheme.surface)
                )
            if message.role == .user { Spacer(minLength: 44) }
        }
        .id(message.id)
    }

    private var thinkingBubble: some View {
        HStack {
            Spacer(minLength: 44)
            Text("豆豆正在思考...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.primary.opacity(0.8)))
        }
    }

    private func toggleListening() {
        if isListening {
            stopListening()
            emotion = .neutral
            return
        }
        Task { await startListening() }
    }

    @MainActor
    private func startListening() async {
        SpeechService.shared.stopSpeaking()
        errorMessage = nil
        emotion = .listening
        do {
            let granted = await transcriber.requestAuthorization()
            guard granted else {
                errorMessage = "请在系统设置中允许语音识别权限"
                emotion = .neutral
                return
            }
            try transcriber.startTranscribing(locale: Locale(identifier: inputLocaleCode)) { text, isFinal in
                Task { @MainActor in
                    if !text.isEmpty { inputText = text }
                    if isFinal {
                        isListening = false
                        emotion = .happy
                    }
                }
            }
            isListening = true
        } catch {
            errorMessage = userFacingMessage(for: error)
            isListening = false
            emotion = .neutral
        }
    }

    @MainActor
    private func stopListening() {
        transcriber.stopTranscribing()
        isListening = false
    }

    @MainActor
    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        stopListening()
        errorMessage = nil
        isSending = true
        emotion = .thinking
        inputText = ""
        messages.append(StackChanMessage(role: .user, text: text))
        persistMessages()

        do {
            let response = try await StackChanAPI.chat(message: text, conversationId: conversationId)
            conversationId = response.conversationId ?? conversationId
            messages.append(StackChanMessage(role: .assistant, text: response.reply))
            petPoints = min(petPoints + 1, 9999)
            dailyChatCount = min(dailyChatCount + 1, 999)
            emotion = inferredEmotion(from: response.reply)
            updateMemory(from: text)
            unlockBadgesIfNeeded()
            SpeechService.shared.speak(replyWithMoodPrefix(response.reply), language: outputLocaleCode)
            persistMessages()
        } catch {
            errorMessage = userFacingMessage(for: error)
            messages.append(StackChanMessage(role: .assistant, text: "哎呀，我走神了。再说一次吧。"))
            emotion = .neutral
            persistMessages()
        }
        isSending = false
    }

    private func inferredEmotion(from reply: String) -> StackChanEmotion {
        let text = reply.lowercased()
        if text.contains("哈哈") || text.contains("太棒") || text.contains("开心") || text.contains("赞") { return .happy }
        if text.contains("稍等") || text.contains("思考") || text.contains("让我看看") { return .thinking }
        return .neutral
    }

    private func runIdleFaceAnimation() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Int.random(in: 1_800_000_000...3_300_000_000)))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.1)) { blink = true }
            }
            try? await Task.sleep(nanoseconds: 110_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.1)) {
                    blink = false
                    gazeX = CGFloat.random(in: -5...5)
                }
            }
        }
    }

    private func runMouthAnimation() async {
        while speechService.isPlaying && !Task.isCancelled {
            await MainActor.run { withAnimation(.easeInOut(duration: 0.09)) { mouthOpen.toggle() } }
            try? await Task.sleep(nanoseconds: 90_000_000)
        }
        await MainActor.run { mouthOpen = false }
    }

    private func resetDailyTaskIfNeeded() {
        let today = StackChanDateUtil.todayString()
        guard dailyTaskDate != today else { return }
        dailyTaskDate = today
        dailyChatCount = 0
    }

    private func unlockBadgesIfNeeded() {
        if dailyChatCount >= dailyGoal { badgeChatNovice = true }
        if streakDays >= 7 { badgeStreak7 = true }
        if petPoints >= 100 { badgePetLover = true }
    }

    private func replyWithMoodPrefix(_ reply: String) -> String {
        switch emotion {
        case .happy:
            return "耶，\(reply)"
        case .thinking:
            return "我想到了，\(reply)"
        case .listening:
            return "我听到了，\(reply)"
        case .neutral:
            return reply
        }
    }

    private func updateMemory(from text: String) {
        let lower = text.lowercased()
        if lower.contains("英语") || lower.contains("口语") { favoriteTopic = "口语练习" }
        else if lower.contains("学习") { favoriteTopic = "学习" }
        else if lower.contains("翻译") { favoriteTopic = "翻译" }
        else if lower.contains("写作") { favoriteTopic = "写作" }
    }

    private func updateDailyStreak() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        guard lastActiveDate != today else { return }
        if let last = formatter.date(from: lastActiveDate),
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
           Calendar.current.isDate(last, inSameDayAs: yesterday) {
            streakDays += 1
        } else if !lastActiveDate.isEmpty {
            streakDays = 1
        }
        lastActiveDate = today
    }

    private func prepareDailyEventIfNeeded() {
        let today = StackChanDateUtil.todayString()
        if dailyEventDate != today {
            dailyEventDate = today
            dailyEventDone = false
            let randomEvent = StackChanPetEvent.library.randomElement() ?? StackChanPetEvent.library[0]
            dailyEventId = randomEvent.id
            currentEvent = randomEvent
            return
        }
        currentEvent = StackChanPetEvent.library.first(where: { $0.id == dailyEventId }) ?? StackChanPetEvent.library[0]
    }

    private func switchEvent() {
        let options = StackChanPetEvent.library.filter { $0.id != currentEvent?.id }
        guard let next = options.randomElement() else { return }
        currentEvent = next
        dailyEventId = next.id
        dailyEventDone = false
    }

    private func completeEvent(_ event: StackChanPetEvent) {
        guard !dailyEventDone else { return }
        dailyEventDone = true
        petPoints = min(petPoints + event.reward, 9999)
        dailyChatCount = min(dailyChatCount + 1, 999)
        emotion = .happy
        unlockBadgesIfNeeded()
        messages.append(StackChanMessage(role: .assistant, text: "事件完成！奖励你 +\(event.reward) 亲密度，太棒了。"))
        persistMessages()
    }

    private var currentSkin: StackChanSkin {
        StackChanSkin(rawValue: skinRawValue) ?? .classic
    }

    private func appendDailyGreetingIfNeeded() {
        let today = StackChanDateUtil.todayString()
        guard lastGreetingDate != today else { return }
        lastGreetingDate = today
        let hour = Calendar.current.component(.hour, from: Date())
        let greet: String
        if hour < 11 {
            greet = "早上好，我已经上线陪你啦。"
        } else if hour < 17 {
            greet = "下午好，想先聊天、翻译还是学习？"
        } else {
            greet = "晚上好，辛苦一天了，我陪你放松一下。"
        }
        messages.append(StackChanMessage(role: .assistant, text: greet))
        persistMessages()
    }

    private var activeInputLanguage: StackChanLanguageOption {
        StackChanLanguageOption(localeCode: inputLocaleCode) ?? .chinese
    }

    private func clearConversation() {
        stopListening()
        SpeechService.shared.stopSpeaking()
        conversationId = nil
        errorMessage = nil
        messages = [StackChanMessage(role: .assistant, text: "会话已重置。你好，我是\(petName)机器人。")]
        persistMessages()
    }

    private func loadCachedMessages() {
        guard let data = messageCache.data(using: .utf8),
              let cached = try? JSONDecoder().decode([StackChanMessage].self, from: data),
              !cached.isEmpty else { return }
        messages = cached
    }

    private func persistMessages() {
        guard let data = try? JSONEncoder().encode(messages),
              let text = String(data: data, encoding: .utf8) else { return }
        messageCache = text
    }
}

private struct StackChanFacePanel: View {
    let emotion: StackChanEmotion
    let blink: Bool
    let mouthOpen: Bool
    let gazeX: CGFloat
    let skin: StackChanSkin

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(skin.faceBackground)
                .frame(width: 210, height: 102)

            HStack(spacing: 30) {
                eye
                eye
            }
            .offset(x: gazeX)

            mouth
                .offset(y: 24)
        }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white)
            .frame(width: 24, height: blink ? 4 : 24)
    }

    private var mouth: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(skin.accent.opacity(0.95))
            .frame(width: emotion == .happy ? 34 : 22, height: mouthOpen ? 8 : 3)
    }
}

private enum StackChanRole: String, Codable {
    case user
    case assistant
}

private struct StackChanMessage: Identifiable, Codable {
    let id = UUID()
    let role: StackChanRole
    let text: String
}

private enum StackChanLanguageOption: String, CaseIterable, Identifiable {
    case chinese = "zh-CN"
    case english = "en-US"
    case indonesian = "id-ID"

    var id: String { rawValue }
    var localeCode: String { rawValue }

    var title: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "英语"
        case .indonesian: return "印尼语"
        }
    }

    var shortTitle: String {
        switch self {
        case .chinese: return "中"
        case .english: return "EN"
        case .indonesian: return "印"
        }
    }

    init?(localeCode: String) {
        self.init(rawValue: localeCode)
    }
}

private enum StackChanAPI {
    static let systemPrompt = "你是“豆豆”，一个可爱、简短、像机器人宠物一样陪伴用户的助手。回答要友好、口语化、温暖，尽量不超过两句话；必要时先给结论再补一句建议。"

    static func chat(message: String, conversationId: String?) async throws -> (conversationId: String?, reply: String) {
        let base = ServerConfigStore.shared.baseURLString
        let endpoint = base.hasSuffix("/") ? base + "api/chat" : base + "/api/chat"
        guard let url = URL(string: endpoint) else {
            throw APIClientError.serverError("无效的接口地址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        var body: [String: Any] = [
            "message": message,
            "systemPrompt": systemPrompt,
            "role": "pet_robot"
        ]
        let petName = UserDefaults.standard.string(forKey: "stack_chan_pet_name") ?? "豆豆"
        let favoriteTopic = UserDefaults.standard.string(forKey: "stack_chan_favorite_topic") ?? "聊天"
        body["memory"] = [
            "petName": petName,
            "favoriteTopic": favoriteTopic
        ]
        if let conversationId, !conversationId.isEmpty {
            body["conversationId"] = conversationId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let text = String(data: data, encoding: .utf8) ?? "接口请求失败"
            throw APIClientError.serverError(text)
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let choices = object["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (object["conversationId"] as? String, content)
            }

            let reply = (object["reply"] as? String)
                ?? (object["text"] as? String)
                ?? (object["message"] as? String)
                ?? ""
            let cid = object["conversationId"] as? String
            if !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (cid, reply)
            }
        }

        if let rawText = String(data: data, encoding: .utf8),
           !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (conversationId, rawText)
        }
        throw APIClientError.serverError("接口返回为空")
    }
}

private enum StackChanDateUtil {
    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct StackChanPetEvent: Identifiable {
    let id: String
    let title: String
    let detail: String
    let reward: Int

    static let library: [StackChanPetEvent] = [
        .init(id: "e1", title: "晨间问候", detail: "对豆豆说一句早安，开始今天的陪伴。", reward: 5),
        .init(id: "e2", title: "口语挑战", detail: "和豆豆完成 1 句英语口语练习。", reward: 8),
        .init(id: "e3", title: "翻译训练", detail: "让豆豆帮你翻译一条短句。", reward: 6),
        .init(id: "e4", title: "情绪安抚", detail: "向豆豆倾诉今天的一件小烦恼。", reward: 7),
        .init(id: "e5", title: "学习打卡", detail: "问豆豆一个学习问题并记录答案。", reward: 9)
    ]
}

private struct StackChanPetRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var petName: String
    @Binding var favoriteTopic: String
    @Binding var petPoints: Int
    @Binding var streakDays: Int
    @Binding var dailyChatCount: Int
    let dailyGoal: Int
    @Binding var badgeChatNovice: Bool
    @Binding var badgeStreak7: Bool
    @Binding var badgePetLover: Bool
    @Binding var skinRawValue: String
    @AppStorage("stack_chan_skin_mint_unlocked") private var skinMintUnlocked = false
    @AppStorage("stack_chan_skin_sunset_unlocked") private var skinSunsetUnlocked = false

    @State private var energy: Int = 70
    @State private var mood: Int = 80

    private var currentSkin: StackChanSkin {
        StackChanSkin(rawValue: skinRawValue) ?? .classic
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.86, green: 0.93, blue: 1.0), Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 180)
                        .overlay {
                            VStack(spacing: 8) {
                                StackChanFacePanel(emotion: .happy, blink: false, mouthOpen: false, gazeX: 0, skin: currentSkin)
                                Text("\(petName) 的房间")
                                    .font(.headline.weight(.semibold))
                            }
                        }

                    VStack(spacing: 10) {
                        statRow("亲密度", "\(petPoints)")
                        statRow("连续陪伴", "\(streakDays) 天")
                        statRow("最爱话题", favoriteTopic)
                        statRow("体力", "\(energy)%")
                        statRow("心情", "\(mood)%")
                        statRow("今日互动", "\(dailyChatCount)/\(dailyGoal)")
                    }
                    .padding(14)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("成就墙")
                            .font(.subheadline.weight(.bold))
                        HStack(spacing: 8) {
                            badgeCell("新手聊天", unlocked: badgeChatNovice)
                            badgeCell("7日陪伴", unlocked: badgeStreak7)
                            badgeCell("宠物达人", unlocked: badgePetLover)
                        }
                    }
                    .padding(14)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("皮肤工坊")
                            .font(.subheadline.weight(.bold))
                        skinShopRow(
                            skin: .classic,
                            description: "默认外观",
                            cost: 0,
                            unlocked: true
                        )
                        skinShopRow(
                            skin: .mint,
                            description: "清新绿色主题",
                            cost: 40,
                            unlocked: skinMintUnlocked
                        )
                        skinShopRow(
                            skin: .sunset,
                            description: "暖色晚霞主题",
                            cost: 80,
                            unlocked: skinSunsetUnlocked
                        )
                    }
                    .padding(14)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack(spacing: 10) {
                        actionButton("喂食", "fork.knife") {
                            energy = min(energy + 12, 100)
                            mood = min(mood + 5, 100)
                            petPoints += 2
                        }
                        actionButton("玩耍", "figure.play") {
                            energy = max(energy - 8, 0)
                            mood = min(mood + 12, 100)
                            petPoints += 3
                        }
                        actionButton("休息", "bed.double.fill") {
                            energy = min(energy + 18, 100)
                            mood = min(mood + 8, 100)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("宠物房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func badgeCell(_ title: String, unlocked: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: unlocked ? "rosette" : "lock")
                .font(.system(size: 14, weight: .bold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(unlocked ? Color.orange : AppTheme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(unlocked ? Color.orange.opacity(0.12) : AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func skinShopRow(
        skin: StackChanSkin,
        description: String,
        cost: Int,
        unlocked: Bool
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(skin.faceBackground)
                .frame(width: 44, height: 34)
                .overlay(
                    HStack(spacing: 4) {
                        Circle().fill(Color.white).frame(width: 5, height: 5)
                        Circle().fill(Color.white).frame(width: 5, height: 5)
                    }
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(skin.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()

            Button {
                applyOrUnlockSkin(skin, cost: cost, unlocked: unlocked)
            } label: {
                Text(currentSkin == skin ? "使用中" : (unlocked ? "使用" : "解锁 \(cost)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(currentSkin == skin ? Color.gray : skin.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(currentSkin == skin)
        }
        .padding(10)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func applyOrUnlockSkin(_ skin: StackChanSkin, cost: Int, unlocked: Bool) {
        if skin == .classic {
            skinRawValue = StackChanSkin.classic.rawValue
            return
        }
        if unlocked {
            skinRawValue = skin.rawValue
            return
        }
        guard petPoints >= cost else { return }
        petPoints -= cost
        if skin == .mint { skinMintUnlocked = true }
        if skin == .sunset { skinSunsetUnlocked = true }
        skinRawValue = skin.rawValue
    }
}

private extension View {
    var sectionContainerStyle: some View {
        self
            .padding(14)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

private struct AssistantQuickStartView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                assistantQuickCard

                VStack(alignment: .leading, spacing: 10) {
                    Text("推荐入口")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    NavigationLink {
                        AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
                    } label: {
                        quickRow("开始对话", "立即进入 AI 助理聊天", "message.fill")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WritingStudioView()
                    } label: {
                        quickRow("写作创作", "文章、润色、扩写", "square.and.pencil")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RealTimeTranslationView()
                    } label: {
                        quickRow("实时语音翻译", "边说边译，双语输出", "waveform.badge.mic")
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var assistantQuickCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.74, green: 0.83, blue: 1.0))
                        .frame(width: 46, height: 46)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0.26, green: 0.38, blue: 0.93))
                }
                Text("你好，我是小酱问问～")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                tagPill("学习问答")
                tagPill("模拟面试")
                tagPill("文章创作")
            }

            NavigationLink {
                AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
            } label: {
                HStack(spacing: 10) {
                    Text("点击输入聊天内容")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 38, height: 38)
                        .background(Color(red: 0.92, green: 0.95, blue: 1.0))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.37, green: 0.36, blue: 0.95), lineWidth: 1.8)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.81, green: 0.88, blue: 1.0), Color(red: 0.82, green: 0.92, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())
    }

    private func quickRow(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 30, height: 30)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(12)
        .background(Color(red: 0.93, green: 0.96, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AssistantServiceSearchView: View {
    @State private var keyword = ""
    private let items = ["AI助理", "翻译", "学习辅导", "写作创作", "PPT生成", "会议总结", "语音速记", "文档分析"]

    private var filtered: [String] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        List {
            ForEach(filtered, id: \.self) { item in
                NavigationLink {
                    AIAssistantChatView(title: item, allowLocalExecution: false)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppTheme.primary)
                        Text(item)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
        }
        .searchable(text: $keyword, prompt: "搜索服务/能力")
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct AssistantHistoryView: View {
    private let threads: [ChatThread] = [
        ChatThread(id: "h1", title: "AI助理", preview: "请总结今天工作重点", time: "今天", systemImage: "brain.head.profile", tint: .blue, tags: ["已完成"]),
        ChatThread(id: "h2", title: "翻译", preview: "把会议内容翻译成中文", time: "昨天", systemImage: "character.bubble", tint: .indigo, tags: ["常用"]),
        ChatThread(id: "h3", title: "学习", preview: "整理印尼语高频短句", time: "周五", systemImage: "book.fill", tint: .green, tags: ["收藏"])
    ]

    var body: some View {
        ScrollView {
            ChatThreadSection(threads: threads)
                .padding(16)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
