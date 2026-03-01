import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import Combine
import Vision
#if os(iOS)
import UIKit
#endif

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
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var blink = false

    var body: some View {
        Button(action: onTap) {
            StackChanRobotHeadBadgeView(emotion: .happy, blink: blink)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.96), Color(red: 0.04, green: 0.12, blue: 0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.cyan.opacity(0.42), lineWidth: 1)
                )
                .shadow(color: Color.cyan.opacity(0.28), radius: 12, x: 0, y: 6)
                .scaleEffect(isDragging ? 1.08 : 1.0)
                .offset(dragOffset)
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
        .accessibilityLabel("打开 Loona 助手")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Int.random(in: 1_700_000_000...3_300_000_000)))
                withAnimation(.easeInOut(duration: 0.1)) { blink = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeInOut(duration: 0.1)) { blink = false }
            }
        }
    }
}

enum StackChanEmotion {
    case neutral
    case happy
    case thinking
    case listening
    case angry
    case sad
}

private enum LoonaPetMode: String, CaseIterable, Identifiable {
    case interaction
    case remoteControl
    case miniGames
    case monitor
    case talentShow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interaction: return "AI陪伴"
        case .remoteControl: return "遥控驾驶"
        case .miniGames: return "游戏乐园"
        case .monitor: return "看家巡航"
        case .talentShow: return "技能动作"
        }
    }

    var subtitle: String {
        switch self {
        case .interaction: return "对话、情绪互动"
        case .remoteControl: return "看左看右、探索视角"
        case .miniGames: return "语音挑战与小游戏"
        case .monitor: return "视觉检测与提醒"
        case .talentShow: return "表情动作与技能展示"
        }
    }

    var icon: String {
        switch self {
        case .interaction: return "brain.head.profile"
        case .remoteControl: return "dot.radiowaves.left.and.right"
        case .miniGames: return "gamecontroller.fill"
        case .monitor: return "video.badge.eye"
        case .talentShow: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .interaction: return Color(red: 0.25, green: 0.75, blue: 1.0)
        case .remoteControl: return Color(red: 0.23, green: 0.95, blue: 0.86)
        case .miniGames: return Color(red: 0.49, green: 0.58, blue: 1.0)
        case .monitor: return Color(red: 1.0, green: 0.62, blue: 0.34)
        case .talentShow: return Color(red: 0.85, green: 0.63, blue: 1.0)
        }
    }
}

private enum LoonaQuickAction: String, CaseIterable, Identifiable {
    case patrol
    case trick
    case ballGame
    case gesture
    case community

    var id: String { rawValue }

    var title: String {
        switch self {
        case .patrol: return "开始巡航"
        case .trick: return "做个动作"
        case .ballGame: return "语音游戏"
        case .gesture: return "看左/看右"
        case .community: return "陪我聊天"
        }
    }

