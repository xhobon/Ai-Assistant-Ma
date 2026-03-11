import SwiftUI

/// 侧边栏项：助理为默认页 + 写作、PPT、记录、翻译、学习、设置
enum SidebarItem: Int, CaseIterable {
    case partner = 0        // 助理（默认）
    case writing = 1        // 写作
    case ppt = 2            // PPT
    case notesSummary = 3   // 记录（笔记/总结合并）
    case translate = 4      // 翻译
    case learning = 5       // 学习
    case profile = 6        // 设置

    var title: String {
        switch self {
        case .partner: return "助理"
        case .writing: return "写作"
        case .ppt: return "PPT"
        case .notesSummary: return "记录"
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
        case .notesSummary: return "note.text"
        case .translate: return "character.bubble"
        case .learning: return "book.fill"
        case .profile: return "gearshape"
        }
    }
}

private let sidebarActiveBg = AppTheme.primary.opacity(0.20)
private let sidebarActiveFg = AppTheme.primary
private let sidebarInactive = AppTheme.textSecondary

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
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? sidebarActiveBg : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .partner
    @State private var detailResetSeed = 0
    @State private var detailMounted = true
    @ObservedObject private var tokenStore = TokenStore.shared
    @State private var copyToastMessage: String?
    @State private var isCompactSidebarPresented = false
    @GestureState private var sidebarDragTranslation: CGFloat = 0
    @State private var sidebarSearchText: String = ""
    @State private var sidebarHistory: [CloudConversationSummary] = []
    @State private var isSidebarHistoryLoading = false
    @State private var hasLoadedSidebarHistory = false
    private var primarySidebarItems: [SidebarItem] {
        // 侧边栏只保留：助理、记录、翻译、学习（写作/PPT 入口已移动到助理页面的加号里）
        SidebarItem.allCases.filter { ![.profile, .writing, .ppt].contains($0) }
    }
    /// 根据当前选中的页面返回窗口标题
    private var currentWindowTitle: String {
        switch selectedItem {
        case .partner: return "AI助理"
        case .writing: return "写作"
        case .ppt: return "PPT"
        case .notesSummary: return "记录"
        case .translate: return "AI翻译"
        case .learning: return "印尼语学习"
        case .profile: return "设置"
        }
    }

    private func forceResetCurrentDetail(for item: SidebarItem) {
        // 强制卸载并重建 detail 子树，确保二级页面被关闭
        detailMounted = false
        DispatchQueue.main.async {
            selectedItem = item
            detailMounted = true
            detailResetSeed += 1
        }
    }

    private func selectSidebarItem(_ item: SidebarItem) {
        if selectedItem == item {
            forceResetCurrentDetail(for: item)
        } else {
            selectedItem = item
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            isCompactSidebarPresented = false
        }
    }

    private var sidebarWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.74, 300)
    }

    private func openSidebar() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            isCompactSidebarPresented = true
        }
    }

    private func closeSidebar() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            isCompactSidebarPresented = false
        }
    }
    
    private var sidebarToolbarButton: some View {
        Button {
            openSidebar()
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开侧边栏")
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 8) {
                sidebarSearchBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                sidebarNewChatButton
                    .padding(.horizontal, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(primarySidebarItems, id: \.rawValue) { item in
                            Button {
                                selectSidebarItem(item)
                            } label: {
                                SidebarRow(item: item, isSelected: selectedItem == item)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                        }
                        
                        sidebarHistorySection
                            .padding(.top, 6)
                    }
                    .padding(.top, 0)
                }
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)

                Button {
                    selectSidebarItem(.profile)
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
    }

    private var sidebarSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textTertiary)
            TextField("搜索历史对话", text: $sidebarSearchText)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.inputText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !sidebarSearchText.isEmpty {
                Button {
                    sidebarSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.unifiedButtonBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private var sidebarNewChatButton: some View {
        Button {
            selectedItem = .partner
            NotificationCenter.default.post(name: .sidebarNewConversation, object: nil)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                isCompactSidebarPresented = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("发起新对话")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.unifiedButtonBorder.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("发起新对话")
    }

    private var sidebarHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("历史对话")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 12)
            
            if isSidebarHistoryLoading {
                Text("加载中...")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 12)
            } else if filteredSidebarHistory.isEmpty {
                Text(sidebarSearchText.isEmpty ? "暂无历史对话" : "未找到匹配结果")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 12)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredSidebarHistory.prefix(12)) { item in
                        Button {
                            selectedItem = .partner
                            NotificationCenter.default.post(
                                name: .sidebarOpenConversation,
                                object: nil,
                                userInfo: ["id": item.id]
                            )
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                isCompactSidebarPresented = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                if !item.lastMessage.isEmpty {
                                    Text(item.lastMessage)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private var filteredSidebarHistory: [CloudConversationSummary] {
        let keyword = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return sidebarHistory }
        return sidebarHistory.filter { item in
            item.title.localizedCaseInsensitiveContains(keyword)
            || item.lastMessage.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func loadSidebarHistory() {
        Task { await loadSidebarHistoryAsync() }
    }

    private func loadSidebarHistoryAsync() async {
        isSidebarHistoryLoading = true
        defer { isSidebarHistoryLoading = false }
        
        if tokenStore.isLoggedIn {
            do {
                let cached = LocalDataStore.shared.loadCloudConversationSummaries()
                if !cached.isEmpty {
                    sidebarHistory = cached
                }
                if hasLoadedSidebarHistory {
                    return
                }
                let remote = try await APIClient.shared.getConversations(take: 50)
                sidebarHistory = remote
                LocalDataStore.shared.saveCloudConversationSummaries(remote)
                hasLoadedSidebarHistory = true
                return
            } catch {
                #if DEBUG
                print("[SidebarHistory] cloud conversations unavailable, fallback to local: \(error.localizedDescription)")
                #endif
            }
        }
        
        let all = LocalDataStore.shared.loadAllConversations()
        let formatter = ISO8601DateFormatter()
        let localList: [CloudConversationSummary] = all.map { (id, rows) in
            let last = rows.last
            let first = rows.first
            let lastText = (last?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstText = (first?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleRaw = (firstText?.isEmpty == false ? firstText! : "本地会话")
            let title = String(titleRaw.prefix(20))
            let lastTime = (last?["time"] as? TimeInterval) ?? Date().timeIntervalSince1970
            let firstTime = (first?["time"] as? TimeInterval) ?? lastTime
            return CloudConversationSummary(
                id: id,
                title: title,
                createdAt: formatter.string(from: Date(timeIntervalSince1970: firstTime)),
                updatedAt: formatter.string(from: Date(timeIntervalSince1970: lastTime)),
                lastMessage: String((lastText ?? "").prefix(80))
            )
        }
        sidebarHistory = localList.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var detailColumn: some View {
        Group {
            if detailMounted {
                switch selectedItem {
                case .partner:
                    AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
                case .writing:
                    WritingStudioView()
                case .ppt:
                    PPTStudioView()
                case .notesSummary:
                    NotesSummaryWorkspaceView(initialMode: .note)
                case .translate:
                    AITranslateHomeView()
                case .learning:
                    IndonesianLearningView()
                case .profile:
                    ProfileCenterView()
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hideNavigationBarOnMac()
        .id("detail-\(selectedItem.rawValue)-\(detailResetSeed)")
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        Group {
            NavigationStack {
                GeometryReader { proxy in
                    detailColumn
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 18)
                                .onEnded { value in
                                    guard !isCompactSidebarPresented else { return }
                                    let fromLeftEdge = value.startLocation.x <= 24
                                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                                    if fromLeftEdge && horizontal && value.translation.width > 72 {
                                        openSidebar()
                                    }
                                }
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.pageBackground.ignoresSafeArea())
                .navigationTitle(currentWindowTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !isCompactSidebarPresented {
                            sidebarToolbarButton
                        }
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if isCompactSidebarPresented {
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.18)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeSidebar()
                            }
                            .transition(.opacity)

                        sidebarContent
                            .frame(width: sidebarWidth)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .offset(x: min(0, sidebarDragTranslation))
                            .gesture(
                                DragGesture(minimumDistance: 12)
                                    .updating($sidebarDragTranslation) { value, state, _ in
                                        if value.translation.width < 0 {
                                            state = value.translation.width
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.width < -70 {
                                            closeSidebar()
                                        }
                                    }
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
                            .transition(.move(edge: .leading))
                    }
                    .zIndex(100)
                }
            }
            .onAppear {
                isCompactSidebarPresented = false
                loadSidebarHistory()
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isCompactSidebarPresented)
        }
        .onChange(of: selectedItem) { _, _ in
            // 切换侧边栏页面时停止语音播放，避免在其它页还能听到朗读
            SpeechService.shared.stopSpeaking()
        }
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .toast(message: $copyToastMessage)
        .onReceive(NotificationCenter.default.publisher(for: .globalCopySucceeded)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                copyToastMessage = "已复制到剪贴板"
            }
        }
        .onChange(of: tokenStore.token) { _, _ in
            loadSidebarHistory()
            hasLoadedSidebarHistory = false
        }
        .onChange(of: isCompactSidebarPresented) { _, isOpen in
            if isOpen {
                loadSidebarHistory()
            }
        }
    }
}

#Preview {
    ContentView()
}
