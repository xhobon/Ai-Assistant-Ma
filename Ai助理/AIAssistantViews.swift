import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import AVFoundation
import Combine
#endif

struct AIAssistantHomeView: View {
    private let services: [AssistantService] = [
        AssistantService(id: "s1", title: "AI智能助理", subtitle: "帮您分析电商数据", tags: ["准确", "专业"], action: "分析", icon: "sparkles"),
        AssistantService(id: "s2", title: "法律顾问", subtitle: "帮您解决任何法律问题", tags: ["专业", "经验丰富"], action: "咨询", icon: "person.text.rectangle"),
        AssistantService(id: "s3", title: "投资顾问", subtitle: "针对您的疑问解惑", tags: ["管理财务", "风险管理"], action: "咨询", icon: "chart.line.uptrend.xyaxis"),
        AssistantService(id: "s4", title: "面试官", subtitle: "为您模拟面试场景", tags: ["岗位丰富", "全面"], action: "面试", icon: "briefcase"),
        AssistantService(id: "s5", title: "AI编程", subtitle: "为您定制软件开发", tags: ["多代码语言"], action: "编写", icon: "curlybraces"),
        AssistantService(id: "s6", title: "营销策划", subtitle: "为您提出详细的方案", tags: ["详细", "完美"], action: "策划", icon: "lightbulb" )
    ]

    private let categories = ["全部", "工作助理", "学习助理", "生活助理"]
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var isAnimating = false

    private var primaryService: AssistantService {
        services[0]
    }

    private var quickServices: [AssistantService] {
        Array(services.prefix(3))
    }

    private var filteredServices: [AssistantService] {
        let filtered = services.filter { service in
            let matchedCategory = selectedCategory == "全部" || category(for: service) == selectedCategory
            let matchedSearch = searchText.isEmpty
                || service.title.localizedCaseInsensitiveContains(searchText)
                || service.subtitle.localizedCaseInsensitiveContains(searchText)
            return matchedCategory && matchedSearch
        }
        return filtered
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 页头
                    TechAIAssistantHeader()
                        .padding(.bottom, ModernDesignSystem.Spacing.sm)
                    
                    // 搜索（与学习页样式、大小一致） + 首页 AI 助理入口
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textTertiary)
                            TextField("搜索AI服务...", text: $searchText)
                                .font(.subheadline)
                                .textFieldStyle(.plain)
                                .foregroundStyle(AppTheme.inputText)
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
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
                        
                        HomePrimaryEntryCard(service: primaryService)
                    }
                    .responsiveContainer()
                    .padding(.bottom, ModernDesignSystem.Spacing.sm)
                    
                    // AI服务网格 - 点击卡片进入对话
                    if filteredServices.isEmpty {
                        ModernCard(style: .glass) {
                            VStack(spacing: ModernDesignSystem.Spacing.md) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundStyle(AppTheme.textTertiary)
                                
                                Text("没有找到匹配的服务")
                                    .font(ModernDesignSystem.Typography.cardTitle)
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text("试试其他关键词或分类")
                                    .font(ModernDesignSystem.Typography.body)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(ModernDesignSystem.Spacing.xl)
                        }
                        .responsiveContainer()
                        .padding(.bottom, ModernDesignSystem.Spacing.lg)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                        ForEach(filteredServices) { service in
                            NavigationLink {
                                AIAssistantChatView(title: service.title, allowLocalExecution: false)
                                } label: {
                                    TechServiceCard(service: service)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .responsiveContainer()
                        .padding(.bottom, ModernDesignSystem.Spacing.xxxl)
                    }
                }
            }
            .scrollIndicators(.automatic)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .hideNavigationBarOnMac()
        }
    }

    private func category(for service: AssistantService) -> String {
        switch service.id {
        case "s1", "s2", "s3":
            return "工作助理"
        case "s4", "s5":
            return "学习助理"
        default:
            return "生活助理"
        }
    }
}

struct AIAssistantHomeHeader: View {
    private let baseHeight: CGFloat = 190

    private var safeTop: CGFloat {
        #if os(iOS)
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 20)
        #elseif os(macOS)
        return 20
        #endif
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    AppTheme.primary.opacity(0.92),
                    AppTheme.primaryVariant.opacity(0.85),
                    AppTheme.secondary.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: baseHeight + safeTop)
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.18), Color.black.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 140, height: 140)
                        .blur(radius: 16)
                        .offset(x: -120, y: -20)
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 180, height: 180)
                        .blur(radius: 22)
                        .offset(x: 160, y: -40)
                }
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI助理")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("随时待命，支持多场景协作")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.88))
                    }

                    Spacer()

                    Text("在线")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("为你安排高效的一天")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("快速进入对话、翻译与学习场景")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.9))
                }

                // 保留组件但不再使用固定假数据（实际首页已使用新版 TechAIAssistantHeader）
            }
            .padding(.horizontal, 20)
            .padding(.top, safeTop + 10)
            .padding(.bottom, 16)
        }
    }
}

struct HomeSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textSecondary)
            TextField("搜索服务/场景/关键词", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow.opacity(0.75), radius: 10, x: 0, y: 6)
    }
}

struct HomeQuickActionStrip: View {
    let primaryService: AssistantService

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                AIAssistantChatView(title: primaryService.title, allowLocalExecution: false)
            } label: {
                HomeQuickActionCard(title: "智能对话", subtitle: "立即开始", systemImage: "sparkles", tint: AppTheme.accentStrong)
            }
            .buttonStyle(.plain)

            NavigationLink {
                AIAssistantChatView(title: primaryService.title, allowLocalExecution: false)
            } label: {
                HomeQuickActionCard(title: "语音助手", subtitle: "点击输入", systemImage: "waveform", tint: AppTheme.accentWarm)
            }
            .buttonStyle(.plain)

            NavigationLink {
                AIAssistantChatView(title: primaryService.title, allowLocalExecution: false)
            } label: {
                HomeQuickActionCard(title: "图像识别", subtitle: "拍照导入", systemImage: "camera.fill", tint: AppTheme.brandBlue)
            }
            .buttonStyle(.plain)
        }
    }
}

struct HomeQuickActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 6) {
                Text("立即进入")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 5)
    }
}

struct HomeInsightCard: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentWarm.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: "bolt.fill")
                    .foregroundStyle(AppTheme.accentWarm)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("建议")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accentWarm)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentWarm.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow, radius: 10, x: 0, y: 6)
    }
}

struct HomeStatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}

struct HomeSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HomePrimaryEntryCard: View {
    let service: AssistantService