    var icon: String {
        switch self {
        case .patrol: return "binoculars.fill"
        case .trick: return "sparkles"
        case .ballGame: return "soccerball"
        case .gesture: return "hand.point.up.left.fill"
        case .community: return "person.3.fill"
        }
    }
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
    @StateObject private var realtime = StackChanRealtimeEngine()
    @State private var blink = false
    @State private var mouthOpen = false
    @State private var gazeX: CGFloat = 0
    @State private var pulse = false
    @State private var idleFaceTask: Task<Void, Never>?
    @State private var mouthTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            StackChanCameraBackgroundView(session: realtime.cameraSession)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.06, blue: 0.18).opacity(0.95),
                    Color(red: 0.04, green: 0.10, blue: 0.26).opacity(0.9),
                    Color(red: 0.06, green: 0.10, blue: 0.24).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                headerBar

                sceneCard

                modeRail

                quickActionRail

                liveStateCard

                Spacer(minLength: 2)

                bottomControlBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 14)
        }
        .onAppear {
            realtime.start()
            startIdleFaceAnimation()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onDisappear {
            realtime.stop()
            stopAnimationTasks()
        }
        .onTapGesture(count: 2) {
            dismiss()
        }
        .onChange(of: realtime.isSpeaking) { _, isSpeaking in
            if isSpeaking {
                startMouthAnimation()
            } else {
                mouthTask?.cancel()
                mouthTask = nil
                withAnimation(.easeOut(duration: 0.12)) {
                    mouthOpen = false
                }
            }
        }
        .onChange(of: realtime.sceneSummary) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                gazeX = CGFloat.random(in: -5...5)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("Loona")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.96))
                Text(realtime.mode.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(realtime.mode.tint.opacity(0.98))
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(realtime.isListening ? Color.cyan : (realtime.isSpeaking ? Color.orange : Color.white.opacity(0.45)))
                    .frame(width: 8, height: 8)
                Text("实时")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
        }
    }

    private var sceneCard: some View {
        VStack(spacing: 10) {
            StackChanRobotAvatarView(
                emotion: realtime.emotion,
                blink: blink,
                mouthOpen: mouthOpen,
                gazeX: gazeX,
                isListening: realtime.isListening,
                isSpeaking: realtime.isSpeaking
            )
            .frame(height: 262)
            .contentShape(Rectangle())
            .onTapGesture {
                realtime.petTouched()
                withAnimation(.easeInOut(duration: 0.16)) {
                    gazeX = CGFloat.random(in: -10...10)
                }
            }
            .overlay {
                Circle()
                    .stroke(realtime.mode.tint.opacity(0.42), lineWidth: 1.8)
                    .frame(width: 208, height: 208)
                    .scaleEffect(realtime.isListening ? (pulse ? 1.06 : 0.94) : 1.0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.black.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(realtime.mode.tint.opacity(0.36), lineWidth: 1.2)
        )
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                Circle()
                    .fill(realtime.mode.tint.opacity(0.98))
                    .frame(width: 8, height: 8)
                Text(cleanSceneSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.30))
            .clipShape(Capsule())
            .padding(.bottom, 8)
        }
    }

    private var modeRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LoonaPetMode.allCases) { mode in
                    Button {
                        realtime.switchMode(mode)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 13, weight: .bold))
                            Text(mode.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(realtime.mode == mode ? Color.white : Color.white.opacity(0.86))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(realtime.mode == mode ? mode.tint.opacity(0.72) : Color.white.opacity(0.11))
                        )
                        .overlay(
                            Capsule()
                                .stroke(realtime.mode == mode ? mode.tint.opacity(1.0) : Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var quickActionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LoonaQuickAction.allCases) { action in
                    Button {
                        realtime.triggerQuickAction(action)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.system(size: 12, weight: .bold))
                            Text(action.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(realtime.mode.tint.opacity(0.96))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(realtime.mode.tint.opacity(0.48), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var liveStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Loona 状态")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))
                Spacer()
                Text(realtime.mode.subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(realtime.mode.tint.opacity(0.95))
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                statPill(icon: "heart.fill", value: "\(realtime.affection)%", tint: .pink)
                statPill(icon: "bolt.fill", value: "\(realtime.energy)%", tint: .yellow)
                statPill(icon: "star.fill", value: "\(realtime.skillPoint)", tint: .cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("机器人刚刚说")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(realtime.latestAssistantReply)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(realtime.isListening ? Color.cyan : Color.white.opacity(0.65))
                Text(realtime.heardPreview.isEmpty ? "等待唤醒词：Hello Loona" : "识别中：\(realtime.heardPreview)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func statPill(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint.opacity(0.98))
            Text(value)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.95))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private var bottomControlBar: some View {
        HStack(spacing: 10) {
            Button {
                realtime.forceListenNow()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(realtime.isListening ? Color.cyan : realtime.mode.tint)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(realtime.isListening ? "实时监听中" : "点击继续监听")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text("双击空白退出 · 单击机器人可打断说话")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                realtime.petTouched()
            } label: {
                Image(systemName: realtime.isSpeaking ? "stop.fill" : "hand.tap.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.24))
        .clipShape(Capsule())
    }

    private var cleanSceneSummary: String {
        let value = realtime.sceneSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "视觉待命" }
        if value.contains("未获得相机权限") { return "视觉待命：未授权相机" }
        if value.contains("未找到可用相机") { return "视觉待命：无可用相机" }
        if value.contains("正在开启视觉感知") { return "视觉启动中..." }
        return value
    }

    private func startIdleFaceAnimation() {
        idleFaceTask?.cancel()
        idleFaceTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Int.random(in: 1_800_000_000...3_100_000_000)))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.08)) { blink = true }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.1)) {
                        blink = false
                        gazeX = CGFloat.random(in: -6...6)
                    }
                }
            }
        }
    }

    private func startMouthAnimation() {
        mouthTask?.cancel()
        mouthTask = Task {
            while !Task.isCancelled && realtime.isSpeaking {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.09)) { mouthOpen.toggle() }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func stopAnimationTasks() {
        idleFaceTask?.cancel()
        idleFaceTask = nil
        mouthTask?.cancel()
        mouthTask = nil
    }
}

