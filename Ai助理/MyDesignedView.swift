import SwiftUI

struct MyDesignedView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var tokenStore = TokenStore.shared
    @State private var showAuthSheet = false
    @State private var authMode: AuthMode = .login
    @State private var showAccountCenter = false
    @State private var showSettings = false
    @State private var showAssistantMemory = false
    @State private var showFAQ = false
    @State private var showAbout = false
    @State private var showSupport = false
    @State private var showClearConfirm = false
    @State private var showClearDone = false
    @State private var showMemberRecharge = false

    private let quickStats: [(String, String)] = [
        ("连续使用", "12天"),
        ("今日提问", "8次"),
        ("已生成", "32条")
    ]

    private let actionItems: [MyActionItem] = [
        .init(id: "settings", title: "通用设置", subtitle: "语音、外观、隐私", icon: "gearshape"),
        .init(id: "account", title: "账户中心", subtitle: "登录状态与资料", icon: "person.crop.circle"),
        .init(id: "memory", title: "助理记忆", subtitle: "长期偏好与上下文", icon: "brain.head.profile"),
        .init(id: "faq", title: "常见问题", subtitle: "快速排查与使用说明", icon: "questionmark.circle"),
        .init(id: "support", title: "在线客服", subtitle: "工作日 9:00-18:00", icon: "headphones"),
        .init(id: "about", title: "关于与文档", subtitle: "版本信息与协议", icon: "info.circle")
    ]
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                motivationBanner
                headerCard
                statsRow
                vipCard
                actionGrid
                dangerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 36)
            .frame(maxWidth: pageMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAuthSheet) {
            AuthView(mode: authMode)
        }
        .navigationDestination(isPresented: $showSettings) {
            AppSettingsView()
        }
        .navigationDestination(isPresented: $showAccountCenter) {
            AccountProfileCenterView()
        }
        .navigationDestination(isPresented: $showAssistantMemory) {
            AssistantMemoryView()
        }
        .navigationDestination(isPresented: $showFAQ) {
            FAQView()
        }
        .navigationDestination(isPresented: $showAbout) {
            AboutView()
        }
        .navigationDestination(isPresented: $showSupport) {
            SupportView()
        }
        .navigationDestination(isPresented: $showMemberRecharge) {
            MemberRechargeView()
        }
        .alert("清除所有记录", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                ClearDataStore.shared.clearAll()
                showClearDone = true
            }
        } message: {
            Text("将清除本机上的收藏、翻译历史等本地数据，且无法恢复。")
        }
        .alert("已清除", isPresented: $showClearDone) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("本地记录已清除。")
        }
    }

    private var motivationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hi，又是充满干劲的一天")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.35, green: 0.45, blue: 0.95), Color(red: 0.84, green: 0.35, blue: 0.72)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("近30天已完成 17 条任务，接待 11 次咨询")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.98, green: 0.94, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.78, green: 0.86, blue: 1.0), Color(red: 0.89, green: 0.82, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 62, height: 62)
                Image(systemName: "person.crop.circle.badge.sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tokenStore.isLoggedIn ? "已登录账号" : "未登录账号")
                    .font(.system(size: 20, weight: .bold))
                Text(tokenStore.isLoggedIn ? "账号同步已开启" : "登录后可同步收藏与历史")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                if tokenStore.isLoggedIn {
                    showAccountCenter = true
                } else {
                    authMode = .login
                    showAuthSheet = true
                }
            } label: {
                Text(tokenStore.isLoggedIn ? "个人中心" : "去登录")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.primary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.93, blue: 1.0), Color(red: 0.95, green: 0.90, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            ForEach(quickStats, id: \.0) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(item.1)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var vipCard: some View {
        Button {
            showMemberRecharge = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("会员中心")
                        .font(.system(size: 22, weight: .bold))
                    Text("解锁更长上下文、更快响应与高级工具")
                    .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundStyle(Color(red: 0.98, green: 0.73, blue: 0.33))
            }
            .padding(14)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.textPrimary)
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(actionItems) { item in
                Button {
                    handleTap(item.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(red: 0.92, green: 0.95, blue: 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dangerCard: some View {
        Button {
            showClearConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("清除本地记录")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
    }

    private func handleTap(_ id: String) {
        switch id {
        case "settings": showSettings = true
        case "account": showAccountCenter = true
        case "memory": showAssistantMemory = true
        case "faq": showFAQ = true
        case "support": showSupport = true
        case "about": showAbout = true
        default: break
        }
    }
}

private struct MyActionItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}