    var body: some View {
        NavigationLink {
            AIAssistantChatView(title: service.title, allowLocalExecution: false)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.18))
                            .frame(width: 60, height: 60)
                        Image(systemName: service.icon)
                            .font(.title2)
                            .foregroundStyle(AppTheme.accentStrong)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(service.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("推荐")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accentStrong)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(service.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    ForEach(service.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text("立即\(service.action)")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(AppTheme.accentStrong)
                    .clipShape(Capsule())
                }
            }
            .padding(18)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.softShadow, radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct HomeQuickEntryRow: View {
    let services: [AssistantService]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(services) { service in
                    HomeQuickEntryCard(service: service)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct HomeQuickEntryCard: View {
    let service: AssistantService

    var body: some View {
        NavigationLink {
            AIAssistantChatView(title: service.title, allowLocalExecution: false)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.surfaceMuted)
                        .frame(width: 46, height: 46)
                    Image(systemName: service.icon)
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentStrong)
                }

                Text(service.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 6) {
                    Text(service.action)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(width: 160, alignment: .leading)
            .padding(14)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.softShadow, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct AIAssistantCategoryTabs: View {
    let categories: [String]
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(categories, id: \.self) { item in
                Button {
                    selected = item
                } label: {
                    HStack(spacing: 6) {
                        if item == "全部" {
                            Image(systemName: "sparkle")
                                .font(.caption)
                        }
                        Text(item)
                            .font(.subheadline.weight(selected == item ? .semibold : .regular))
                    }
                    .foregroundStyle(selected == item ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(selected == item ? AppTheme.surface : AppTheme.surfaceMuted)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.border, lineWidth: selected == item ? 1.2 : 1)
                    )
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct AIAssistantServiceCard: View {
    let service: AssistantService
    let category: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: service.icon)
                        .font(.title3)
                        .foregroundStyle(AppTheme.accentStrong)
                }
                Spacer()
                Text(category)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(Capsule())
            }

            Text(service.title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(service.subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(service.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text("立即\(service.action)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentStrong)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 10, x: 0, y: 6)
    }
}

struct AssistantService: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let tags: [String]
    let action: String
    let icon: String
}

struct AIAssistantChatView: View {
    let title: String
    /// 仅首页入口为 true，其他（法律/投资/面试等）保持原样，不显示本机执行
    var allowLocalExecution: Bool = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatViewModel
    @ObservedObject private var speechSettings = SpeechSettingsStore.shared

    init(title: String, allowLocalExecution: Bool = false) {
        self.title = title
        self.allowLocalExecution = allowLocalExecution
        _viewModel = StateObject(wrappedValue: ChatViewModel(allowLocalExecution: allowLocalExecution))
    }
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showFilePicker = false
    @State private var showChatMenu = false
    @State private var showVoiceCall = false
    @State private var showVideoCall = false
    @State private var showShortcutRow = false

    private let threads: [ChatThread] = [
        ChatThread(id: "c1", title: "电商数据分析", preview: "上周转化率降低的原因是什么？", time: "10:24", systemImage: "chart.line.uptrend.xyaxis", tint: .blue, tags: ["置顶", "1 未读"]),
        ChatThread(id: "c2", title: "法律咨询", preview: "关于合同解除的注意事项", time: "昨天", systemImage: "doc.text.magnifyingglass", tint: .purple, tags: ["已归档"]),
        ChatThread(id: "c3", title: "面试模拟", preview: "请帮我模拟产品经理面试", time: "周一", systemImage: "briefcase", tint: .orange, tags: ["常用"]),
        ChatThread(id: "c4", title: "AI 编程", preview: "如何优化 SwiftUI 列表性能", time: "2 月 15 日", systemImage: "chevron.left.slash.chevron.right", tint: .teal, tags: ["草稿"])
    ]

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            AIAssistantChatTopBar(
                title: title,
                isMuted: speechSettings.playbackMuted,
                onBack: { dismiss() },
                onMute: {
                    speechSettings.playbackMuted.toggle()
                    if speechSettings.playbackMuted { viewModel.stopSpeaking() }
                },
                onVoiceCall: { showVoiceCall = true },
                onMore: { showChatMenu = true }
            )
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 6)
            #else
            AIAssistantChatHeader(
                title: title,
                unreadCount: 0,
                isMuted: speechSettings.playbackMuted,
                onMute: {
                    speechSettings.playbackMuted.toggle()
                    if speechSettings.playbackMuted { viewModel.stopSpeaking() }
                },
                onVoiceCall: { showVoiceCall = true },
                onMore: { showChatMenu = true }
            )
            #endif

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if viewModel.messages.isEmpty {
                                DesignedAssistantIntroPanel { prompt in
                                    viewModel.inputText = prompt
                                    viewModel.sendMessage()
                                }
                            }
                            ChatMessageSection(messages: viewModel.messages, onClear: viewModel.resetConversation)
                            Color.clear
                                .frame(height: 1)
                                .id("assistantChatBottom")
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("assistantChatBottom", anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("assistantChatBottom", anchor: .bottom)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(spacing: 0) {
                ChatPromptChips { prompt in
                    viewModel.inputText = prompt
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                if showShortcutRow {
                    ChatShortcutHorizontalRow(
                        viewModel: viewModel,
                        onPhoto: { showPhotoPicker = true; viewModel.togglePhotoMode() },
                        onVoiceCall: { showVoiceCall = true; showShortcutRow = false },
                        onVideoCall: { showVideoCall = true; showShortcutRow = false },
                        onDismiss: { showShortcutRow = false }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface)
                    .padding(.bottom, 6)
                }

                HStack(alignment: .bottom, spacing: 0) {
                    ChatComposerBar(
                        text: $viewModel.inputText,
                        isListening: viewModel.isListening,
                        isSending: viewModel.isSending,
                        onAttach: {
                            showPhotoPicker = true
                            viewModel.togglePhotoMode()
                        },
                        onVoice: { viewModel.toggleListening() },
                        onSend: { viewModel.sendMessage() },
                        onPlus: { showShortcutRow.toggle() },
                        onPasteImage: { imageData in
                            viewModel.handlePastedImage(imageData)
                        },
                        onFileUpload: {
                            showFilePicker = true
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
            .padding(.bottom, 2)
        }
        #if os(iOS)
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .pdf, .text, .plainText, .rtf, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let url) = result, let fileURL = url.first {
                if fileURL.startAccessingSecurityScopedResource() {
                    defer { fileURL.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: fileURL) {
                        viewModel.handleFileUpload(url: fileURL, data: data)
                    }
                }
            }
        }
        #elseif os(macOS)
        .fileImporter(isPresented: $showPhotoPicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    viewModel.handleImageData(data)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .pdf, .text, .plainText, .rtf, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let url) = result, let fileURL = url.first {
                if fileURL.startAccessingSecurityScopedResource() {
                    defer { fileURL.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: fileURL) {
                        viewModel.handleFileUpload(url: fileURL, data: data)
                    }
                }
            }
        }
        #endif
        #if os(iOS)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.handleImageData(data)
                    }
                } else {
                    viewModel.alertMessage = "无法读取图片"
                }
            }
        }
        #endif
        .confirmationDialog("更多操作", isPresented: $showChatMenu) {
            Button("新对话") {
                viewModel.resetConversation()
            }
            Button("清空对话", role: .destructive) {
                viewModel.resetConversation()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("执行命令", isPresented: Binding(
            get: { viewModel.pendingCommand != nil },
            set: { if !$0 { viewModel.cancelCommandExecution() } }
        )) {
            Button("允许") {
                viewModel.confirmCommandExecution()
            }
            Button("拒绝", role: .cancel) {
                viewModel.cancelCommandExecution()
            }
        } message: {
            if let pending = viewModel.pendingCommand {
                Text("助理请求在本机执行：\n\(pending.command)")
            }
        }
        .confirmationDialog("发送执行结果", isPresented: Binding(
            get: { viewModel.pendingSendResult != nil },
            set: { if !$0 { viewModel.cancelSendResult() } }
        )) {
            Button("继续") {
                viewModel.confirmSendResult()
            }
            Button("取消", role: .cancel) {
                viewModel.cancelSendResult()
            }
        } message: {
            Text("执行结果将发送至服务器以生成回复。请确认结果中无敏感信息后再继续，保护您的隐私。")
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .fullScreenCoverOrSheet(isPresented: $showVoiceCall) {
            VoiceCallView(
                viewModel: viewModel,
                onEnd: { showVoiceCall = false }
            )
        }
        .fullScreenCoverOrSheet(isPresented: $showVideoCall) {
            VideoCallView(viewModel: viewModel, onEnd: { showVideoCall = false })
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #elseif os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // 窗口失焦时停止播放
            SpeechService.shared.stopSpeaking()
        }
        #endif
    }
}

// MARK: - 语音通话（参考图：浅色渐变 + 底部四键 + 进入即实时对话）
struct VoiceCallView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var speechService = SpeechService.shared
    var onEnd: () -> Void
    @State private var lastReplyText: String = ""
    @State private var isProcessing = false
    @State private var wasListening = false
    @State private var hasAutoStarted = false
    @State private var showCamera = false
    @State private var toastMessage: String?
    @State private var conversationTask: Task<Void, Never>?
    @State private var suppressNextCapturedTurn = false

    private let softIndigo = Color(red: 0.97, green: 0.96, blue: 1.0)
    private let softViolet = Color(red: 0.96, green: 0.95, blue: 1.0)
    private let softLavender = Color(red: 0.94, green: 0.93, blue: 0.99)
    private let controlGray = Color(red: 0.35, green: 0.35, blue: 0.38)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [softIndigo, softViolet, softLavender],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        if viewModel.isListening {
                            suppressNextCapturedTurn = true
                            _ = viewModel.stopListeningForRealtime()
                        }
                        conversationTask?.cancel()
                        SpeechService.shared.stopSpeaking()
                        isProcessing = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toastMessage = "已暂停语音"
                        }
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(controlGray)
                    }
                    Spacer()
                    Text("语音通话")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(controlGray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.7))
                        .clipShape(Capsule())
                    Spacer()
                    Button(action: {
                        stopAllAndReset()
                        onEnd()
                    }) {
                        Text("字")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(controlGray)
                    }
                    .accessibilityLabel("切换到文字")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.primary.opacity(0.12),
                                    AppTheme.secondary.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 40)
                        .opacity(0.9)

                    VStack(spacing: 16) {
                        VoiceWaveformBars(
                            isActive: viewModel.isListening,
                            barColor: viewModel.isListening ? AppTheme.primary.opacity(0.8) : controlGray.opacity(0.5),
                            inactiveColor: controlGray.opacity(0.4)
                        )

                        Text(voicePromptText)
                            .font(.subheadline)
                            .foregroundStyle(controlGray)
                    }
                }
                .frame(height: 220)

                if !lastReplyText.isEmpty {
                    ScrollView {
                        Text(lastReplyText)
                            .font(.footnote)
                            .foregroundStyle(controlGray.opacity(0.9))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                    .background(Color.white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }

                Spacer()

                HStack(spacing: 32) {
                    VoiceCallControlButton(
                        systemImage: viewModel.isListening ? "waveform" : "mic.fill",
                        tint: controlGray,
                        action: handleMicrophoneTap
                    )
                    .accessibilityLabel(viewModel.isListening ? "暂停" : "麦克风")

                    VoiceCallControlButton(systemImage: "square.and.arrow.up", tint: controlGray) {
                        let text = lastReplyText.trimmingCharacters(in: .whitespacesAndNewlines)
                        ClipboardService.copy(text.isEmpty ? "AI语音通话中" : text)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toastMessage = "已复制内容"
                        }
                    }
                    .accessibilityLabel("分享")

                    Button(action: { showCamera = true }) {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundStyle(controlGray)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开摄像头")

                    Button(action: {
                        stopAllAndReset()
                        onEnd()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(AppTheme.error)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("结束通话")
                }
                .padding(.bottom, 24)

                Text("内容由 AI 生成")
                    .font(.caption)
                    .foregroundStyle(controlGray.opacity(0.8))
                    .padding(.bottom, 20)
            }
        }
        .toast(message: $toastMessage)
        .onChange(of: viewModel.isListening) { _, isListening in
            if wasListening && !isListening {
                if suppressNextCapturedTurn {
                    suppressNextCapturedTurn = false
                    _ = viewModel.consumeLatestVoiceCapturedText()
                    wasListening = isListening
                    return
                }
                let textToSend = viewModel.consumeLatestVoiceCapturedText()
                if !textToSend.isEmpty {
                    processVoiceTurn(textToSend)
                }
            }
            wasListening = isListening
        }
        .onAppear {
            stopAllAndReset()
            wasListening = false
            if !hasAutoStarted && !isProcessing {
                hasAutoStarted = true
                viewModel.startListeningForRealtime(localeIdentifier: "zh-CN")
            }
        }
        .onDisappear {
            stopAllAndReset()
        }
        .fullScreenCoverOrSheet(isPresented: $showCamera) {
            #if os(iOS)
            CameraPicker { image in
                showCamera = false
                guard let data = image.jpegData(compressionQuality: 0.9) else { return }
                Task { await viewModel.handleImageDataAndSend(data) }
            }
            #elseif os(macOS)
            MacCameraView(onCapture: { data in
                showCamera = false
                Task { await viewModel.handleImageDataAndSend(data) }
            }, onCancel: {
                showCamera = false
            })
            #endif
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private var voicePromptText: String {
        if isProcessing { return "AI 正在回答…" }
        if speechService.isPlaying { return "AI 正在说话…" }
        if viewModel.isListening { return "正在听你说…" }
        return "你可以开始说话"
    }

    private func handleMicrophoneTap() {
        if viewModel.isListening {
            _ = viewModel.stopListeningForRealtime()
            return
        }
        if isProcessing || speechService.isPlaying {
            conversationTask?.cancel()
            SpeechService.shared.stopSpeaking()
            isProcessing = false
        }
        viewModel.startListeningForRealtime(localeIdentifier: "zh-CN")
    }

    private func processVoiceTurn(_ text: String) {
        conversationTask?.cancel()
        conversationTask = Task {
            await MainActor.run {
                isProcessing = true
                if lastReplyText.count > 240 {
                    lastReplyText = ""
                }
            }
            do {
                let reply = try await viewModel.sendAndWaitForReply(text: text)
                if Task.isCancelled { return }
                let chunks = makeReplyChunks(reply)
                await MainActor.run { lastReplyText = "" }
                for chunk in chunks {
                    try Task.checkCancellation()
                    await MainActor.run {
                        lastReplyText += chunk
                        SpeechService.shared.speakOnline(chunk, language: "zh-CN")
                    }
                    await waitForSpeechFinish()
                }
            } catch is CancellationError {
                // 用户手动打断
            } catch {
                await MainActor.run {
                    viewModel.alertMessage = userFacingMessage(for: error)
                }
            }
            await MainActor.run {
                isProcessing = false
                if !viewModel.isListening {
                    viewModel.startListeningForRealtime(localeIdentifier: "zh-CN")
                }
            }
        }
    }

    private func waitForSpeechFinish() async {
        while true {
            if Task.isCancelled {
                await MainActor.run { SpeechService.shared.stopSpeaking() }
                break
            }
            let playing = await MainActor.run { speechService.isPlaying }
            if !playing { break }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
    }

    private func makeReplyChunks(_ reply: String) -> [String] {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var chunks: [String] = []
        var current = ""

        for char in trimmed {
            current.append(char)
            let strongBreak = "。！？!?；;\n".contains(char)
            let softBreak = "，,、".contains(char)
            if strongBreak || (softBreak && current.count >= 12) || current.count >= 26 {
                let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { chunks.append(piece) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { chunks.append(tail) }
        return chunks.isEmpty ? [trimmed] : chunks
    }

    private func stopAllAndReset() {
        suppressNextCapturedTurn = true
        wasListening = false
        conversationTask?.cancel()
        conversationTask = nil
        _ = viewModel.stopListeningForRealtime()
        _ = viewModel.consumeLatestVoiceCapturedText()
        SpeechService.shared.stopSpeaking()
        isProcessing = false
    }
}

/// 三个长圆条，随节奏跳动模拟音频波动
private struct VoiceWaveformBars: View {
    var isActive: Bool = true
    var barColor: Color = Color(red: 0.35, green: 0.35, blue: 0.38)
    var inactiveColor: Color = Color(red: 0.35, green: 0.35, blue: 0.38).opacity(0.4)

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = Double(i) * 0.35
                    let scale = isActive ? (0.5 + 0.5 * sin(t * 4.5 + phase)) : 0.6
                    let height = max(8, 8 + 16 * scale)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? barColor : inactiveColor)
                        .frame(width: 8, height: height)
                        .animation(.easeInOut(duration: 0.15), value: height)
                }
            }
        }
        .frame(height: 28)
    }
}

private struct VoiceCallControlButton: View {
    let systemImage: String
    var tint: Color = Color(red: 0.35, green: 0.35, blue: 0.38)
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.8))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#if os(macOS)
/// macOS 图片选择器：先显示操作按钮，避免 onAppear 直接弹 NSOpenPanel 导致卡死
struct MacImagePicker: View {
    var onImage: (URL) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("选择图片")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("从相册或文件夹选择一张图片发送给助理识别")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("选择图片") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.image]
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            onImage(url)
                        } else {
                            onCancel()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 280, minHeight: 140)
        .padding(24)
    }
}