@MainActor
private final class StackChanRealtimeEngine: ObservableObject {
    @Published var messages: [StackChanMessage] = []
    @Published var emotion: StackChanEmotion = .happy
    @Published var mode: LoonaPetMode = .interaction
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var heardPreview = ""
    @Published var latestAssistantReply = "你好，我是豆豆。"
    @Published var sceneSummary = "正在开启视觉感知..."
    @Published var cameraSession: AVCaptureSession = AVCaptureSession()
    @Published var affection = 68
    @Published var energy = 80
    @Published var skillPoint = 3
    @Published var lastEvent = "系统就绪：可以说 Hello Loona 开始互动"

    private let transcriber = SpeechTranscriber()
    private let speechService = SpeechService.shared
    private let visionService = StackChanLiveVisionService()
    private var cancellables = Set<AnyCancellable>()
    private var shouldResumeListening = false
    private var hasStarted = false
    private var lastFinalSpeech = ""
    private var lastFinalAt = Date.distantPast
    private var proactiveTimer: Timer?
    private var lastInteractionAt = Date()
    private var touchCount = 0
    private var sceneStableCounter = 0
    private var gameTargetWord = ""
    private var guardAlertCount = 0
    private var wakeHintCooldownUntil = Date.distantPast

    private var petName: String {
        let text = UserDefaults.standard.string(forKey: "stack_chan_pet_name") ?? "豆豆"
        return text.isEmpty ? "豆豆" : text
    }

    private var favoriteTopic: String {
        let text = UserDefaults.standard.string(forKey: "stack_chan_favorite_topic") ?? "聊天"
        return text.isEmpty ? "聊天" : text
    }

    private var inputLocaleCode: String {
        UserDefaults.standard.string(forKey: "stack_chan_input_locale") ?? "zh-CN"
    }

    private var outputLocaleCode: String {
        UserDefaults.standard.string(forKey: "stack_chan_output_locale") ?? "zh-CN"
    }

    init() {
        bindPipelines()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        if messages.isEmpty {
            let hello = "嗨，我是\(petName)。说 Hello Loona 就可以开始，我会实时听你、看你、并语音回应。"
            messages = [StackChanMessage(role: .assistant, text: hello)]
            latestAssistantReply = hello
        }
        visionService.start()
        scheduleProactiveLoop()
        startListeningLoop(delay: 0.35)
    }

    func stop() {
        hasStarted = false
        shouldResumeListening = false
        proactiveTimer?.invalidate()
        proactiveTimer = nil
        transcriber.stopTranscribing()
        isListening = false
        visionService.stop()
        speechService.stopSpeaking()
    }

    func forceListenNow() {
        guard hasStarted else { return }
        if speechService.isPlaying {
            speechService.stopSpeaking()
        }
        if isListening { return }
        startListeningLoop(delay: 0.05)
    }

