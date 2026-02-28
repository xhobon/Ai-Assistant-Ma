import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ProfileCenterView: View {
    @State private var showAuthSheet = false
    @State private var authMode: AuthMode = .login
    @State private var showMemberRecharge = false
    @State private var showTaskCenter = false
    @State private var showSettings = false
    @State private var showClearConfirm = false
    @State private var showClearDone = false
    // 快捷入口
    @State private var showFavorites = false
    @State private var showWallet = false
    @State private var showShareGift = false
    // 设置入口
    @State private var showAccount = false
    // 服务与支持
    @State private var showAbout = false
    @State private var showFAQ = false
    @State private var showSupport = false
    @State private var showAssistantMemory = false

    private let quickActions: [ProfileQuickAction] = [
        ProfileQuickAction(id: "fav", title: "我的收藏", icon: "star.fill"),
        ProfileQuickAction(id: "wallet", title: "我的钱包", icon: "wallet.pass"),
        ProfileQuickAction(id: "task", title: "任务中心", icon: "calendar.badge.checkmark"),
        ProfileQuickAction(id: "gift", title: "分享有礼", icon: "gift.fill")
    ]

    private let settingsItems: [ProfileMenuItem] = [
        ProfileMenuItem(id: "settings", title: "通用设置", subtitle: "语音、外观、隐私与本地数据", icon: "gearshape"),
        ProfileMenuItem(id: "account", title: "账户与安全", subtitle: "登录状态与设备安全", icon: "shield.fill"),
        ProfileMenuItem(id: "memory", title: "助理记忆", subtitle: "偏好与长期记忆管理", icon: "brain.head.profile")
    ]

    private let helpItems: [ProfileMenuItem] = [
        ProfileMenuItem(id: "faq", title: "常见问题", subtitle: "快速排查与使用说明", icon: "questionmark.circle"),
        ProfileMenuItem(id: "support", title: "在线客服", subtitle: "工作日 9:00-18:00", icon: "headphones"),
        ProfileMenuItem(id: "about", title: "关于与文档", subtitle: "版本信息、协议条款、会员规则", icon: "info.circle"),
        ProfileMenuItem(id: "clear", title: "清除所有记录", subtitle: "聊天、学习、翻译", icon: "trash")
    ]

    var body: some View {
        NavigationStack {
            AppPageScaffold(maxWidth: 960, spacing: 18) {
                ProfileLoginCard {
                    authMode = .login
                    showAuthSheet = true
                }

                VIPBannerCard {
                    showMemberRecharge = true
                }

                ProfileQuickActionRow(actions: quickActions) { action in
                    switch action.id {
                    case "fav": showFavorites = true
                    case "wallet": showWallet = true
                    case "task": showTaskCenter = true
                    case "gift": showShareGift = true
                    default: break
                    }
                }

                ProfileSectionHeader(title: "设置入口")
                ProfileMenuList(items: settingsItems) { item in
                    switch item.id {
                    case "settings": showSettings = true
                    case "account": showAccount = true
                    case "memory": showAssistantMemory = true
                    default: break
                    }
                }
                ProfileHintCard(text: "在设置中可管理通知、隐私与语言等选项，确保你的对话记录与个人信息安全。")

                ProfileSectionHeader(title: "服务与支持")
                ProfileMenuList(items: helpItems) { item in
                    switch item.id {
                    case "faq": showFAQ = true
                    case "support": showSupport = true
                    case "about": showAbout = true
                    case "clear": showClearConfirm = true
                    default: break
                    }
                }
            }
            .navigationDestination(isPresented: $showMemberRecharge) {
                MemberRechargeView()
            }
            .navigationDestination(isPresented: $showTaskCenter) {
                TaskCenterView()
            }
            .navigationDestination(isPresented: $showSettings) {
                AppSettingsView()
            }
            .navigationDestination(isPresented: $showFavorites) {
                MyFavoritesView()
            }
            .navigationDestination(isPresented: $showWallet) {
                MyWalletView()
            }
            .navigationDestination(isPresented: $showShareGift) {
                ShareGiftView()
            }
            .navigationDestination(isPresented: $showAccount) {
                AccountSecurityView()
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
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView(mode: authMode)
        }
        .alert("清除所有记录", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                ClearDataStore.shared.clearAll()
                showClearDone = true
            }
        } message: {
            Text("将清除本机上的收藏、翻译历史等本地数据，且无法恢复。登录后数据可同步至账号；未登录时卸载应用也会清空。")
        }
        .alert("已清除", isPresented: $showClearDone) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("本地记录已清除。")
        }
    }
}

struct ProfileLoginCard: View {
    var onLogin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.primaryGradient.opacity(0.16))
                    .frame(width: 56, height: 56)
                Image(systemName: "person.crop.circle.badge.sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("未登录账号")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("登录后可同步收藏、翻译和学习记录")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Text("去登录")
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(AppTheme.primary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow, radius: 10, x: 0, y: 4)
        .onTapGesture {
            onLogin()
        }
    }
}

