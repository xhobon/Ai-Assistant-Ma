import SwiftUI

/// 侧边栏项：助理为默认页 + 写作、PPT、笔记、总结、翻译、学习、设置
enum SidebarItem: Int, CaseIterable {
    case partner = 0        // 助理（默认）
    case writing = 1        // 写作
    case ppt = 2            // PPT
    case notes = 3         // 笔记
    case summary = 4       // 总结
    case translate = 5     // 翻译
    case learning = 6      // 学习
    case profile = 7       // 设置

    var title: String {
        switch self {
        case .partner: return "助理"
        case .writing: return "写作"
        case .ppt: return "PPT"
        case .notes: return "笔记"
        case .summary: return "总结"
        case .translate: return "翻译"
        case .learning: return "学习"
        case .profile: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .partner: return "brain.head.profile"
        case .writing: return "pencil"
        case .ppt: return "rectangle.stack"
        case .notes: return "mic"
        case .summary: return "doc.text"
        case .translate: return "character.bubble"
        case .learning: return "book.fill"
        case .profile: return "gearshape"
        }
    }
}

private let sidebarActiveBg = Color(red: 0.11, green: 0.44, blue: 0.85).opacity(0.16)
private let sidebarActiveFg = Color(red: 0.10, green: 0.43, blue: 0.86)
private let sidebarInactive = Color(red: 0.35, green: 0.39, blue: 0.45)

struct SidebarLogoView: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 34, height: 34)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textOnPrimary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("AI 全能助理")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Workspace")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

/// 参考图：图标在上、文字在下，选中为浅绿圆角块
struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? sidebarActiveFg : sidebarInactive)
                .frame(width: 28, height: 28)
                .background(isSelected ? sidebarActiveFg.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppTheme.textPrimary : sidebarInactive)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? sidebarActiveBg : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .partner
    @ObservedObject private var appearance = AppearanceStore.shared
    @State private var copyToastMessage: String?
    private var primarySidebarItems: [SidebarItem] {
        // 侧边栏只保留：助理、笔记、总结、翻译、学习（写作/PPT 入口已移动到助理页面的加号里）
        SidebarItem.allCases.filter { ![.profile, .writing, .ppt].contains($0) }
    }

    private static var defaultSidebarItem: SidebarItem { .partner }

    /// 根据当前选中的页面返回窗口标题
    private var currentWindowTitle: String {
        let item = selectedItem ?? .partner
        switch item {
        case .partner: return "AI助理"
        case .writing: return "写作"
        case .ppt: return "PPT"
        case .notes: return "笔记"
        case .summary: return "总结"
        case .translate: return "AI翻译"
        case .learning: return "印尼语学习"
        case .profile: return "设置"
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SidebarLogoView()
                    .padding(.top, 16)
                    .padding(.horizontal, 12)
                Text("导航")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                VStack(spacing: 8) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(primarySidebarItems, id: \.rawValue) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    SidebarRow(item: item, isSelected: selectedItem == item)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.top, 4)
                    }
                    Divider()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)

                    Button {
                        selectedItem = .profile
                    } label: {
                        SidebarRow(item: .profile, isSelected: selectedItem == .profile)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 250)
        } detail: {
            Group {
                switch selectedItem ?? Self.defaultSidebarItem {
                case .partner:
                    AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
                case .writing:
                    WritingStudioView()
                case .ppt:
                    PPTStudioView()
                case .notes:
                    NotesWorkspaceView()
                case .summary:
                    SummaryWorkspaceView()
                case .translate:
                    AITranslateHomeView()
                case .learning:
                    IndonesianLearningView()
                case .profile:
                    ProfileCenterView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(currentWindowTitle)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
        .onChange(of: selectedItem) { _, _ in
            // 切换侧边栏页面时停止语音播放，避免在其它页还能听到朗读
            SpeechService.shared.stopSpeaking()
        }
        .preferredColorScheme(appearance.colorScheme)
        .toast(message: $copyToastMessage)
        .onReceive(NotificationCenter.default.publisher(for: .globalCopySucceeded)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                copyToastMessage = "已复制到剪贴板"
            }
        }
    }
}

#Preview {
    ContentView()
}