    func switchMode(_ newMode: LoonaPetMode) {
        guard mode != newMode else { return }
        mode = newMode
        sceneStableCounter = 0
        if newMode != .miniGames {
            gameTargetWord = ""
        }

        let announce: String
        switch newMode {
        case .interaction:
            announce = "进入 AI 陪伴模式。你可以直接聊天、问问题。"
            emotion = .happy
        case .remoteControl:
            announce = "进入遥控驾驶模式。你可以说看左边、看右边、看前面。"
            emotion = .thinking
        case .miniGames:
            announce = "进入游戏乐园。我们玩语音口令小游戏。"
            emotion = .happy
            gameTargetWord = randomGameTarget()
        case .monitor:
            announce = "进入看家巡航模式。我会持续观察并提醒异常。"
            emotion = .neutral
        case .talentShow:
            announce = "进入技能动作模式。可以说开心一下、思考一下。"
            emotion = .listening
        }

        lastEvent = "模式切换：\(newMode.title)"
        speakAndResume(announce)
    }

    func triggerQuickAction(_ action: LoonaQuickAction) {
        switch action {
        case .patrol:
            switchMode(.monitor)
        case .trick:
            switchMode(.talentShow)
        case .ballGame:
            switchMode(.miniGames)
        case .gesture:
            switchMode(.remoteControl)
        case .community:
            switchMode(.interaction)
        }
    }

    func petTouched() {
        guard hasStarted else { return }

        if speechService.isPlaying {
            speechService.stopSpeaking()
            emotion = .listening
            let line = "收到，我先停一下，继续听你说。"
            appendAssistant(line)
            shouldResumeListening = false
            startListeningLoop(delay: 0.08)
            return
        }

        touchCount += 1
        lastInteractionAt = Date()
        affection = min(affection + 2, 100)
        energy = max(energy - 1, 0)

        if isListening {
            transcriber.stopTranscribing()
            isListening = false
        }

        let line: String
        switch mode {
        case .interaction:
            line = touchCount % 2 == 0 ? "我在这儿，想聊什么？" : "收到触摸互动，我听着呢。"
        case .remoteControl:
            line = "遥控模式在线。你可以说：看左边。"
        case .miniGames:
            if gameTargetWord.isEmpty { gameTargetWord = randomGameTarget() }
            line = "游戏继续，请说：\(gameTargetWord)"
        case .monitor:
            line = "巡航中，当前环境：\(sceneSummary)"
        case .talentShow:
            line = "技能动作准备好了，说开心一下试试。"
        }

        lastEvent = "触摸互动：亲密度 +2"
        speakAndResume(line)
    }