/// macOS 摄像头实时预览 + 拍照发送给助理
struct MacCameraView: View {
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    @StateObject private var session = MacCameraSession()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                MacCameraPreviewView(session: session.session)
                    .background(Color.black)
                if session.errorMessage != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(session.errorMessage ?? "无法打开摄像头")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .frame(minWidth: 400, minHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 16) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("拍照并发送给助理") {
                    session.capturePhoto { data in
                        if let data = data {
                            onCapture(data)
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(session.session == nil || session.errorMessage != nil)
            }
            .padding(16)
        }
        .frame(minWidth: 420, minHeight: 360)
        .onAppear { session.start() }
        .onDisappear { session.stop() }
    }
}

/// 封装 AVCaptureSession，支持预览与拍照
private final class MacCameraSession: NSObject, ObservableObject {
    @Published private(set) var session: AVCaptureSession?
    @Published private(set) var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "mac.camera.session")
    private var photoOutput: AVCapturePhotoOutput?
    private var captureCompletion: ((Data?) -> Void)?

    override init() {
        super.init()
    }

    func start() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session?.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.session, let photoOutput = self.photoOutput else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureSession() {
        let s = AVCaptureSession()
        s.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
               ?? AVCaptureDevice.default(for: .video) else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "未找到摄像头"
            }
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "无法打开摄像头"
            }
            return
        }
        if s.canAddInput(input) { s.addInput(input) }
        let output = AVCapturePhotoOutput()
        if s.canAddOutput(output) {
            s.addOutput(output)
            photoOutput = output
        }
        session = s
        DispatchQueue.main.async { [weak self] in
            self?.session = s
            self?.errorMessage = nil
        }
        s.startRunning()
    }
}

