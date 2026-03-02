import SwiftUI

struct AIAssistantDesignedHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSearch = false
    @State private var showHistory = false
    @State private var showWritingStudio = false
    @State private var showPPTStudio = false
    @State private var showNotesWorkspace = false
    @State private var showSummaryWorkspace = false
    @State private var showRealtimeTranslate = false
    @State private var showTranslateHome = false
    @State private var showLearningHome = false
    @State private var showAssistantChat = false

    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                topBar
                languageSection
                creationSection
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
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showHistory) {
            AssistantHistoryView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showWritingStudio) {
            WritingStudioView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showPPTStudio) {
            PPTStudioView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showNotesWorkspace) {
            NotesWorkspaceView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showSummaryWorkspace) {
            SummaryWorkspaceView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showRealtimeTranslate) {
            RealTimeTranslationView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showTranslateHome) {
            AITranslateHomeView()
                .navigationTitle("翻译")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showLearningHome) {
            IndonesianLearningView()
                .navigationTitle("学习")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showAssistantChat) {
            AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
                .toolbar(.hidden, for: .tabBar)
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