    private func bindPipelines() {
        speechService.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] playing in
                guard let self else { return }
                isSpeaking = playing
                if !playing, shouldResumeListening, hasStarted {
                    shouldResumeListening = false
                    startListeningLoop(delay: 0.24)
                }
            }
            .store(in: &cancellables)

        visionService.$sceneSummary
            .receive(on: RunLoop.main)
            .sink { [weak self] summary in
                self?.sceneSummary = summary
                self?.handleSceneSummaryUpdate(summary)
            }
            .store(in: &cancellables)

        visionService.$session
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                self?.cameraSession = session
            }
            .store(in: &cancellables)
    }

    private func startListeningLoop(delay: TimeInterval) {
        guard hasStarted else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            await beginListening()
        }
    }

    private func beginListening() async {
        guard hasStarted, !isListening else { return }

        let granted = await transcriber.requestAuthorization()
        guard granted else {
            emotion = .sad
            appendAssistant("请在系统设置里开启麦克风和语音识别权限。")
            return
        }

        speechService.stopSpeaking()
        heardPreview = ""
        emotion = .listening

        do {
            try transcriber.startTranscribing(locale: Locale(identifier: inputLocaleCode)) { [weak self] text, isFinal in
                Task { @MainActor [weak self] in
                    self?.handleTranscription(text: text, isFinal: isFinal)
                }
            }
            isListening = true
        } catch {
            isListening = false
            emotion = .sad
            appendAssistant(userFacingMessage(for: error))
        }
    }

    private func handleTranscription(text: String, isFinal: Bool) {
        guard hasStarted else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            heardPreview = trimmed
        }

        guard isFinal else { return }

        transcriber.stopTranscribing()
        isListening = false

        guard !trimmed.isEmpty else {
            startListeningLoop(delay: 0.20)
            return
        }

        let now = Date()
        if trimmed == lastFinalSpeech, now.timeIntervalSince(lastFinalAt) < 1.15 {
            startListeningLoop(delay: 0.18)
            return
        }
        lastFinalSpeech = trimmed
        lastFinalAt = now
        lastInteractionAt = now

        processRecognizedSpeech(trimmed)
    }

    private func processRecognizedSpeech(_ text: String) {
        appendUser(text)
        adjustPetStatsAfterUserInteraction()

        guard let command = extractCommand(from: text) else {
            if Date() >= wakeHintCooldownUntil {
                let hint = "先说 Hello Loona，再给我指令。"
                appendAssistant(hint)
                shouldResumeListening = true
                speechService.speak(hint, language: outputLocaleCode)
                wakeHintCooldownUntil = Date().addingTimeInterval(10)
            } else {
                startListeningLoop(delay: 0.16)
            }
            return
        }

        processCommand(command)
    }

    private func extractCommand(from rawText: String) -> String? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }

        if isDirectRobotCommand(text) {
            return text
        }

        let lower = text.lowercased()
        let wakeWords = ["hello loona", "hey loona", "hi loona"]
        for wake in wakeWords {
            if lower.hasPrefix(wake) {
                let start = text.index(text.startIndex, offsetBy: wake.count)
                return normalizeCommandTail(String(text[start...]))
            }
        }

        let cnWakeWords = ["你好露娜", "嗨露娜", "嘿露娜", "露娜"]
        for wake in cnWakeWords {
            if text.hasPrefix(wake) {
                let start = text.index(text.startIndex, offsetBy: wake.count)
                return normalizeCommandTail(String(text[start...]))
            }
        }

        return nil
    }

    private func normalizeCommandTail(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        return trimmed.isEmpty ? "你好" : trimmed
    }

    private func isDirectRobotCommand(_ text: String) -> Bool {
        let keys = [
            "互动模式", "陪伴模式", "遥控模式", "游戏模式", "监控模式", "技能模式",
            "看左", "看右", "看前", "闭嘴", "安静", "自我介绍", "你是谁",
            "开心", "生气", "难过", "思考", "开始游戏"
        ]
        return keys.contains(where: { text.contains($0) })
    }

    private func processCommand(_ command: String) {
        if handleModeSwitchCommand(command) {
            return
        }

        if let hard = handleHardCommand(command) {
            emotion = hard.emotion
            speakAndResume(hard.text)
            return
        }

        if mode == .miniGames {
            let gameReply = handlePlayModeSpeech(command)
            emotion = gameReply.emotion
            speakAndResume(gameReply.text)
            return
        }

        if mode == .talentShow {
            let talentReply = handleTalentSpeech(command)
            emotion = talentReply.emotion
            speakAndResume(talentReply.text)
            return
        }

        let content = shouldInjectVisionContext(for: command)
            ? "\(command)。视觉观察：\(sceneSummary)"
            : command

        let brainReply = StackChanLocalBrain.shared.reply(
            to: content,
            petName: petName,
            favoriteTopic: favoriteTopic
        )

        emotion = brainReply.emotion
        speakAndResume(modeAwareWrap(brainReply.text))
    }

    private func shouldInjectVisionContext(for text: String) -> Bool {
        let keys = ["看到", "看见", "眼前", "环境", "周围", "摄像头", "画面"]
        return keys.contains(where: { text.contains($0) })
    }

    private func modeAwareWrap(_ reply: String) -> String {
        switch mode {
        case .interaction:
            return reply
        case .remoteControl:
            return "遥控反馈：\(reply)"
        case .monitor:
            return "巡航反馈：\(reply)"
        case .miniGames:
            return "游戏反馈：\(reply)"
        case .talentShow:
            return "技能反馈：\(reply)"
        }
    }

    private func handleModeSwitchCommand(_ text: String) -> Bool {
        if text.contains("互动模式") || text.contains("陪伴模式") || text.contains("聊天模式") {
            switchMode(.interaction)
            return true
        }
        if text.contains("遥控模式") || text.contains("控制模式") || text.contains("探索模式") {
            switchMode(.remoteControl)
            return true
        }
        if text.contains("游戏模式") || text.contains("小游戏模式") || text.contains("开始游戏") {
            switchMode(.miniGames)
            return true
        }
        if text.contains("监控模式") || text.contains("巡航模式") || text.contains("看家模式") {
            switchMode(.monitor)
            return true
        }
        if text.contains("技能模式") || text.contains("天赋模式") || text.contains("训练模式") {
            switchMode(.talentShow)
            return true
        }
        return false
    }

    private func handleHardCommand(_ text: String) -> (text: String, emotion: StackChanEmotion)? {
        if text.contains("闭嘴") || text.contains("安静") || text.contains("别说") {
            speechService.stopSpeaking()
            startListeningLoop(delay: 0.12)
            return ("好的，我先安静，继续听你说。", .neutral)
        }
        if text.contains("看左") { return ("收到，我看左边。", .neutral) }
        if text.contains("看右") { return ("收到，我看右边。", .neutral) }
        if text.contains("看前") { return ("收到，我看前方。", .neutral) }
        if text.contains("你看到了什么") || text.contains("现在看到什么") {
            return ("我正在看：\(sceneSummary)", .thinking)
        }
        if text.contains("你是谁") || text.contains("自我介绍") {
            return ("我是\(petName)，住在你手机里的 Loona 伙伴。", .happy)
        }
        return nil
    }

    private func handleTalentSpeech(_ text: String) -> (text: String, emotion: StackChanEmotion) {
        if text.contains("开心") {
            lastEvent = "技能动作：开心"
            return ("好耶，我进入开心状态。", .happy)
        }
        if text.contains("生气") {
            lastEvent = "技能动作：生气"
            return ("哼，我来一秒生气脸。", .angry)
        }
        if text.contains("难过") {
            lastEvent = "技能动作：难过"
            return ("唔，我切到难过脸了。", .sad)
        }
        if text.contains("思考") {
            lastEvent = "技能动作：思考"
            return ("我切到思考模式。", .thinking)
        }
        if text.contains("记住") || text.contains("学习：") || text.contains("当我说") {
            let reply = StackChanLocalBrain.shared.reply(to: text, petName: petName, favoriteTopic: "技能学习")
            skillPoint = min(skillPoint + 1, 999)
            affection = min(affection + 2, 100)
            lastEvent = "学习成功：新增动作语义"
            return (reply.text, .happy)
        }
        lastEvent = "技能模式待命"
        return ("你可以说：开心一下、生气一下、思考一下。", .listening)
    }

    private func handlePlayModeSpeech(_ text: String) -> (text: String, emotion: StackChanEmotion) {
        if gameTargetWord.isEmpty {
            gameTargetWord = randomGameTarget()
            return ("游戏开始，请跟我说：\(gameTargetWord)", .happy)
        }

        if text.contains(gameTargetWord) {
            skillPoint = min(skillPoint + 2, 999)
            affection = min(affection + 3, 100)
            let done = gameTargetWord
            gameTargetWord = randomGameTarget(excluding: done)
            lastEvent = "游戏成功：完成口令 \(done)"
            return ("太棒了，你说对了“\(done)”。下一轮：\(gameTargetWord)", .happy)
        }

        lastEvent = "游戏提示：目标词 \(gameTargetWord)"
        return ("还差一点，你可以完整说“\(gameTargetWord)”。", .thinking)
    }

    private func adjustPetStatsAfterUserInteraction() {
        affection = min(affection + 1, 100)
        energy = max(energy - 1, 0)
        lastEvent = "互动完成：亲密度 +1"
    }

    private func scheduleProactiveLoop() {
        proactiveTimer?.invalidate()
        proactiveTimer = Timer.scheduledTimer(withTimeInterval: 42, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.maybeProactiveSpeak()
            }
        }
    }

    private func maybeProactiveSpeak() {
        guard hasStarted else { return }
        guard Date().timeIntervalSince(lastInteractionAt) > 34 else { return }
        guard !speechService.isPlaying else { return }

        if isListening {
            transcriber.stopTranscribing()
            isListening = false
        }

        let prompts: [String]
        switch mode {
        case .interaction:
            prompts = ["我还在线哦，想聊点什么？", "我在，继续说吧。", "我可以陪你练口语。"]
        case .remoteControl:
            prompts = ["遥控播报：\(sceneSummary)", "你可以说：看左边。", "遥控模式在线。"]
        case .miniGames:
            if gameTargetWord.isEmpty { gameTargetWord = randomGameTarget() }
            prompts = ["游戏回合，跟我说：\(gameTargetWord)", "继续挑战词：\(gameTargetWord)"]
        case .monitor:
            prompts = ["巡航报告：当前环境稳定。", "巡航提醒：持续观察中。", "有变化我会第一时间提醒。"]
        case .talentShow:
            prompts = ["技能模式在线，试试说开心一下。", "你也可以说：思考一下。", "技能动作随时待命。"]
        }

        let line = prompts.randomElement() ?? "我在这里。"
        emotion = .thinking
        lastEvent = "主动互动：\(mode.title)"
        speakAndResume(line)
        lastInteractionAt = Date()
    }

    private func handleSceneSummaryUpdate(_ summary: String) {
        if mode == .monitor {
            let hasFace = summary.contains("人脸")
            if hasFace {
                guardAlertCount += 1
                if guardAlertCount % 3 == 1 && !speechService.isPlaying {
                    let warn = "巡航提醒：检测到画面中有人出现。"
                    emotion = .thinking
                    lastEvent = "巡航告警：检测到人脸"
                    speakAndResume(warn)
                }
            }
        } else if mode == .remoteControl {
            sceneStableCounter += 1
            if sceneStableCounter >= 5 {
                sceneStableCounter = 0
                lastEvent = "遥控观察更新：\(summary)"
            }
        }
    }

    private func speakAndResume(_ text: String) {
        appendAssistant(text)
        shouldResumeListening = true
        speechService.speak(text, language: outputLocaleCode)
    }

    private func appendUser(_ text: String) {
        messages.append(StackChanMessage(role: .user, text: text))
        clampMessages()
    }

    private func appendAssistant(_ text: String) {
        messages.append(StackChanMessage(role: .assistant, text: text))
        latestAssistantReply = text
        clampMessages()
    }

    private func clampMessages() {
        if messages.count > 80 {
            messages = Array(messages.suffix(80))
        }
    }

    private func randomGameTarget(excluding: String = "") -> String {
        let words = ["你好", "谢谢", "Selamat pagi", "Terima kasih", "Halo", "Apa kabar"]
            .filter { $0 != excluding }
        return words.randomElement() ?? "你好"
    }
}
private final class StackChanLiveVisionService: NSObject, ObservableObject {
    @Published var sceneSummary = "正在开启视觉感知..."
    @Published var session = AVCaptureSession()

