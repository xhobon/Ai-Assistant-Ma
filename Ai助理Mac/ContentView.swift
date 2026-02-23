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
        case .partner: return "person.2"
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

/// AI全能助理 Logo：AI 亮绿 + 全能助理深色
private let logoTeal = Color(red: 0.15, green: 0.45, blue: 0.45)
private let accentGreen = Color(red: 0.25, green: 0.72, blue: 0.35)
private let activeGreenBg = Color(red: 0.85, green: 0.95, blue: 0.88)
private let activeGreenFg = Color(red: 0.15, green: 0.55, blue: 0.28)
private let sidebarInactive = Color(red: 0.35, green: 0.35, blue: 0.38)

struct SidebarLogoView: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("AI")
                .font(.headline.weight(.bold))
                .foregroundStyle(accentGreen)
                .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
            Text("全能助理")
                .font(.headline.weight(.semibold))
                .foregroundStyle(logoTeal)
                .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
        }
        .padding(.bottom, 20)
    }
}

/// 参考图：图标在上、文字在下，选中为浅绿圆角块
struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isSelected ? activeGreenFg : sidebarInactive)
                .frame(width: 22, height: 22)
            Text(item.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(isSelected ? activeGreenFg : sidebarInactive)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .partner
    @ObservedObject private var appearance = AppearanceStore.shared
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
                                .padding(.horizontal, 10)
                            }
                        }
                        .padding(.top, 4)
                    }

                    Button {
                        selectedItem = .profile
                    } label: {
                        SidebarRow(item: .profile, isSelected: selectedItem == .profile)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationSplitViewColumnWidth(min: 100, ideal: 115, max: 140)
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
    }
}

#Preview {
    ContentView()
}
