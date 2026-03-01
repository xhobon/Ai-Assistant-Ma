import SwiftUI
import UniformTypeIdentifiers

struct AIAssistantDesignedHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSearch = false
    @State private var showHistory = false
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
            showAssistantChat = true
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