extension MacCameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = captureCompletion
        captureCompletion = nil
        if let error = error {
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        DispatchQueue.main.async { completion?(data) }
    }
}

/// 将 AVCaptureSession 预览层嵌入 SwiftUI（macOS）
private struct MacCameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?

    func makeNSView(context: Context) -> NSView {
        let view = CameraPreviewNSView()
        view.session = session
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CameraPreviewNSView)?.session = session
    }
}

private final class CameraPreviewNSView: NSView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer?.removeFromSuperlayer()
            guard let session = session else { return }
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspect
            layer.frame = bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            self.layer = layer
            self.previewLayer = layer
        }
    }
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
#endif

#if os(iOS)
/// 打开系统相机，用于视觉对话
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif

// MARK: - 视频通话（AI 形象 + 语音）
struct VideoCallView: View {
    @ObservedObject var viewModel: ChatViewModel
    var onEnd: () -> Void
    @State private var lastReplyText: String = ""
    @State private var isProcessing = false
    @State private var wasListening = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.22),
                    Color(red: 0.06, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.stopListening()
                        onEnd()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }

                Text("视频通话")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primary.opacity(0.4), AppTheme.primary.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                    Circle()
                        .fill(AppTheme.primary.opacity(0.25))
                        .frame(width: 120, height: 120)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)

                Text(statusLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 32)

                if !lastReplyText.isEmpty {
                    Text(lastReplyText)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    if viewModel.isListening {
                        viewModel.toggleListening()
                    } else if !isProcessing {
                        viewModel.toggleListening()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.isListening ? AppTheme.accentWarm.opacity(0.3) : Color.white.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: viewModel.isListening ? "waveform" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                Text(viewModel.isListening ? "正在听…" : "点击说话")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()
                    .frame(height: 40)
            }
        }
        .onChange(of: viewModel.isListening) { _, isListening in
            if wasListening && !isListening && !viewModel.inputText.isEmpty {
                let textToSend = viewModel.inputText
                viewModel.inputText = ""
                Task {
                    isProcessing = true
                    do {
                        let reply = try await viewModel.sendAndWaitForReply(text: textToSend)
                        await MainActor.run {
                            lastReplyText = reply
                            SpeechService.shared.speak(reply, language: "zh-CN")
                        }
                    } catch {
                        await MainActor.run {
                            viewModel.alertMessage = userFacingMessage(for: error)
                        }
                    }
                    isProcessing = false
                }
            }
            wasListening = isListening
        }
        .onAppear {
            wasListening = viewModel.isListening
        }
    }

    private var statusLabel: String {
        if isProcessing { return "AI 正在思考…" }
        if viewModel.isListening { return "说完后自动回复" }
        return "点击麦克风与 AI 对话"
    }
}