struct VIPBannerCard: View {
    var onUnlock: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 52, height: 52)
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VIP会员")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textOnPrimary)
                Text("升级解锁全部功能与更高额度")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textOnPrimary.opacity(0.82))
            }

            Spacer()

            UnifiedAppButton(
                title: "立即解锁",
                systemImage: nil,
                style: .outline,
                action: onUnlock
            )
            .frame(width: 102)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.primary,
                    AppTheme.secondary,
                    AppTheme.primary.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: AppTheme.primary.opacity(0.22), radius: 12, x: 0, y: 5)
    }
}

struct ProfileSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(AppTheme.primaryGradient)
                .frame(width: 8, height: 22)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct MemberBenefit: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

struct MemberPlan: Identifiable, Hashable {
    let id: String
    let title: String
    let price: String
    let originalPrice: String
    let badge: String?
}

struct PaymentOption: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
}

struct MemberBenefitsCard: View {
    let benefits: [MemberBenefit]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会员专享 4 大权益")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(benefits) { benefit in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(benefit.tint.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: benefit.systemImage)
                                .foregroundStyle(benefit.tint)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(benefit.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(benefit.subtitle)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MemberCenterEntryCard: View {
    var onUnlock: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentWarm.opacity(0.18))
                    .frame(width: 50, height: 50)
                Image(systemName: "crown.fill")
                    .foregroundStyle(AppTheme.accentWarm)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("充值会员")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("进入会员中心选择套餐与支付方式")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: onUnlock) {
                Text("立即解锁")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.unifiedButtonPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MemberPlanCard: View {
    let plans: [MemberPlan]
    @Binding var selectedPlanId: String
    var onUnlock: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(plans) { plan in
                    Button {
                        selectedPlanId = plan.id
                    } label: {
                        VStack(spacing: 8) {
                            if let badge = plan.badge {
                                Text(badge)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.accentWarm.opacity(0.25))
                                    .clipShape(Capsule())
                            } else {
                                Color.clear
                                    .frame(height: 20)
                            }

                            Text(plan.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("¥\(plan.price)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.accentStrong)

                            Text("¥\(plan.originalPrice)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .strikethrough()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedPlanId == plan.id ? AppTheme.accent.opacity(0.12) : AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selectedPlanId == plan.id ? AppTheme.accentStrong.opacity(0.6) : Color.clear, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onUnlock) {
                Text("立即解锁")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.unifiedButtonPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct PaymentOptionCard: View {
    let options: [PaymentOption]
    @Binding var selectedId: String

    var body: some View {
        VStack(spacing: 12) {
            ForEach(options) { option in
                Button {
                    selectedId = option.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.systemImage)
                            .foregroundStyle(option.id == "wechat" ? .green : AppTheme.brandBlue)

                        Text(option.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Image(systemName: selectedId == option.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedId == option.id ? AppTheme.accentStrong : AppTheme.textSecondary.opacity(0.5))
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if option.id != options.last?.id {
                    Divider().padding(.leading, 32)
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ProfileHintCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppTheme.primary)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .background(AppTheme.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct ProfileQuickActionRow: View {
    let actions: [ProfileQuickAction]
    var onAction: (ProfileQuickAction) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(actions) { action in
                Button {
                    onAction(action)
                } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.primaryGradient.opacity(0.15))
                                .frame(width: 46, height: 46)
                            Image(systemName: action.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }
                        Text(action.title)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceMuted.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct ProfileMenuList: View {
    let items: [ProfileMenuItem]
    var onItemTap: (ProfileMenuItem) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    onItemTap(item)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.primary.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: item.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // 关键：让整行（含空白区域）都可点击
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.id != items.last?.id {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .padding(6)
        .background(AppTheme.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct ProfileQuickAction: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
}

struct ProfileMenuItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
}

// MARK: - Member Recharge

struct MemberRechargeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlanId: String = "life"
    @State private var selectedPaymentId: String = "wechat"

    private let benefits: [MemberBenefit] = [
        MemberBenefit(id: "reply", title: "无限制回复", subtitle: "高峰时段优先响应", systemImage: "sparkles", tint: .orange),
        MemberBenefit(id: "translate", title: "无限制翻译", subtitle: "多语种实时互译", systemImage: "globe", tint: .blue),
        MemberBenefit(id: "study", title: "解锁专业学习", subtitle: "提升学习与创作效率", systemImage: "graduationcap.fill", tint: .purple),
        MemberBenefit(id: "assistant", title: "私人助理", subtitle: "专属高效解决方案", systemImage: "person.fill.badge.plus", tint: .teal)
    ]

    private let plans: [MemberPlan] = [
        MemberPlan(id: "life", title: "终身会员", price: "188", originalPrice: "398", badge: "最多人买"),
        MemberPlan(id: "year", title: "年度会员", price: "108", originalPrice: "342", badge: nil),
        MemberPlan(id: "quarter", title: "季度会员", price: "88", originalPrice: "168", badge: nil)
    ]

    private let paymentOptions: [PaymentOption] = [
        PaymentOption(id: "wechat", title: "微信支付", systemImage: "message.fill"),
        PaymentOption(id: "alipay", title: "支付宝支付", systemImage: "a.circle.fill")
    ]

    var body: some View {
        AppPageScaffold(maxWidth: 960, spacing: 18) {
            MemberRechargeHeader {
                dismiss()
            }

            MemberBenefitsCard(benefits: benefits)

            ProfileSectionHeader(title: "充值会员", subtitle: "推荐永久会员方案")
            MemberPlanCard(plans: plans, selectedPlanId: $selectedPlanId) {
            }
            PaymentOptionCard(options: paymentOptions, selectedId: $selectedPaymentId)
        }
    }
}

struct MemberRechargeHeader: View {
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }

                Spacer()

                Text("会员中心")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Color.clear
                    .frame(width: 36, height: 36)
            }

            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.primary.opacity(0.9),
                                AppTheme.secondary.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VIP会员")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textOnPrimary)
                        Text("升级解锁全部功能")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textOnPrimary.opacity(0.7))
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(AppTheme.accentWarm.opacity(0.9))
                            .frame(width: 68, height: 68)
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.textOnPrimary)
                    }
                }
                .padding(16)
            }
            .frame(height: 120)
        }
        .padding(.top, 16)
    }
}

// MARK: - Task Center

struct TaskCenterView: View {
    @Environment(\.dismiss) private var dismiss

    private let tasks: [RewardTask] = [
        RewardTask(
            id: "share",
            title: "每日分享 3 个好友",
            subtitle: "每分享 1 个，可得天数+1",
            progress: 0,
            progressText: "0/3",
            actionTitle: "去分享",
            systemImage: "arrowshape.turn.up.right.fill"
        ),
        RewardTask(
            id: "invite",
            title: "每日邀请 5 个新用户",
            subtitle: "每邀请 1 人，可得天数+5",
            progress: 0,
            progressText: "0/5",
            actionTitle: "去邀请",
            systemImage: "person.crop.circle.badge.plus"
        )
    ]

    var body: some View {
        AppPageScaffold(maxWidth: 960, spacing: 18) {
            TaskCenterHeader {
                dismiss()
            }

            TaskSummaryCard(availableDays: 0)

            TaskListCard(tasks: tasks)
        }
    }
}

struct RewardTask: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let progress: Double
    let progressText: String
    let actionTitle: String
    let systemImage: String
}

struct TaskCenterHeader: View {
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }

                Spacer()

                Text("每日奖励任务")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.top, 16)
    }
}

struct TaskSummaryCard: View {
    let availableDays: Int

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(availableDays)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.accentWarm)
                Text("可用天数")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surfaceMuted)
                Image(systemName: "calendar")
                    .font(.system(size: 38))
                    .foregroundStyle(AppTheme.accentWarm)
            }
            .frame(width: 120, height: 80)
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TaskListCard: View {
    let tasks: [RewardTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("做任务 领次数")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(tasks) { task in
                TaskRow(task: task)

                if task.id != tasks.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TaskRow: View {
    let task: RewardTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentWarm.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: task.systemImage)
                    .foregroundStyle(AppTheme.accentWarm)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    UnifiedAppButton(
                        title: task.actionTitle,
                        systemImage: nil,
                        style: .primary
                    ) {
                        ClipboardService.copy("\(task.title)\n\(task.subtitle)")
                    }
                    .frame(width: 88)
                }

                Text(task.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 10) {
                    ProgressView(value: task.progress)
                        .tint(AppTheme.accentWarm)
                        .frame(maxWidth: .infinity)
                    Text(task.progressText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Settings

struct AppSettingsView: View {
    @ObservedObject private var speechSettings = SpeechSettingsStore.shared
    @ObservedObject private var appearance = AppearanceStore.shared
    @State private var showClearConfirm = false
    @State private var toastMessage: String?
    @State private var showAccountSecurity = false
    @State private var showFAQ = false
    @State private var showSupport = false

    private var speedLabel: String {
        let r = speechSettings.speechRate
        if r < 0.42 { return "较慢" }
        if r > 0.54 { return "较快" }
        return "正常"
    }

    var body: some View {
        SettingsPage(title: "设置") {
            SettingsCard(
                title: "快捷入口",
                subtitle: "常用设置与帮助集中在这里。"
            ) {
                SettingsRow(
                    systemImage: "shield.lefthalf.filled",
                    title: "账户与安全",
                    subtitle: "查看登录状态与安全说明",
                    showChevron: true
                ) {
                    showAccountSecurity = true
                }
                SettingsRow(
                    systemImage: "questionmark.circle",
                    title: "常见问题",
                    subtitle: "快速排查使用问题",
                    showChevron: true
                ) {
                    showFAQ = true
                }
                SettingsRow(
                    systemImage: "headphones",
                    title: "在线客服",
                    subtitle: "工作日 9:00-18:00",
                    showChevron: true
                ) {
                    showSupport = true
                }
            }

            SettingsCard(
                title: "语音与朗读",
                subtitle: "控制语音播报开关、语速与音质。"
            ) {
                SettingsInlineToggleRow(
                    systemImage: speechSettings.playbackMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    title: "语音播报",
                    subtitle: speechSettings.playbackMuted ? "已关闭" : "已开启",
                    isOn: Binding(
                        get: { !speechSettings.playbackMuted },
                        set: { speechSettings.playbackMuted = !$0 }
                    )
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("语速")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(speedLabel)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        UnifiedAppButton(
                            title: "试听",
                            systemImage: "play.circle.fill",
                            style: .primary
                        ) {
                            SpeechService.shared.speak("这是一个示例播报，用来预览当前语音设置。", language: "zh-CN")
                        }
                        .frame(width: 96)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(speechSettings.speechRate) },
                            set: { speechSettings.speechRate = Float($0) }
                        ),
                        in: 0.3...0.6,
                        step: 0.02
                    )
                    .tint(AppTheme.primary)
                }
                .padding(12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("语音质量")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("在线更自然；离线由系统语音决定。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Picker("语音质量", selection: Binding(
                            get: { speechSettings.voiceQuality },
                            set: { speechSettings.voiceQuality = $0 }
                        )) {
                            Text("在线（更自然）").tag("online")
                            Text("优质").tag("premium")
                            Text("增强").tag("enhanced")
                            Text("默认").tag("default")
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }

            SettingsCard(
                title: "外观与显示",
                subtitle: "选择浅色/深色模式，或跟随系统。"
            ) {
                Picker("深色模式", selection: Binding(
                    get: { appearance.mode },
                    set: { appearance.mode = $0 }
                )) {
                    Text("跟随系统").tag(AppearanceStore.Mode.system)
                    Text("浅色").tag(AppearanceStore.Mode.light)
                    Text("深色").tag(AppearanceStore.Mode.dark)
                }
                .pickerStyle(.segmented)

                SettingsRow(
                    systemImage: "circle.lefthalf.filled",
                    title: "当前模式",
                    subtitle: appearance.mode == .system ? "跟随系统" : (appearance.mode == .dark ? "深色模式" : "浅色模式"),
                    showChevron: false,
                    action: nil
                )
            }

            SettingsCard(
                title: "隐私与数据",
                subtitle: "管理本地数据与同步状态。"
            ) {
                SettingsRow(
                    systemImage: TokenStore.shared.isLoggedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark",
                    title: "登录状态",
                    subtitle: TokenStore.shared.isLoggedIn ? "已登录" : "未登录",
                    value: nil,
                    tint: TokenStore.shared.isLoggedIn ? AppTheme.primary : AppTheme.textPrimary,
                    showChevron: false,
                    action: nil
                )

                SettingsRow(
                    systemImage: "icloud",
                    title: "数据同步",
                    subtitle: TokenStore.shared.isLoggedIn ? "已启用账号同步（按功能逐步开放）" : "未登录，仅保存在本机",
                    showChevron: false,
                    action: nil
                )

                SettingsRow(
                    systemImage: "hand.raised.fill",
                    title: "隐私说明",
                    subtitle: "我们不会在未经同意的情况下共享你的个人数据。",
                    showChevron: false,
                    action: nil
                )
                SettingsRow(
                    systemImage: "trash",
                    title: "清除所有本地记录",
                    subtitle: "收藏、翻译历史、部分偏好等",
                    isDestructive: true,
                    showChevron: true
                ) {
                    showClearConfirm = true
                }
            }
        }
        .toast(message: $toastMessage)
        .navigationDestination(isPresented: $showAccountSecurity) {
            AccountSecurityView()
        }
        .navigationDestination(isPresented: $showFAQ) {
            FAQView()
        }
        .navigationDestination(isPresented: $showSupport) {
            SupportView()
        }
        .confirmationDialog(
            "清除所有本地记录？",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清除", role: .destructive) {
                ClearDataStore.shared.clearAll()
                withAnimation(.easeInOut(duration: 0.2)) {
                    toastMessage = "已清除本地记录"
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该操作不可恢复。登录用户的云端数据不会被删除。")
        }
    }
}

// MARK: - 助理记忆（长期记忆与自主学习）

struct AssistantMemoryView: View {
    @State private var items: [UserMemoryItem] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var newContent = ""
    @State private var newCategory = "fact"
    @State private var showAddSheet = false

    private var isLoggedIn: Bool { TokenStore.shared.isLoggedIn }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("助理会根据聊天与使用情况自动记住你的偏好和重要信息，也可在此手动添加。登录后记忆会同步到你的账号。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal)

                if loading && items.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("加载中…")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else if let err = errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding()
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Text(categoryLabel(item.category))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                Text(item.content)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    deleteItem(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("助理记忆")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newContent = ""
                    newCategory = "fact"
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                    Text("添加")
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .onAppear { loadMemories() }
        .sheet(isPresented: $showAddSheet) {
            addMemorySheet
        }
    }

    private var addMemorySheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("例如：偏好简洁回答、常用印尼语翻译", text: $newContent, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .foregroundStyle(AppTheme.inputText)
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                Picker("类型", selection: $newCategory) {
                    Text("事实").tag("fact")
                    Text("偏好").tag("preference")
                    Text("习惯").tag("habit")
                }
                .pickerStyle(.segmented)
                .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(20)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("添加记忆")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showAddSheet = false
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveNewMemory()
                        showAddSheet = false
                    }
                    .foregroundStyle(AppTheme.primary)
                    .disabled(newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func categoryLabel(_ c: String) -> String {
        switch c {
        case "preference": return "偏好"
        case "habit": return "习惯"
        default: return "事实"
        }
    }

    private func loadMemories() {
        loading = true
        errorMessage = nil
        Task {
            do {
                if isLoggedIn {
                    let local = LocalDataStore.shared.loadMemories()
                    if !local.isEmpty {
                        try await APIClient.shared.addMemories(local.map { ($0.content, $0.category) })
                        LocalDataStore.shared.saveMemories([])
                    }
                    let list = try await APIClient.shared.getMemories()
                    await MainActor.run {
                        items = list
                        loading = false
                    }
                } else {
                    await MainActor.run {
                        items = LocalDataStore.shared.loadMemories()
                        loading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = userFacingMessage(for: error)
                    loading = false
                }
            }
        }
    }

    private func saveNewMemory() {
        let content = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let item = UserMemoryItem.from(content, category: newCategory)
        if isLoggedIn {
            Task {
                do {
                    try await APIClient.shared.addMemories([(content: content, category: newCategory)])
                    await MainActor.run { loadMemories() }
                } catch {
                    await MainActor.run { errorMessage = userFacingMessage(for: error) }
                }
            }
        } else {
            LocalDataStore.shared.addMemory(item)
            items.insert(item, at: 0)
        }
    }

    private func deleteItem(_ item: UserMemoryItem) {
        if isLoggedIn {
            Task {
                do {
                    try await APIClient.shared.deleteMemory(id: item.id)
                    await MainActor.run { items.removeAll { $0.id == item.id } }
                } catch {
                    await MainActor.run { errorMessage = userFacingMessage(for: error) }
                }
            }
        } else {
            LocalDataStore.shared.removeMemory(id: item.id)
            items.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - Auth

enum AuthMode: String, CaseIterable, Identifiable {
    case login = "登录"
    case register = "注册"

    var id: String { rawValue }
}

struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State var mode: AuthMode
    @State private var email = ""
    @State private var displayName = ""
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var isSendingCode = false
    @State private var message: String?
    @State private var statusText: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case displayName
        case code
    }

    private var isSendCodeDisabled: Bool {
        isSendingCode || isSubmitting || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var submitButtonTitle: String {
        isSubmitting ? "提交中..." : (mode == .login ? "登录" : "注册")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        AuthHeaderCard(mode: mode)
                        modeSwitchSection
                        formSection
                        statusSection
                        submitSection
                    }
                    .frame(maxWidth: 860)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("账户")
            .toolbar { backToolbarItem }
        }
        .alert("提示", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    @ToolbarContentBuilder
    private var backToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("返回")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppTheme.textPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    private var modeSwitchSection: some View {
        HStack(spacing: 8) {
            ForEach(AuthMode.allCases) { item in
                modePill(item)
            }
        }
        .padding(6)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func modePill(_ item: AuthMode) -> some View {
        Button {
            mode = item
            statusText = nil
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(mode == item ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(AppTheme.surface))
                Text(item.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(mode == item ? AppTheme.textOnPrimary : AppTheme.textPrimary)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    private var formSection: some View {
        VStack(spacing: 12) {
            AuthTextField(title: "邮箱", placeholder: "name@email.com", text: $email)
                .focused($focusedField, equals: .email)

            if mode == .register {
                AuthTextField(title: "昵称", placeholder: "请输入昵称", text: $displayName)
                    .focused($focusedField, equals: .displayName)
            }

            codeFieldSection
        }
    }

    private var codeFieldSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("验证码")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 10) {
                TextField("请输入邮箱验证码", text: $code)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.inputText)
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .focused($focusedField, equals: .code)

                Button {
                    onTapSendCode()
                } label: {
                    HStack(spacing: 6) {
                        if isSendingCode {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppTheme.textOnPrimary)
                        }
                        Text(isSendingCode ? "发送中" : "发送验证码")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(minWidth: 110)
                    .padding(.vertical, 10)
                    .background(AppTheme.primaryGradient)
                    .foregroundStyle(AppTheme.textOnPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSendCodeDisabled)
                .opacity(isSendCodeDisabled ? 0.55 : 1)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusText, !statusText.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.primary)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var submitSection: some View {
        HStack(spacing: 10) {
            Button {
                onTapSubmit()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(submitButtonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.primaryGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppTheme.primary.opacity(0.22), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || isSendingCode)
            .opacity((isSubmitting || isSendingCode) ? 0.7 : 1)

            Button {
                onTapGoogleSignIn()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Google")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(minWidth: 118)
                .padding(.vertical, 13)
                .padding(.horizontal, 12)
                .background(AppTheme.surface)
                .foregroundStyle(AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.borderStrong.opacity(0.75), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || isSendingCode)
            .opacity((isSubmitting || isSendingCode) ? 0.65 : 1)
        }
    }

    private func validateEmail() -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "请输入邮箱" }
        if !trimmed.contains("@") { return "邮箱格式不正确" }
        return nil
    }

    @MainActor
    private func onTapSendCode() {
        guard !isSendingCode, !isSubmitting else { return }
        if let err = validateEmail() {
            message = err
            return
        }
        isSendingCode = true
        statusText = "正在发送验证码..."
        let targetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let purpose = mode == .login ? "login" : "register"

        Task {
            do {
                let codeReturned = try await APIClient.shared.sendEmailCode(email: targetEmail, purpose: purpose)
                await MainActor.run {
                    statusText = "验证码已发送，请在 10 分钟内完成验证"
                    if let c = codeReturned, !c.isEmpty {
                        message = "验证码已发送，请在 10 分钟内完成验证。\n\n当前测试环境，本次验证码为：\(c)"
                    } else {
                        message = "验证码已发送，请在 10 分钟内完成验证。"
                    }
                }
            } catch {
                await MainActor.run {
                    statusText = "发送失败，请重试"
                    message = userFacingMessage(for: error)
                }
            }
            await MainActor.run {
                isSendingCode = false
            }
        }
    }

    @MainActor
    private func onTapSubmit() {
        guard !isSubmitting, !isSendingCode else { return }
        if let err = validateEmail() {
            message = err
            return
        }
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.isEmpty {
            message = "请输入验证码"
            return
        }
        if mode == .register && displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message = "请输入昵称"
            return
        }

        isSubmitting = true
        statusText = "正在验证账号信息..."
        let targetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let auth: AuthResponse
                if mode == .login {
                    auth = try await APIClient.shared.loginWithEmailCode(email: targetEmail, code: trimmedCode)
                } else {
                    auth = try await APIClient.shared.registerWithEmailCode(
                        email: targetEmail,
                        code: trimmedCode,
                        displayName: targetName
                    )
                }
                await MainActor.run {
                    TokenStore.shared.token = auth.token
                    statusText = "登录成功"
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    statusText = "提交失败，请检查验证码或网络"
                    message = userFacingMessage(for: error)
                }
            }
            await MainActor.run {
                isSubmitting = false
            }
        }
    }

    @MainActor
    private func onTapGoogleSignIn() {
        statusText = "正在准备 Google 登录..."
        message = "Google 登录入口已添加。请在后端配置 OAuth 后，我可以继续帮你接通完整登录流程。"
    }
}

struct AuthHeaderCard: View {
    let mode: AuthMode

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.primaryGradient.opacity(0.16))
                    .frame(width: 56, height: 56)
                Image(systemName: mode == .login ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(mode == .login ? "欢迎回来" : "创建新账号")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(mode == .login ? "登录后即可同步您的数据" : "注册后即可使用完整功能与数据同步")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.borderStrong.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 3)
    }
}

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.inputText)
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.borderStrong.opacity(0.55), lineWidth: 1)
                    )
        }
    }
}

