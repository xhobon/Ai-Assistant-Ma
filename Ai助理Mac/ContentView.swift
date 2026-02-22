import SwiftUI

/// 侧边栏项：参考图 6 项 + 原有的翻译、学习、设置
enum SidebarItem: Int, CaseIterable {
    case home = 0           // 首页 → AI助理
    case partner = 1        // 伙伴 → AI助理
    case writing = 2        // 写作 → AI助理
    case ppt = 3            // PPT → AI助理
    case notes = 4          // 笔记 → AI助理
    case summary = 5        // 总结 → AI助理
    case translate = 6      // 翻译（原有）
    case learning = 7       // 学习（原有）→ 印尼语学习
    case profile = 8        // 设置（原有）

    var title: String {
        switch self {
        case .home: return "首页"
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
        case .home: return "house"
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
    @State private var selectedItem: SidebarItem? = .home
    @ObservedObject private var appearance = AppearanceStore.shared
    private var primarySidebarItems: [SidebarItem] {
        SidebarItem.allCases.filter { $0 != .profile }
    }

    /// 根据当前选中的页面返回窗口标题
    private var currentWindowTitle: String {
        let item = selectedItem ?? .home
        switch item {
        case .home: return "首页"
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
                switch selectedItem ?? .home {
                case .home:
                    HomeView()
                case .partner:
                    AIAssistantChatView(title: "AI助理")
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
        .preferredColorScheme(appearance.colorScheme)
    }
}

#Preview {
    ContentView()
}