/// 参考图：左侧返回、中间头像+名称+「内容由AI生成」、右侧喇叭(静音)+电话+三点
struct AIAssistantChatHeader: View {
    let title: String
    var unreadCount: Int = 0
    var isMuted: Bool = false
    var onMute: () -> Void = {}
    var onVoiceCall: () -> Void
    var onMore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentWarm.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("内容由AI生成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            UnifiedAppIconButton(systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                onMute()
            }
            .accessibilityLabel(isMuted ? "取消静音" : "静音")

            UnifiedAppIconButton(systemImage: "phone.fill") {
                onVoiceCall()
            }
            .accessibilityLabel("语音通话")

            CircleButton(systemImage: "ellipsis", action: onMore)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#if os(iOS)
private struct AIAssistantChatTopBar: View {
    let title: String
    let isMuted: Bool
    let onBack: () -> Void
    let onMute: () -> Void
    let onVoiceCall: () -> Void
    let onMore: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(AppTheme.TopBar.backIconFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: AppTheme.TopBar.backButtonSize, height: AppTheme.TopBar.backButtonSize)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                .frame(width: AppTheme.TopBar.sideSlotWidth, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    topActionButton(system: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", action: onMute)
                        .accessibilityLabel(isMuted ? "取消静音" : "静音")
                    topActionButton(system: "phone.fill", action: onVoiceCall)
                        .accessibilityLabel("语音通话")
                    topActionButton(system: "ellipsis", action: onMore)
                        .accessibilityLabel("更多操作")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(AppTheme.surface)
                .clipShape(Capsule())
            }

            Text(title)
                .font(AppTheme.TopBar.titleFont)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, AppTheme.TopBar.sideSlotWidth + 12)
        }
        .frame(height: AppTheme.TopBar.height)
    }

    private func topActionButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
#endif

struct ChatPromptRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(AppTheme.textSecondary)
                .padding(8)
                .background(AppTheme.surfaceMuted)
                .clipShape(Circle())

            Spacer()

            HStack(spacing: 10) {
                Text("帮我写一份年度总结")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentWarm.opacity(0.2))
                    .clipShape(Capsule())

                AvatarBubble()
            }
        }
    }
}

struct ChatReplyBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarBubble()

            VStack(alignment: .leading, spacing: 10) {
                Text("xxxx年，对我来说是一个不平凡的一年。它给我考验、带来挑战，也让我幸运地获得成功。\n\n一方面，在2019年我坚持完成了自己的学习计划，取得了进步，提高了自己的能力，得到了老师的认可和肯定。我参加了一系列的考试，如期末考试、中考和高考，取得了优异的成绩，非常满意。我对自己已经可以承担起学习与责任感到很开心。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(16)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 4)

            CircleButton(systemImage: "square.and.arrow.up")
        }
    }
}

/// 参考图：相机 | 发消息或按住说话 | 语音输入 | 发送 | 加号
struct ChatComposerBar: View {
    @Binding var text: String
    let isListening: Bool
    let isSending: Bool
    var onAttach: () -> Void
    var onVoice: () -> Void
    var onSend: () -> Void
    var onPlus: () -> Void = {}
    var onPasteImage: ((Data) -> Void)? = nil
    var onFileUpload: (() -> Void)? = nil

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            iconButton("camera.fill", isPrimary: false) {
                onAttach()
            }
            .accessibilityLabel("拍照或相册")
            
            iconButton("doc.fill", isPrimary: false) {
                onFileUpload?()
            }
            .accessibilityLabel("上传文件")

            #if os(macOS)
            PasteableTextField(
                text: $text,
                placeholder: "发消息或按住说话...",
                onPasteImage: onPasteImage,
                onSubmit: { onSend() }
            )
            .font(.subheadline)
            .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
                .tint(AppTheme.primary)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(minHeight: 44)
                .layoutPriority(1)
                .onSubmit { onSend() }
            #else
            TextField("发消息或按住说话...", text: $text, axis: .vertical)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
                .tint(AppTheme.primary)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(minHeight: 44)
                .layoutPriority(1)
                .onSubmit { onSend() }
            #endif

            iconButton(isListening ? "waveform.circle.fill" : "mic.fill", isPrimary: isListening) {
                onVoice()
            }
            .accessibilityLabel(isListening ? "正在听" : "语音输入")

            iconButton("paperplane.fill", isPrimary: canSend) {
                onSend()
            }
            .disabled(!canSend)
            .accessibilityLabel("发送")

            iconButton("plus", isPrimary: false) {
                onPlus()
            }
            .accessibilityLabel("更多功能")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.unifiedButtonBorder.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow.opacity(0.45), radius: 6, x: 0, y: 2)
    }

    private func iconButton(_ systemName: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isPrimary
                        ? AnyShapeStyle(AppTheme.primary)
                        : AnyShapeStyle(Color(red: 0.92, green: 0.95, blue: 1.0))
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isPrimary ? .white : AppTheme.primary)
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct ChatPromptChips: View {
    var onPick: (String) -> Void

    private let items: [(String, String)] = [
        ("发现", "帮我梳理今天的重点工作，按优先级排序。"),
        ("帮我写作", "请根据这个主题写一段简洁有力的文案。"),
        ("图片生成", "帮我写一个适合生成海报图的提示词。"),
        ("群发收集", "请生成一条群发消息模板，语气礼貌简洁。")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    Button {
                        onPick(item.1)
                    } label: {
                        Text(item.0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#if os(macOS)
/// 支持粘贴图片的 TextField（macOS）
struct PasteableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onPasteImage: ((Data) -> Void)?
    var onSubmit: (() -> Void)?
    
    func makeNSView(context: Context) -> CustomTextField {
        let textField = CustomTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.delegate = context.coordinator
        textField.onPasteImage = onPasteImage
        textField.onSubmit = onSubmit
        textField.textColor = NSColor.labelColor
        
        // 设置 cell 以支持多行
        if let cell = textField.cell as? NSTextFieldCell {
            cell.wraps = true
            cell.isScrollable = false
            cell.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: CustomTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.onPasteImage = onPasteImage
        nsView.onSubmit = onSubmit
        nsView.textColor = NSColor.labelColor
        if let cell = nsView.cell as? NSTextFieldCell {
            cell.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text = textField.stringValue
            }
        }
    }
}

/// 自定义 TextField，支持拦截粘贴事件
class CustomTextField: NSTextField {
    var onPasteImage: ((Data) -> Void)?
    var onSubmit: (() -> Void)?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 拦截 Cmd+V
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            return handlePaste()
        }
        // 回车：发送消息；Option/Shift+回车：换行
        let isReturn = (event.keyCode == 36) || (event.charactersIgnoringModifiers == "\r") || (event.charactersIgnoringModifiers == "\n")
        if isReturn {
            if event.modifierFlags.contains(.option) || event.modifierFlags.contains(.shift) {
                // 允许换行，走系统默认行为
                return false
            } else {
                // 发送消息，不插入换行
                onSubmit?()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    private func handlePaste() -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 检查是否有图片（使用正确的 PasteboardType）
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.jpg")
        ]
        
        for type in imageTypes {
            if let imageData = pasteboard.data(forType: type) {
                DispatchQueue.main.async {
                    self.onPasteImage?(imageData)
                }
                return true
            }
        }
        
        // 检查是否有文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let imageData = try? Data(contentsOf: url),
                   NSImage(data: imageData) != nil {
                    DispatchQueue.main.async {
                        self.onPasteImage?(imageData)
                    }
                    return true
                }
            }
        }
        
        // 允许普通文本粘贴
        return false
    }
}
#endif

