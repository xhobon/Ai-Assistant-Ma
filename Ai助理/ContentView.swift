import SwiftUI

/// 侧边栏项：助理为默认页 + 写作、PPT、记录、翻译、学习、设置
enum SidebarItem: Int, CaseIterable {
    case partner = 0        // 助理（默认）
    case writing = 1        // 写作
    case ppt = 2            // PPT
    case notesSummary = 3   // 记录（笔记/总结合并）
    case translate = 4      // 翻译
    case learning = 5       // 学习
    case practice = 6       // 练习
    case profile = 7        // 设置

    var title: String {
        switch self {
        case .partner: return "助理"
        case .writing: return "写作"
        case .ppt: return "PPT"
        case .notesSummary: return "记录"
        case .translate: return "翻译"
        case .learning: return "学习"
        case .practice: return "练习"
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
        case .practice: return "bolt.fill"
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
    @EnvironmentObject private var languageStore: AppLanguageStore
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
            Text(languageStore.localized(item.title))
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
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var selectedItem: SidebarItem = .partner
    @State private var detailResetSeed = 0
    @State private var detailMounted = true
    @ObservedObject private var tokenStore = TokenStore.shared
    @ObservedObject private var syncStore = SyncStatusStore.shared
    @State private var copyToastMessage: String?
    @State private var isCompactSidebarPresented = false
    @GestureState private var sidebarDragTranslation: CGFloat = 0
    @State private var sidebarSearchText: String = ""
    @State private var sidebarHistory: [CloudConversationSummary] = []
    @State private var isSidebarHistoryLoading = false
    @State private var hasLoadedSidebarHistory = false
    @State private var showSidebarRenameDialog = false
    @State private var showSidebarDeleteConfirm = false
    @State private var sidebarRenameText: String = ""
    @State private var selectedSidebarItem: CloudConversationSummary?
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
        case .practice: return "练习"
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

            ChatSyncStatusRow(status: syncStore.status, errorText: syncStore.lastError)
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
                        .contextMenu {
                            Button("重命名") {
                                selectedSidebarItem = item
                                sidebarRenameText = item.title
                                showSidebarRenameDialog = true
                            }
                            Button("删除对话", role: .destructive) {
                                selectedSidebarItem = item
                                showSidebarDeleteConfirm = true
                            }
                        }
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
        sidebarHistory = LocalDataStore.shared.loadLocalConversationSummaries()
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
                case .practice:
                    PracticeHomeView()
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
                .navigationTitle(languageStore.localized(currentWindowTitle))
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
        .alert("重命名对话", isPresented: $showSidebarRenameDialog) {
            TextField("对话标题", text: $sidebarRenameText)
            Button("取消", role: .cancel) { selectedSidebarItem = nil }
            Button("保存") {
                guard let item = selectedSidebarItem else { return }
                let title = normalizeTitle(sidebarRenameText)
                Task { await renameSidebarConversation(id: item.id, title: title) }
                selectedSidebarItem = nil
            }
        } message: {
            Text("输入 6-20 个字符的标题")
        }
        .alert("删除对话", isPresented: $showSidebarDeleteConfirm) {
            Button("取消", role: .cancel) { selectedSidebarItem = nil }
            Button("删除", role: .destructive) {
                guard let item = selectedSidebarItem else { return }
                Task { await deleteSidebarConversation(id: item.id) }
                selectedSidebarItem = nil
            }
        } message: {
            Text("该操作将删除此对话及其消息，无法恢复。")
        }
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

    private func normalizeTitle(_ raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var chars = Array(cleaned)
        if chars.count > 20 {
            chars = Array(chars.prefix(20))
        }
        if chars.count < 6 {
            var padded = Array("关于") + chars + Array("对话")
            if padded.count < 6 {
                padded.append(contentsOf: Array("记录"))
            }
            return String(padded.prefix(20))
        }
        return String(chars)
    }

    private func renameSidebarConversation(id: String, title: String) async {
        guard !title.isEmpty else { return }
        if tokenStore.isLoggedIn {
            sidebarHistory = sidebarHistory.map { item in
                guard item.id == id else { return item }
                return CloudConversationSummary(
                    id: item.id,
                    title: title,
                    createdAt: item.createdAt,
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                    lastMessage: item.lastMessage
                )
            }
            LocalDataStore.shared.saveCloudConversationSummaries(sidebarHistory)
            LocalDataStore.shared.enqueuePendingTitleUpdate(id: id, title: title)
            syncStore.status = .syncing
            do {
                _ = try await APIClient.shared.updateConversationTitle(conversationId: id, title: title)
                LocalDataStore.shared.removePendingTitleUpdate(id: id)
                syncStore.status = .success
                syncStore.lastError = nil
            } catch {
                syncStore.status = .failed
                syncStore.lastError = error.localizedDescription
            }
        } else {
            LocalDataStore.shared.updateLocalConversationTitle(id: id, title: title)
            sidebarHistory = LocalDataStore.shared.loadLocalConversationSummaries()
        }
    }

    private func deleteSidebarConversation(id: String) async {
        if tokenStore.isLoggedIn {
            sidebarHistory.removeAll { $0.id == id }
            LocalDataStore.shared.saveCloudConversationSummaries(sidebarHistory)
            LocalDataStore.shared.enqueuePendingDelete(id: id)
            syncStore.status = .syncing
            do {
                try await APIClient.shared.deleteConversation(conversationId: id)
                LocalDataStore.shared.removePendingDelete(id: id)
                syncStore.status = .success
                syncStore.lastError = nil
            } catch {
                syncStore.status = .failed
                syncStore.lastError = error.localizedDescription
            }
        } else {
            LocalDataStore.shared.deleteConversation(id: id)
            sidebarHistory = LocalDataStore.shared.loadLocalConversationSummaries()
        }
    }
}

#Preview {
    ContentView()
}