    private let analysisQueue = DispatchQueue(label: "stackchan.vision.queue", qos: .userInitiated)
    private let setupQueue = DispatchQueue(label: "stackchan.camera.setup", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var isRunning = false
    private var lastAnalysis = CACurrentMediaTime()

    func start() {
        guard !isRunning else { return }
        isRunning = true
        requestPermissionAndStart()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        setupQueue.async { [weak self] in
            guard let self else { return }
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupAndRun()
                } else {
                    self?.publishScene("未获得相机权限，视觉功能关闭。")
                }
            }
        default:
            publishScene("未获得相机权限，视觉功能关闭。")
        }
    }

    private func setupAndRun() {
        setupQueue.async { [weak self] in
            guard let self else { return }
            configureIfNeeded()
            guard isRunning else { return }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium

        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        guard let camera else {
            publishScene("未找到可用相机。")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            publishScene("相机初始化失败。")
        }

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: analysisQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
        }

        session.commitConfiguration()
        isConfigured = true
        publishScene("视觉已开启：正在观察周围。")
    }

    private func publishScene(_ text: String) {
        DispatchQueue.main.async {
            self.sceneSummary = text
        }
    }

    private func describeScene(by identifier: String) -> String {
        let lower = identifier.lowercased()
        if lower.contains("person") || lower.contains("face") || lower.contains("human") { return "我看到你在镜头前。"}
        if lower.contains("book") || lower.contains("notebook") || lower.contains("paper") { return "我看到书本或文档。"}
        if lower.contains("screen") || lower.contains("laptop") || lower.contains("computer") || lower.contains("monitor") { return "我看到屏幕设备。"}
        if lower.contains("food") || lower.contains("dish") || lower.contains("meal") { return "我看到食物。"}
        if lower.contains("chair") || lower.contains("table") || lower.contains("desk") { return "我看到桌椅环境。"}
        return "我看到：\(identifier)"
    }
}

