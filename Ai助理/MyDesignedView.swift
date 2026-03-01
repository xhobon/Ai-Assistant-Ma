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

    private let coreItems: [MyActionItem] = [
        .init(id: "account", title: "账户中心", subtitle: "登录状态、资料与安全", icon: "person.crop.circle"),
        .init(id: "settings", title: "通用设置", subtitle: "语音、外观、隐私与通知", icon: "gearshape"),
        .init(id: "memory", title: "助理记忆", subtitle: "管理偏好与长期上下文", icon: "brain.head.profile")
    ]

    private let supportItems: [MyActionItem] = [
        .init(id: "faq", title: "常见问题", subtitle: "快速排查与使用说明", icon: "questionmark.circle"),
        .init(id: "support", title: "在线客服", subtitle: "工作日 9:00-18:00", icon: "headphones"),
        .init(id: "about", title: "关于与文档", subtitle: "版本信息与协议条款", icon: "info.circle")
    ]

    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                profileCard
                vipCard
                sectionCard(title: "账户与设置", items: coreItems)
                sectionCard(title: "帮助与支持", items: supportItems)
                localDataCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
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

    private var profileCard: some View {
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

            VStack(alignment: .trailing, spacing: 8) {
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

                Button {
                    showSettings = true
                } label: {
                    Text("设置")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.72))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.93, blue: 1.0), Color(red: 0.95, green: 0.90, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
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

    private func sectionCard(title: String, items: [MyActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(items) { item in
                Button {
                    handleTap(item.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(red: 0.92, green: 0.95, blue: 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(12)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var localDataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本地数据")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

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
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)

            Text("仅清除本机收藏、翻译历史、学习记录，不影响账号信息。")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
