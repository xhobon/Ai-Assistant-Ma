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
            Button {
                showStackChanDialog = true
            } label: {
                StackChanFloatingIcon()
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18)
            .padding(.bottom, 96)
            .accessibilityLabel("打开 Stack-chan 助手")
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

private struct StackChanFloatingIcon: View {
    @State private var blink = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 58, height: 58)
                .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 5)

            HStack(spacing: 10) {
                eyeView
                eyeView
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Int.random(in: 1_600_000_000...3_200_000_000)))
                withAnimation(.easeInOut(duration: 0.12)) { blink = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeInOut(duration: 0.12)) { blink = false }
            }
        }
    }

    private var eyeView: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white)
            .frame(width: 11, height: blink ? 2.5 : 11)
    }
}

private struct StackChanDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [StackChanMessage] = [
        StackChanMessage(role: .assistant, text: "嗨，我是豆豆助手。点麦克风说话，或直接打字问我。")
    ]
    @State private var inputText = ""
    @State private var isSending = false
    @State private var isListening = false
    @State private var errorMessage: String?
    @State private var conversationId: String?
    @State private var transcriber = SpeechTranscriber()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { message in
                                bubble(message)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: messages.count) { _, _ in
                        guard let last = messages.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }

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

                    TextField("和豆豆助手说点什么...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Stack-chan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        SpeechService.shared.stopSpeaking()
                        stopListening()
                        dismiss()
                    }
                }
            }
        }
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

    private func toggleListening() {
        if isListening {
            stopListening()
            return
        }
        Task { await startListening() }
    }

    @MainActor
    private func startListening() async {
        SpeechService.shared.stopSpeaking()
        errorMessage = nil
        do {
            let granted = await transcriber.requestAuthorization()
            guard granted else {
                errorMessage = "请在系统设置中允许语音识别权限"
                return
            }
            try transcriber.startTranscribing(locale: Locale(identifier: "zh-CN")) { text, isFinal in
                Task { @MainActor in
                    if !text.isEmpty { inputText = text }
                    if isFinal { isListening = false }
                }
            }
            isListening = true
        } catch {
            errorMessage = userFacingMessage(for: error)
            isListening = false
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
        inputText = ""
        messages.append(StackChanMessage(role: .user, text: text))

        do {
            let response = try await StackChanAPI.chat(message: text, conversationId: conversationId)
            conversationId = response.conversationId ?? conversationId
            messages.append(StackChanMessage(role: .assistant, text: response.reply))
            SpeechService.shared.speak(response.reply, language: "zh-CN")
        } catch {
            let msg = userFacingMessage(for: error)
            errorMessage = msg
            messages.append(StackChanMessage(role: .assistant, text: "我刚刚有点走神了，请再试一次。"))
        }
        isSending = false
    }
}

private enum StackChanRole {
    case user
    case assistant
}

private struct StackChanMessage: Identifiable {
    let id = UUID()
    let role: StackChanRole
    let text: String
}

private enum StackChanAPI {
    static let systemPrompt = "你是一个可爱、简短的机器人助手。回答要友好、简洁，尽量不超过两句话。"

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
            "systemPrompt": systemPrompt
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