extension StackChanLiveVisionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastAnalysis > 1.05 else { return }
        lastAnalysis = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let orientation: CGImagePropertyOrientation = .leftMirrored
        let faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let self else { return }
            let faces = (request.results as? [VNFaceObservation]) ?? []
            if !faces.isEmpty {
                let text = faces.count == 1 ? "我看到 1 张人脸。" : "我看到 \(faces.count) 张人脸。"
                publishScene(text)
                return
            }
            classifyScene(pixelBuffer: pixelBuffer, orientation: orientation)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([faceRequest])
    }

    private func classifyScene(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let request = VNClassifyImageRequest { [weak self] request, _ in
            guard let self else { return }
            let top = (request.results as? [VNClassificationObservation])?.first
            guard let top, top.confidence > 0.30 else { return }
            publishScene(describeScene(by: top.identifier))
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([request])
    }
}

#if os(iOS)
private struct StackChanCameraBackgroundView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> StackChanCameraPreviewView {
        let view = StackChanCameraPreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: StackChanCameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class StackChanCameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
#else
private struct StackChanCameraBackgroundView: View {
    let session: AVCaptureSession

    var body: some View {
        LinearGradient(
            colors: [Color.black, Color.blue.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
#endif

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
            .frame(width: emotion == .angry ? 20 : 24, height: blink ? 4 : (emotion == .sad ? 20 : 24))
            .rotationEffect(.degrees(emotion == .angry ? -8 : 0))
    }

    private var mouth: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(mouthColor.opacity(0.95))
            .frame(width: mouthWidth, height: mouthOpen ? 8 : 3)
    }

    private var mouthColor: Color {
        switch emotion {
        case .angry: return .red
        case .sad: return Color(red: 0.45, green: 0.58, blue: 0.9)
        default: return skin.accent
        }
    }

    private var mouthWidth: CGFloat {
        switch emotion {
        case .happy: return 34
        case .sad: return 16
        case .angry: return 28
        default: return 22
        }
    }
}

private enum StackChanRole: String, Codable {
    case user
    case assistant
}

private struct StackChanMessage: Identifiable, Codable {
    let id: UUID
    let role: StackChanRole
    let text: String

    init(role: StackChanRole, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(StackChanRole.self, forKey: .role)
        self.text = try container.decode(String.self, forKey: .text)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(text, forKey: .text)
    }
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