struct ChatPromptChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.unifiedButtonBorder)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
    }
}

struct ChatSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// 加号展开：一排横向排列、可左右滑动的快捷功能
struct ChatShortcutHorizontalRow: View {
    @ObservedObject var viewModel: ChatViewModel
    var onPhoto: () -> Void = {}
    var onVoiceCall: () -> Void = {}
    var onVideoCall: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                shortcutChip(title: "语音通话", icon: "mic.circle.fill", tint: .blue, action: onVoiceCall)
                shortcutChip(title: "视频通话", icon: "video.circle.fill", tint: .purple, action: onVideoCall)
                shortcutChip(title: "拍照识别", icon: viewModel.isPhotoMode ? "camera.fill" : "camera", tint: .orange) {
                    viewModel.togglePhotoMode()
                    onPhoto()
                }
                shortcutChip(title: "文件总结", icon: "doc.text", tint: .teal) {
                    viewModel.statusText = "等待上传文件"
                    viewModel.inputText = "请帮我总结上传的文件重点。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                shortcutChip(title: "任务清单", icon: "checklist", tint: .green) {
                    viewModel.inputText = "请把今天的目标整理成待办清单。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                shortcutChip(title: "会议纪要", icon: "quote.bubble", tint: .indigo) {
                    viewModel.inputText = "请帮我生成一份会议纪要模板。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                // 写作与 PPT 入口
                shortcutChip(title: "写作", icon: "pencil", tint: .pink) {
                    viewModel.inputText = "我想写一篇文章，请根据我的主题帮我规划大纲并起草内容。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                shortcutChip(title: "PPT", icon: "rectangle.stack.badge.play.fill", tint: .cyan) {
                    viewModel.inputText = "请帮我根据下面的主题生成一份 PPT 提纲，并说明每一页的要点。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 44)
    }

    private func shortcutChip(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surfaceMuted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 加号弹出的快捷功能列表（输入框右侧）
struct ChatShortcutPopoverContent: View {
    @ObservedObject var viewModel: ChatViewModel
    var onPhoto: () -> Void = {}
    var onVoiceCall: () -> Void = {}
    var onVideoCall: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("快捷功能")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                shortcutRow(title: "语音通话", subtitle: "像豆包一样对话", icon: "mic.circle.fill", tint: .blue, action: onVoiceCall)
                shortcutRow(title: "视频通话", subtitle: "AI 形象 + 语音", icon: "video.circle.fill", tint: .purple, action: onVideoCall)
                shortcutRow(title: "拍照识别", subtitle: viewModel.isPhotoMode ? "识别中" : "打开相册", icon: viewModel.isPhotoMode ? "camera.fill" : "camera", tint: .orange) {
                    viewModel.togglePhotoMode()
                    onPhoto()
                }
                shortcutRow(title: "文件总结", subtitle: "导入文档", icon: "doc.text", tint: .teal) {
                    viewModel.statusText = "等待上传文件"
                    viewModel.inputText = "请帮我总结上传的文件重点。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                shortcutRow(title: "任务清单", subtitle: "生成待办", icon: "checklist", tint: .green) {
                    viewModel.inputText = "请把今天的目标整理成待办清单。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                shortcutRow(title: "会议纪要", subtitle: "结构化输出", icon: "quote.bubble", tint: .indigo) {
                    viewModel.inputText = "请帮我生成一份会议纪要模板。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                // 写作与 PPT 入口
                shortcutRow(title: "写作", subtitle: "长文、文案、邮件", icon: "pencil", tint: .pink) {
                    viewModel.inputText = "我想写一篇文章，请根据我的主题帮我规划结构并起草内容。"
                    viewModel.sendMessage()
                    onDismiss()
                }
                shortcutRow(title: "PPT", subtitle: "生成演示提纲", icon: "rectangle.stack.badge.play.fill", tint: .cyan) {
                    viewModel.inputText = "请帮我生成一份 PPT 提纲，并为每一页给出要点。"
                    viewModel.sendMessage()
                    onDismiss()
                }
            }
            .padding(.bottom, 12)
        }
        .frame(minWidth: 260)
        .background(AppTheme.surface)
    }

    private func shortcutRow(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

struct ChatShortcutSection: View {
    @ObservedObject var viewModel: ChatViewModel
    var onPhoto: () -> Void = {}
    var onVoiceCall: () -> Void = {}
    var onVideoCall: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChatSectionHeader(title: "快捷功能", actionTitle: "自定义")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ChatQuickActionButton(
                    title: "语音通话",
                    subtitle: "像豆包一样对话",
                    systemImage: "mic.circle.fill",
                    tint: .blue,
                    action: onVoiceCall
                )
                ChatQuickActionButton(
                    title: "视频通话",
                    subtitle: "AI 形象 + 语音",
                    systemImage: "video.circle.fill",
                    tint: .purple,
                    action: onVideoCall
                )
                ChatQuickToggleButton(
                    title: "拍照识别",
                    subtitle: viewModel.isPhotoMode ? "识别中" : "打开相册",
                    systemImage: viewModel.isPhotoMode ? "camera.fill" : "camera",
                    tint: .orange,
                    isActive: viewModel.isPhotoMode,
                    action: {
                        viewModel.togglePhotoMode()
                        onPhoto()
                    }
                )
                ChatQuickActionButton(
                    title: "文件总结",
                    subtitle: "导入文档",
                    systemImage: "doc.text",
                    tint: .teal
                ) {
                    viewModel.statusText = "等待上传文件"
                    viewModel.inputText = "请帮我总结上传的文件重点。"
                    viewModel.sendMessage()
                }
                ChatQuickActionButton(
                    title: "任务清单",
                    subtitle: "生成待办",
                    systemImage: "checklist",
                    tint: .green
                ) {
                    viewModel.inputText = "请把今天的目标整理成待办清单。"
                    viewModel.sendMessage()
                }
                ChatQuickActionButton(
                    title: "会议纪要",
                    subtitle: "结构化输出",
                    systemImage: "quote.bubble",
                    tint: .indigo
                ) {
                    viewModel.inputText = "请帮我生成一份会议纪要模板。"
                    viewModel.sendMessage()
                }
            }
        }
        .glassCard()
    }
}