struct AuthSocialButton: View {
    let title: String
    let icon: String

    var body: some View {
        Button {
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 我的收藏（学习词汇收藏）

struct MyFavoritesView: View {
    @StateObject private var viewModel = LearningViewModel()

    private var favoriteItems: [VocabItem] {
        viewModel.categories.flatMap { $0.items }.filter { viewModel.isFavorite($0) }
    }

    var body: some View {
        SettingsPage(title: "我的收藏") {
            SettingsCard(title: "已收藏词汇", subtitle: "在学习页将词汇或句子加入收藏后，会显示在这里。") {
                if favoriteItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                        Text("暂无收藏")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("在学习页将词汇或句子加入收藏后，会显示在这里")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(favoriteItems) { item in
                            FavoriteVocabRow(item: item, isFavorite: true) {
                                viewModel.toggleFavorite(item)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct FavoriteVocabRow: View {
    let item: VocabItem
    let isFavorite: Bool
    var onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.textZh)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(item.textId)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(item.exampleZh)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? AppTheme.accentWarm : AppTheme.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - 我的钱包

struct MyWalletView: View {
    var body: some View {
        SettingsPage(title: "我的钱包") {
            SettingsCard(title: "账户余额", subtitle: "当前可用余额") {
                Text("¥ 0.00")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            SettingsCard(title: "收支记录", subtitle: "最近交易记录") {
                Text("暂无记录")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - 分享有礼

struct ShareGiftView: View {
    @State private var toastMessage: String?
    private let inviteURL = "https://ai-assistant.example.com/invite"

    var body: some View {
        SettingsPage(title: "分享有礼") {
            SettingsCard(title: "邀请好友，双方各得奖励", subtitle: "每成功邀请 1 位好友注册并登录，您与好友均可获得 3 天会员体验。多邀多得，上不封顶。") {
                VStack(spacing: 16) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.accentWarm)
                    Button {
                        ClipboardService.copy(inviteURL)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toastMessage = "邀请链接已复制"
                        }
                    } label: {
                        Label("分享邀请链接", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.unifiedButtonPrimary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 8)
                }
            }
        }
        .toast(message: $toastMessage)
    }
}

// MARK: - 账户与安全

struct AccountSecurityView: View {
    var body: some View {
        SettingsPage(title: "账户与安全") {
            SettingsCard(
                title: "登录状态",
                subtitle: "登录后可同步数据，并启用云端长期记忆。"
            ) {
                SettingsRow(
                    systemImage: TokenStore.shared.isLoggedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark",
                    title: TokenStore.shared.isLoggedIn ? "已登录" : "未登录",
                    subtitle: TokenStore.shared.isLoggedIn ? "当前设备已授权访问你的云端数据" : "登录后可跨设备同步聊天、翻译与学习记录",
                    tint: TokenStore.shared.isLoggedIn ? AppTheme.primary : AppTheme.textPrimary,
                    showChevron: false,
                    action: nil
                )
            }

            SettingsCard(
                title: "安全建议",
                subtitle: "以下建议可提升账号与数据安全。"
            ) {
                SecurityTipRow(systemImage: "checkmark.shield", text: "不要在公共设备上长期保持登录状态。")
                SecurityTipRow(systemImage: "person.crop.circle.badge.exclamationmark", text: "账号异常时请立即联系客服处理。")
                SecurityTipRow(systemImage: "externaldrive.badge.icloud", text: "登录后可获得更完整的数据同步能力。")
            }
        }
    }
}

// MARK: - 会员说明

struct MemberExplainView: View {
    var body: some View {
        SettingsPage(title: "会员说明") {
            SettingsCard(title: "会员规则", subtitle: "权益、续费与退款说明") {
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle("会员权益")
                    Text("• 无限制 AI 对话与翻译\n• 专业学习内容与场景解锁\n• 优先响应与专属助理能力\n• 更多权益持续更新")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    sectionTitle("自动续费规则")
                    Text("订阅周期内可随时在系统设置中关闭自动续费。到期前 24 小时内扣款；若取消续费，到期后将恢复为免费版，已解锁内容在当期内仍可使用。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    sectionTitle("退款说明")
                    Text("虚拟会员服务一经开通，如无特殊故障，原则上不支持退款。如有异议请联系客服。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

// MARK: - 常见问题

struct FAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
}

struct FAQView: View {
    @State private var expandedId: String?

    private let items: [FAQItem] = [
        FAQItem(id: "1", question: "如何收藏词汇或句子？", answer: "在学习页中，点击词汇或句子旁的星标即可加入收藏；再次点击可取消。收藏内容会在「我的」—「我的收藏」中显示。"),
        FAQItem(id: "2", question: "翻译历史会同步吗？", answer: "当前版本翻译记录仅保存在本机。登录后，我们将在后续版本支持跨设备同步。"),
        FAQItem(id: "3", question: "如何关闭自动续费？", answer: "iOS：设置 — Apple ID — 订阅 — 选择本应用 — 取消订阅。取消后当前周期内仍可继续使用会员权益。"),
        FAQItem(id: "4", question: "忘记密码怎么办？", answer: "在登录页点击「忘记密码」，按提示通过注册邮箱或手机号找回。若无法找回，请联系在线客服。"),
        FAQItem(id: "5", question: "如何联系客服？", answer: "请进入「我的」—「服务与支持」—「在线客服」，查看工作时间与联系方式。")
    ]

    var body: some View {
        SettingsPage(title: "常见问题") {
            SettingsCard(title: "快速帮助", subtitle: "点开问题查看答案。若仍未解决，可在「在线客服」联系我们。") {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        FAQRow(question: item.question, answer: item.answer, isExpanded: expandedId == item.id) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedId = expandedId == item.id ? nil : item.id
                            }
                        }
                    }
                }
            }
        }
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(question)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if isExpanded {
                    Text(answer)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(2)
                }
            }
            .padding(12)
            .background(AppTheme.surfaceMuted.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SecurityTipRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppTheme.surfaceMuted.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

private struct SettingsLinkRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.primary.opacity(0.13))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(12)
        .background(AppTheme.surfaceMuted.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - 关于我们

struct AboutView: View {
    private var versionText: String {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let b = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    var body: some View {
        SettingsPage(title: "关于我们") {
            SettingsCard(title: "AI 助理", subtitle: "智能对话、多语翻译与情景学习，帮助你更高效地沟通与成长。") {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.accentStrong.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "app.badge.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AppTheme.accentStrong)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI 助理")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("版本 \(versionText)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("让 AI 更懂你，也让你更高效。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }

            SettingsCard(title: "文档与规则", subtitle: "应用协议、服务条款与会员说明。") {
                NavigationLink {
                    DocView(title: "用户协议", content: DocContent.userAgreement)
                } label: {
                    SettingsLinkRow(
                        systemImage: "person.text.rectangle",
                        title: "用户协议",
                        subtitle: "用户权利与责任说明"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DocView(title: "服务条款", content: DocContent.termsOfService)
                } label: {
                    SettingsLinkRow(
                        systemImage: "doc.text",
                        title: "服务条款",
                        subtitle: "服务范围与免责声明"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MemberExplainView()
                } label: {
                    SettingsLinkRow(
                        systemImage: "crown",
                        title: "会员说明",
                        subtitle: "权益、续费与退款规则"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 文档页（用户协议 / 服务条款）

enum DocContent {
    static let userAgreement = """
    欢迎使用 AI 助理。在使用本应用前，请您仔细阅读以下用户协议。

    一、服务说明
    本应用提供 AI 对话、多语翻译、情景学习等功能。我们会根据产品迭代更新功能与界面，并以应用内说明为准。

    二、账号与安全
    您可选择以游客身份使用部分功能，或注册/登录账号以使用完整功能并同步数据。请妥善保管账号信息，因您自身原因导致的泄露由您自行承担责任。

    三、用户行为规范
    您在使用本应用时，应遵守法律法规及公序良俗，不得利用本服务从事违法违规或侵害他人权益的行为。我们有权对违规行为进行处理，包括限制或终止服务。

    四、隐私与数据
    我们重视您的隐私。具体规则请参见《隐私政策》及应用内「设置」中的相关说明。未经您同意，我们不会向第三方出售您的个人信息。

    五、协议变更
    我们可能适时修订本协议，修订后将通过应用内通知或更新说明的方式告知。继续使用即视为接受修订后的协议。
    """

    static let termsOfService = """
    本服务条款与用户协议共同构成您与 AI 助理之间的约定。

    一、服务内容
    AI 助理提供基于 AI 的对话、翻译与学习辅助服务。服务可用性可能因网络、设备或维护而受影响，我们力求稳定但不做绝对保证。

    二、免责声明
    1. AI 生成内容仅供参考，不构成专业建议。重要决策请结合实际情况或咨询专业人士。\n    2. 因不可抗力、网络故障、第三方服务异常等导致的无法使用或数据丢失，我们将在法律允许范围内尽力协助，但不承担超出法律规定的责任。

    三、知识产权
    本应用内的界面、文案、标识等知识产权归我们或相关权利人所有。未经授权，不得复制、修改或用于商业用途。

    四、争议解决
    与本服务有关的争议，以中华人民共和国法律为准据法；如协商不成，由本应用运营方所在地有管辖权的法院管辖。
    """
}

struct DocView: View {
    let title: String
    let content: String

    var body: some View {
        SettingsPage(
            title: title,
            trailing: AnyView(
                Button {
                    ClipboardService.copy(content)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            )
        ) {
            SettingsCard(title: "内容", subtitle: "可长按/选择文本，或使用右上角复制按钮。") {
                Text(content)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - 在线客服

struct SupportView: View {
    @State private var showFAQ = false

    var body: some View {
        SettingsPage(title: "在线客服") {
            SettingsCard(title: "联系我们", subtitle: "我们会尽快回复你。建议先查看常见问题，通常能更快解决。") {
                SettingsRow(
                    systemImage: "clock",
                    title: "服务时间",
                    subtitle: "工作日 9:00 — 18:00",
                    showChevron: false,
                    action: nil
                )
                SettingsRow(
                    systemImage: "envelope",
                    title: "客服邮箱",
                    subtitle: "support@ai-assistant.example.com",
                    showChevron: true
                ) {
                    if let url = URL(string: "mailto:support@ai-assistant.example.com") {
                        #if os(iOS)
                        UIApplication.shared.open(url)
                        #elseif os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }
                SettingsRow(
                    systemImage: "questionmark.circle",
                    title: "常见问题",
                    subtitle: "点开查看常见问题与解决方法",
                    showChevron: true
                ) {
                    showFAQ = true
                }
            }
        }
        .navigationDestination(isPresented: $showFAQ) {
            FAQView()
        }
    }
}
