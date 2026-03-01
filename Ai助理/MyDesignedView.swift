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
            VStack(spacing: 14) {
                profileCard
                vipCard
                sectionCard(title: "账户与设置", items: coreItems)
                sectionCard(title: "帮助与支持", items: supportItems)
                localDataCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .frame(maxWidth: pageMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            ZStack {
                AppTheme.pageBackground
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAuthSheet) {
            AuthView(mode: authMode)
        }
        .navigationDestination(isPresented: $showSettings) {
            AppSettingsView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showAccountCenter) {
            AccountProfileCenterView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showAssistantMemory) {
            AssistantMemoryView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showFAQ) {
            FAQView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showAbout) {
            AboutView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showSupport) {
            SupportView()
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $showMemberRecharge) {
            MemberRechargeView()
                .toolbar(.hidden, for: .tabBar)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.47, green: 0.63, blue: 1.0), Color(red: 0.66, green: 0.52, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tokenStore.isLoggedIn ? "已登录账号" : "未登录账号")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(tokenStore.isLoggedIn ? "账号同步已开启" : "登录后可同步收藏、翻译与学习记录")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
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
                        .foregroundStyle(.white)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.unifiedButtonPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    showSettings = true
                } label: {
                    Label("设置", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                profileMetaPill("本机数据", value: "已保护")
                profileMetaPill("同步状态", value: tokenStore.isLoggedIn ? "已开启" : "未开启")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.89, green: 0.93, blue: 1.0),
                            Color(red: 0.95, green: 0.91, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var vipCard: some View {
        Button {
            showMemberRecharge = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("会员中心")
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("解锁更长上下文、更快响应与高级工具")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.98, green: 0.73, blue: 0.33))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [AppTheme.surface, Color.white.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionCard(title: String, items: [MyActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        handleTap(item.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(red: 0.91, green: 0.95, blue: 1.0))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                        .padding(.horizontal, 12)
                        .frame(height: 66)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .background(AppTheme.surfaceMuted.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
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
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.red.opacity(0.18), lineWidth: 1)
                )
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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func profileMetaPill(_ title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.72))
        .clipShape(Capsule())
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