struct ChatQuickToggleButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(AppTheme.unifiedButtonBorder)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ChatQuickActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(AppTheme.unifiedButtonBorder)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ChatThread: Identifiable, Hashable {
    let id: String
    let title: String
    let preview: String
    let time: String
    let systemImage: String
    let tint: Color
    let tags: [String]
}

struct ChatThreadSection: View {
    let threads: [ChatThread]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChatSectionHeader(title: "对话列表", actionTitle: "查看全部")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(threads) { thread in
                        ChatThreadCard(thread: thread)
                    }
                }
            }
        }
    }
}

struct ChatThreadCard: View {
    let thread: ChatThread

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(thread.tint.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: thread.systemImage)
                        .foregroundStyle(thread.tint)
                }
                Spacer()
                Text(thread.time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(thread.title)
                .font(.subheadline.weight(.semibold))

            Text(thread.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(thread.tags, id: \.self) { tag in
                    GlassTag(text: tag, isActive: tag == "置顶")
                }
            }
        }
        .frame(width: 220, alignment: .leading)
        .glassCard()
    }
}

struct ChatMessageSection: View {
    let messages: [ChatMessage]
    var onClear: () -> Void = {}
    var showDateSeparator: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showDateSeparator, let first = messages.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(first.time.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                        .padding(.vertical, 4)
                }
                .padding(.bottom, 4)
            }
            ForEach(messages) { message in
                ChatBubble(message: message)
            }
        }
    }
}

struct CircleButton: View {
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.unifiedButtonBorder)
                .frame(width: 36, height: 36)
                .background(AppTheme.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct AvatarBubble: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accentWarm.opacity(0.28))
                .frame(width: 40, height: 40)
            Image(systemName: "face.smiling")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.8))
        }
    }
}

struct AIStatusCard: View {
    let status: String

    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundStyle(AppTheme.accentStrong)
            Text(status)
                .font(.subheadline.weight(.semibold))
            Spacer()
            GlassTinyButton(systemImage: "bolt")
        }
        .glassCard()
    }
}

struct DesignedAssistantIntroPanel: View {
    var onPick: (String) -> Void

    private let quickItems: [(String, String, String)] = [
        ("闪记录音", "waveform", "请把这段会议内容整理成要点和行动项。"),
        ("工作总结", "doc.text", "请帮我生成本周工作总结，分为完成事项、问题、下周计划。"),
        ("AI祝福", "heart", "请写一段适合发给同事的生日祝福，真诚简短。"),
        ("助理推荐", "person.2", "根据我今天的任务，推荐3个提高效率的方法。")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("在这里，勾点工作给AI吧")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(quickItems, id: \.0) { item in
                    Button {
                        onPick(item.2)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: item.1)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 30, height: 30)
                                .background(Color(red: 0.90, green: 0.94, blue: 1.0))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(item.0)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                        .padding(10)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(AppTheme.surface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// 用户消息靠右、AI 消息靠左，不居中
struct ChatBubble: View {
    let message: ChatMessage
    @ObservedObject private var speechService = SpeechService.shared

    private let userBubbleBlue = AppTheme.primary
    private let aiBubbleGray = Color(red: 0.965, green: 0.965, blue: 0.97)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 0) }
            if message.role == .assistant {
                AvatarBubble()
            }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : AppTheme.textPrimary)
                if message.role == .assistant {
                    HStack(spacing: 12) {
                        Button {
                            if speechService.isPlaying {
                                speechService.stopSpeaking()
                            } else {
                                speechService.speakOnline(message.content, language: "zh-CN")
                            }
                        } label: {
                            Label(speechService.isPlaying ? "停止" : "朗读", systemImage: speechService.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.plain)

                        Button {
                            ClipboardService.copy(message.content)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                }
                Text(message.time.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(message.role == .user ? .white.opacity(0.8) : AppTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.role == .user ? userBubbleBlue : aiBubbleGray)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

struct AIAssistantCapabilityCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("能力与记忆")
                .font(.headline)
            CapabilityRow(title: "机器学习能力", detail: "自动适配学习节奏与使用习惯")
            CapabilityRow(title: "云端长期记忆", detail: "跨设备同步对话、翻译与学习记录")
            CapabilityRow(title: "实时语音", detail: "降低交互延迟，保障识别准确率")
        }
        .glassCard()
    }
}

struct CapabilityRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct MessageInputBar: View {
    @Binding var text: String
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("输入内容或使用语音", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
            GlassTinyButton(systemImage: "mic")
            GlassTinyButton(systemImage: "paperplane.fill", action: onSend)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct MemoryDetailView: View {
    @ObservedObject private var tokenStore = TokenStore.shared
    @StateObject private var statsViewModel = UserStatsViewModel()

    private var summaryText: String {
        if let s = statsViewModel.stats {
            return "已记录 \(s.totalConversations) 条对话、\(s.totalTranslations) 条翻译、\(s.learningSessions) 次学习记录。"
        } else if !tokenStore.isLoggedIn {
            return "登录后可在云端记录你的对话、翻译与学习记录。"
        } else if statsViewModel.isLoading {
            return "正在统计你的对话、翻译与学习记录…"
        } else {
            return "暂时没有可用的统计数据。"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassHeroCard(
                        title: "云端长期记忆",
                        subtitle: "跨设备同步你的学习与对话",
                        systemImage: "cloud.fill",
                        accent: .blue
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("记忆摘要")
                            .font(.headline)
                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("智能建议")
                            .font(.headline)
                        Text("- 建议每天至少完成 15 分钟口语或翻译练习\n- 多复习「旅行」「职场」等高频场景的短句")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .glassCard()
                }
                .padding(20)
            }
            .navigationTitle("长期记忆")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: tokenStore.token) {
                await statsViewModel.load()
            }
        }
        .glassNavigation()
    }
}

// MARK: - 现代化AI助理组件

struct ModernAIAssistantHeader: View {
    var body: some View {
        ModernHeroHeader(
            systemImage: "sparkles",
            title: "AI智能助理",
            subtitle: "您的专属智能助手",
            badgeText: "PRO",
            headline: "让AI为您赋能",
            subheadline: "涵盖工作、学习、生活的全方位智能服务",
            style: .gradient
        )
    }
}

struct ModernSearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textTertiary)
                .font(.system(size: 16, weight: .medium))
            
