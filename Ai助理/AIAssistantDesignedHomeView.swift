import SwiftUI
import UniformTypeIdentifiers

struct AIAssistantDesignedHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var inputText = ""
    @State private var showSearch = false
    @State private var showHistory = false
    @State private var showFeatureHub = false
    @State private var showAudioImporter = false
    @State private var showVideoImporter = false
    @State private var showTranslateFromImport = false
    @State private var isImportingMedia = false
    @State private var importStatusText: String?
    @State private var importAlertMessage: String?

    private let topTags = ["学习问答", "模拟面试", "文章创作"]
    private let learningTiles: [AssistantLearningTile] = [
        .init(title: "AI解题", subtitle: "有解析，有步骤", icon: "checkmark.seal.fill", tint: Color(red: 0.85, green: 0.93, blue: 1.0), destination: .chat),
        .init(title: "AI写作文", subtitle: "每一篇都不一样", icon: "square.and.pencil", tint: Color(red: 1.0, green: 0.93, blue: 0.86), destination: .writing),
        .init(title: "英语写作", subtitle: "中英对照，句句精彩", icon: "character.book.closed.fill", tint: Color(red: 0.98, green: 0.90, blue: 0.96), destination: .chat),
        .init(title: "话题/游戏", subtitle: "和AI伙伴边学边玩", icon: "gamecontroller.fill", tint: Color(red: 0.85, green: 0.97, blue: 1.0), destination: .chat),
        .init(title: "作业批改", subtitle: "错题有讲解，不懂接着问", icon: "doc.text.magnifyingglass", tint: Color(red: 0.85, green: 0.98, blue: 0.92), destination: .chat),
        .init(title: "英语翻译", subtitle: "不用打字，一拍就翻", icon: "globe.asia.australia.fill", tint: Color(red: 0.92, green: 0.90, blue: 0.99), destination: .translate)
    ]

    private let writingTools: [AssistantToolItem] = [
        .init(title: "全文生成", icon: "doc.text", tint: Color(red: 0.89, green: 0.93, blue: 1.0), destination: .writing),
        .init(title: "PPT生成", icon: "rectangle.stack", tint: Color(red: 0.98, green: 0.91, blue: 0.95), destination: .ppt),
        .init(title: "改写润色", icon: "pencil.and.outline", tint: Color(red: 0.98, green: 0.92, blue: 0.96), destination: .chat),
        .init(title: "单句扩写", icon: "wand.and.stars", tint: Color(red: 0.88, green: 0.97, blue: 1.0), destination: .chat),
        .init(title: "文章续写", icon: "arrow.triangle.branch", tint: Color(red: 0.88, green: 0.97, blue: 1.0), destination: .chat)
    ]

    private let careerTools: [String] = ["职业规划", "简历优化", "简历生成", "模拟面试"]
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                topBar
                heroCard
                importMediaSection
                learningDiscoverySection
                toolSection(title: "辅助·智能写作", items: writingTools)
                compactSection(title: "辅助·就业实习", items: careerTools)
                quickEntrySection
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: pageMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("AI助理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFeatureHub = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
            }
        }
        .navigationDestination(isPresented: $showSearch) {
            AssistantServiceSearchView()
        }
        .navigationDestination(isPresented: $showHistory) {
            AssistantHistoryView()
        }
        .navigationDestination(isPresented: $showFeatureHub) {
            FeatureHubView()
        }
        .navigationDestination(isPresented: $showTranslateFromImport) {
            AITranslateHomeView()
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
                iconTopButton(system: "magnifyingglass", label: "搜索") {
                    showSearch = true
                }
                iconTopButton(system: "clock", label: "历史") {
                    showHistory = true
                }
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

    private var heroCard: some View {
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
            }

            NavigationLink {
                AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
            } label: {
                HStack(spacing: 10) {
                    Text(inputText.isEmpty ? "点击输入聊天内容" : inputText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(inputText.isEmpty ? AppTheme.textTertiary : AppTheme.textPrimary)
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

    private var quickEntrySection: some View {
        HStack(spacing: 10) {
            quickEntryButton(
                title: "翻译",
                subtitle: "文本双语互译",
                icon: "character.bubble",
                tint: Color(red: 0.83, green: 0.92, blue: 1.0)
            ) {
                AITranslateHomeView()
            }
            quickEntryButton(
                title: "实时翻译",
                subtitle: "对话边说边译",
                icon: "waveform",
                tint: Color(red: 0.88, green: 0.95, blue: 1.0)
            ) {
                RealTimeTranslationView()
            }
            quickEntryButton(
                title: "学习",
                subtitle: "词汇短句训练",
                icon: "book.fill",
                tint: Color(red: 0.90, green: 0.95, blue: 1.0)
            ) {
                IndonesianLearningView()
            }
        }
    }

    private var importMediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("语音导入与转写")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 10) {
                importButton(
                    title: "导入音频",
                    subtitle: "本地音频转写",
                    icon: "music.note",
                    tint: Color(red: 0.32, green: 0.69, blue: 0.97)
                ) {
                    showAudioImporter = true
                }
                importButton(
                    title: "导入视频",
                    subtitle: "视频音轨转写",
                    icon: "video.fill",
                    tint: Color(red: 0.47, green: 0.56, blue: 0.98)
                ) {
                    showVideoImporter = true
                }
            }

            if isImportingMedia {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(importStatusText ?? "处理中...")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func importButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(10)
            .background(tint.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var learningDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("有问题，快问AI")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("学习助手 · 词汇/短句/场景练习")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surface)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.92, green: 0.96, blue: 1.0))
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(learningTiles) { tile in
                    NavigationLink {
                        learningDestination(tile.destination)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: tile.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(tile.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(tile.subtitle)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                        .padding(12)
                        .background(tile.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func quickEntryButton<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .buttonStyle(.plain)
    }

    private func toolSection(title: String, items: [AssistantToolItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items) { item in
                    NavigationLink {
                        destinationView(item.destination)
                    } label: {
                        HStack {
                            Text(item.title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(item.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func compactSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func destinationView(_ destination: AssistantEntryDestination) -> some View {
        switch destination {
        case .chat:
            AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
        case .writing:
            WritingStudioView()
        case .ppt:
            PPTStudioView()
        }
    }

    @ViewBuilder
    private func learningDestination(_ destination: AssistantLearningDestination) -> some View {
        switch destination {
        case .chat:
            AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
        case .writing:
            WritingStudioView()
        case .translate:
            AITranslateHomeView()
        }
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
    }
}

private struct AssistantToolItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let destination: AssistantEntryDestination
}

private enum AssistantEntryDestination {
    case chat
    case writing
    case ppt
}

private struct AssistantLearningTile: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let destination: AssistantLearningDestination
}

private enum AssistantLearningDestination {
    case chat
    case writing
    case translate
}