            TextField("搜索智能服务...", text: $text)
                .font(.callout)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
                .onTapGesture {
                    isEditing = true
                }
            
            if !text.isEmpty {
                ModernIconButton("xmark.circle.fill", style: .ghost, size: .small) {
                    text = ""
                }
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .fill(AppTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                        .stroke(isEditing ? AppTheme.primary : AppTheme.border, lineWidth: isEditing ? 2 : 1)
                )
        )
        .animation(ModernDesignSystem.Animation.standard, value: isEditing)
    }
}

struct ModernQuickActionStrip: View {
    let primaryService: AssistantService
    
    var body: some View {
        ModernCard(style: .glass) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("快速开始")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(primaryService.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                ModernButton(
                    primaryService.action,
                    systemImage: "arrow.right.circle.fill",
                    style: .primary,
                    size: .small
                ) {
                    // 快速开始动作
                }
            }
        }
    }
}

struct ModernInsightCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let accent: Color
    
    var body: some View {
        ModernCard(style: .elevated) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // 左侧图标
                ZStack {
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(accent.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                }
                
                // 中间内容
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.xlarge)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ModernSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModernPrimaryEntryCard: View {
    let service: AssistantService
    
    var body: some View {
        ModernCard(style: .elevated, padding: EdgeInsets(
            top: ModernDesignSystem.Spacing.lg,
            leading: ModernDesignSystem.Spacing.lg,
            bottom: ModernDesignSystem.Spacing.lg,
            trailing: ModernDesignSystem.Spacing.lg
        )) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text(service.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text(service.subtitle)
                            .font(.callout)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                        
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            ForEach(service.tags, id: \.self) { tag in
                                ModernTag(text: tag, isActive: true)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: service.icon)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.textOnPrimary)
                    }
                }
                
                ModernButton(
                    service.action,
                    systemImage: "arrow.right",
                    style: .primary
                ) {
                    // 操作处理
                }
            }
        }
    }
}

struct ModernQuickEntryRow: View {
    let services: [AssistantService]
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveLayout.spacing(.card)) {
                    ForEach(services) { service in
                        ResponsiveQuickEntryCard(service: service, width: cardWidth(for: geometry.size.width))
                    }
                }
                .padding(.horizontal, ResponsiveLayout.spacing(.horizontal))
            }
        }
        .frame(height: 100)
    }
    
    private func cardWidth(for containerWidth: CGFloat) -> CGFloat {
        let availableWidth = containerWidth - ResponsiveLayout.spacing(.horizontal) * 2
        let spacing = ResponsiveLayout.spacing(.card)
        let cardCount = min(services.count, ResponsiveLayout.isTablet ? 4 : 3)
        return (availableWidth - spacing * CGFloat(cardCount - 1)) / CGFloat(cardCount)
    }
}

struct ResponsiveQuickEntryCard: View {
    let service: AssistantService
    let width: CGFloat
    
    var body: some View {
        ModernCard(style: .outlined, padding: EdgeInsets(
            top: ResponsiveLayout.spacing(.card),
            leading: ResponsiveLayout.spacing(.card),
            bottom: ResponsiveLayout.spacing(.card),
            trailing: ResponsiveLayout.spacing(.card)
        )) {
            VStack(spacing: ModernDesignSystem.Spacing.xs) {
                Image(systemName: service.icon)
                    .font(ResponsiveLayout.font(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                
                ResponsiveText(
                    service.title,
                    style: .caption,
                    maxLines: 2
                )
                .multilineTextAlignment(.center)
            }
            .frame(width: width)
        }
    }
}

struct ModernCategoryTabs: View {
    let categories: [String]
    @Binding var selected: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(categories, id: \.self) { category in
                    ModernButton(
                        category,
                        style: selected == category ? .primary : .outline,
                        size: .medium
                    ) {
                        selected = category
                    }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.xs)
        }
    }
}

struct ModernServiceCard: View {
    let service: AssistantService
    let category: String
    
    var body: some View {
        ModernCard(style: .elevated) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                // 图标和分类
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                            .fill(AppTheme.primary.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: service.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppTheme.primary)
                    }
                    
                    Spacer()
                    
                    ModernTag(text: category, isActive: false)
                }
                
                // 标题和描述
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(service.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                    
                    Text(service.subtitle)
                        .font(.callout)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                }
                
                // 标签
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        ForEach(service.tags.prefix(2), id: \.self) { tag in
                            ModernTag(text: tag, isActive: false)
                        }
                        if service.tags.count > 2 {
                            Text("+\(service.tags.count - 2)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    
                    ModernButton(
                        service.action,
                        systemImage: "arrow.right",
                        style: .primary,
                        size: .small
                    ) {
                        // 操作处理
                    }
                }
            }
        }
        .scaleEffect(1.0)
        .animation(ModernDesignSystem.Animation.spring, value: service.id)
    }
}

struct ModernEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceMuted)
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ModernTag: View {
    let text: String
    var isActive: Bool = false
    var style: TagStyle = .default
    
    enum TagStyle {
        case `default`
        case pill
        case outlined
    }
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, style == .pill ? 10 : 8)
            .padding(.vertical, 4)
            .background(tagBackground)
            .foregroundStyle(tagForeground)
            .clipShape(Capsule())
            .overlay(tagBorder)
    }
    
    @ViewBuilder
    private var tagBackground: some View {
        switch style {
        case .default, .pill:
            isActive ? AppTheme.primary.opacity(0.1) : AppTheme.surfaceMuted
        case .outlined:
            Color.clear
        }
    }
    
    private var tagForeground: Color {
        isActive ? AppTheme.primary : AppTheme.textSecondary
    }
    

    
    @ViewBuilder
    private var tagBorder: some View {
        if style == .outlined {
            Capsule()
                .stroke(isActive ? AppTheme.primary : AppTheme.border, lineWidth: 1)
        }
    }
}

// MARK: - 分类筛选芯片（稍大一点更易点）
struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? AppTheme.primary : AppTheme.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.clear : AppTheme.borderStrong, lineWidth: 1)
        )
    }
}

// MARK: - 今日数据单项（一排紧凑显示，背景与边框区分明显）
struct TodayDataItem: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(tint.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - 科技感AI助理头部（与翻译页紧凑尺寸一致）
struct TechAIAssistantHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                Text("AI助理")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            Text("智能AI助手集合")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 6) {
                Circle()
                    .fill(ModernColorSystem.Neon.neonGreen)
                    .frame(width: 6, height: 6)
                Text("系统在线")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)
                Text("最后更新: \(Date(), style: .time)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .responsiveContainer()
    }
}

// MARK: - 服务卡片（紧凑、与今日数据左右对齐）
struct TechServiceCard: View {
    let service: AssistantService
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.primary)
                    .frame(width: 3, height: 32)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: service.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(service.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    
                    Text(service.subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 3) {
                        ForEach(service.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppTheme.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.primary.opacity(0.12)))
                        }
                    }
                    
                    HStack(spacing: 3) {
                        Text(service.action)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 10)
            }
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}
