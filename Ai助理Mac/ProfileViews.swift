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
    @State private var showMemberExplain = false
    @State private var showFAQ = false
    // 服务与支持
    @State private var showAbout = false
    @State private var showAgreement = false
    @State private var showTerms = false
    @State private var showSupport = false

    private let quickActions: [ProfileQuickAction] = [
        ProfileQuickAction(id: "fav", title: "我的收藏", icon: "star.fill"),
        ProfileQuickAction(id: "wallet", title: "我的钱包", icon: "wallet.pass"),
        ProfileQuickAction(id: "task", title: "任务中心", icon: "calendar.badge.checkmark"),
        ProfileQuickAction(id: "gift", title: "分享有礼", icon: "gift.fill")
    ]

    private let settingsItems: [ProfileMenuItem] = [
        ProfileMenuItem(id: "settings", title: "设置", subtitle: "通知、隐私、深色模式", icon: "gearshape"),
        ProfileMenuItem(id: "account", title: "账户与安全", subtitle: "登录信息、设备管理", icon: "shield.fill"),
        ProfileMenuItem(id: "member", title: "会员说明", subtitle: "权益、自动续费规则", icon: "doc.plaintext"),
        ProfileMenuItem(id: "faq", title: "常见问题", subtitle: "快速获取帮助", icon: "questionmark.circle")
    ]

    private let helpItems: [ProfileMenuItem] = [
        ProfileMenuItem(id: "clear", title: "清除所有记录", subtitle: "聊天、学习、翻译", icon: "trash"),
        ProfileMenuItem(id: "about", title: "关于我们", subtitle: "品牌与版本信息", icon: "info.circle"),
        ProfileMenuItem(id: "agreement", title: "用户协议", subtitle: "用户权利与责任", icon: "person.text.rectangle"),
        ProfileMenuItem(id: "terms", title: "服务条款", subtitle: "服务与免责声明", icon: "doc.text"),
        ProfileMenuItem(id: "support", title: "在线客服", subtitle: "工作日 9:00-18:00", icon: "headphones")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
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
                        case "member": showMemberExplain = true
                        case "faq": showFAQ = true
                        default: break
                        }
                    }
                    ProfileHintCard(text: "在设置中可管理通知、隐私与语言等选项，确保你的对话记录与个人信息安全。")

                    ProfileSectionHeader(title: "服务与支持")
                    ProfileMenuList(items: helpItems) { item in
                        switch item.id {
                        case "clear": showClearConfirm = true
                        case "about": showAbout = true
                        case "agreement": showAgreement = true
                        case "terms": showTerms = true
                        case "support": showSupport = true
                        default: break
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.automatic)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .hideNavigationBarOnMac()
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
            .navigationDestination(isPresented: $showMemberExplain) {
                MemberExplainView()
            }
            .navigationDestination(isPresented: $showFAQ) {
                FAQView()
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutView()
            }
            .navigationDestination(isPresented: $showAgreement) {
                DocView(title: "用户协议", content: DocContent.userAgreement)
            }
            .navigationDestination(isPresented: $showTerms) {
                DocView(title: "服务条款", content: DocContent.termsOfService)
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
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentWarm.opacity(0.25))
                    .frame(width: 64, height: 64)
                Image(systemName: "face.smiling")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("点击登录")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("您还没登录呢～")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 4)
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
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 52, height: 52)
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color.yellow)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VIP会员")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("升级解锁全部功能")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            Spacer()

            Button(action: onUnlock) {
                Text("立即解锁")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface)
                    .foregroundStyle(AppTheme.accentStrong)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ProfileSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(AppTheme.accentWarm)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    VStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.accentWarm.opacity(0.16))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: action.icon)
                                    .foregroundStyle(AppTheme.accentWarm)
                            )
                        Text(action.title)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        Image(systemName: item.icon)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if item.id != items.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        ScrollView {
            VStack(spacing: 18) {
                MemberRechargeHeader {
                    dismiss()
                }

                MemberBenefitsCard(benefits: benefits)

                ProfileSectionHeader(title: "充值会员", subtitle: "推荐永久会员方案")
                MemberPlanCard(plans: plans, selectedPlanId: $selectedPlanId) {
                }
                PaymentOptionCard(options: paymentOptions, selectedId: $selectedPaymentId)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
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
                            .foregroundStyle(.white)
                        Text("升级解锁全部功能")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(AppTheme.accentWarm.opacity(0.9))
                            .frame(width: 68, height: 68)
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
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
        ScrollView {
            VStack(spacing: 18) {
                TaskCenterHeader {
                    dismiss()
                }

                TaskSummaryCard(availableDays: 0)

                TaskListCard(tasks: tasks)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
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
                    Button(task.actionTitle) {
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.unifiedButtonPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
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
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var speechSettings = SpeechSettingsStore.shared
    @ObservedObject private var appearance = AppearanceStore.shared
    @State private var isTesting = false
    @State private var alertMessage: String?
    @State private var showClearConfirm = false
    @State private var showClearDone = false

    private var speedLabel: String {
        let r = speechSettings.speechRate
        if r < 0.42 { return "较慢" }
        if r > 0.54 { return "较快" }
        return "正常"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("设置")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear
                        .frame(width: 36, height: 36)
                }

                // MARK: 朗读设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("朗读设置")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("语速")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(speedLabel)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Slider(value: Binding(
                            get: { Double(speechSettings.speechRate) },
                            set: { speechSettings.speechRate = Float($0) }
                        ), in: 0.3...0.6, step: 0.02)
                        .tint(AppTheme.primary)
                    }
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Text("语音质量")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Picker("语音质量", selection: Binding(
                            get: { speechSettings.voiceQuality },
                            set: { speechSettings.voiceQuality = $0 }
                        )) {
                            Text("默认").tag("default")
                            Text("增强").tag("enhanced")
                            Text("优质").tag("premium")
                            Text("在线（更自然）").tag("online")
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }
                .glassCard()

                // MARK: 通知
                VStack(alignment: .leading, spacing: 12) {
                    Text("通知")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("在系统「设置 → 通知」中管理本应用的通知权限与提醒。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .glassCard()

                // MARK: 隐私与数据
                VStack(alignment: .leading, spacing: 12) {
                    Text("隐私与数据")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 未登录：数据仅保存在本机，卸载应用即清空。")
                        Text("• 登录后：您的数据可同步至账号，多设备共享。")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                }
                .glassCard()

                // MARK: 外观
                VStack(alignment: .leading, spacing: 12) {
                    Text("外观")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Picker("深色模式", selection: Binding(
                        get: { appearance.mode },
                        set: { appearance.mode = $0 }
                    )) {
                        Text("跟随系统").tag(AppearanceStore.Mode.system)
                        Text("浅色").tag(AppearanceStore.Mode.light)
                        Text("深色").tag(AppearanceStore.Mode.dark)
                    }
                    .pickerStyle(.segmented)
                }
                .glassCard()

                // MARK: 账户与安全
                VStack(alignment: .leading, spacing: 12) {
                    Text("账户与安全")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    HStack {
                        Image(systemName: TokenStore.shared.isLoggedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                            .foregroundStyle(TokenStore.shared.isLoggedIn ? AppTheme.primary : AppTheme.textSecondary)
                        Text(TokenStore.shared.isLoggedIn ? "已登录" : "未登录")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("登录后数据将同步至您的账号；仅登录用户拥有跨设备持久数据。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .glassCard()

                // MARK: 清除本地数据
                VStack(alignment: .leading, spacing: 12) {
                    Text("清除本地数据")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Button {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除所有记录（收藏、翻译历史等）")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(12)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Text("仅清除本机数据，卸载应用也会清空。登录后数据可同步至账号。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .glassCard()
            }
            .padding(20)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
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
    @State private var account = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var displayName = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                AuthHeaderCard()

                Picker("模式", selection: $mode) {
                    ForEach(AuthMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    if mode == .login {
                        AuthTextField(title: "账号", placeholder: "邮箱或手机号", text: $account)
                    } else {
                        AuthTextField(title: "邮箱", placeholder: "name@email.com", text: $email)
                        AuthTextField(title: "手机号", placeholder: "+62...", text: $phone)
                        AuthTextField(title: "昵称", placeholder: "请输入昵称", text: $displayName)
                    }
                    SecureField("密码", text: $password)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }

                Button {
                } label: {
                    Text(mode == .login ? "登录" : "注册")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.unifiedButtonPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                HStack(spacing: 12) {
                    AuthSocialButton(title: "Apple 登录", icon: "applelogo")
                    AuthSocialButton(title: "Google 登录", icon: "g.circle")
                }

                Spacer()
            }
            .padding(20)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("账户")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

struct AuthHeaderCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(AppTheme.accentWarm.opacity(0.25))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "face.smiling")
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.8))
                )
            VStack(alignment: .leading, spacing: 6) {
                Text("欢迎回来")
                    .font(.headline)
                Text("登录后即可同步您的数据")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - 我的收藏（学习词汇收藏）

struct MyFavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LearningViewModel()

    private var favoriteItems: [VocabItem] {
        viewModel.categories.flatMap { $0.items }.filter { viewModel.isFavorite($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("我的收藏")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

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
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(favoriteItems) { item in
                            FavoriteVocabRow(item: item, isFavorite: true) {
                                viewModel.toggleFavorite(item)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("我的钱包")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 12) {
                    Text("余额")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("¥ 0.00")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)

                Text("收支记录")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                Text("暂无记录")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
    }
}

// MARK: - 分享有礼

struct ShareGiftView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("分享有礼")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 16) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.accentWarm)
                    Text("邀请好友，双方各得奖励")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("每成功邀请 1 位好友注册并登录，您与好友均可获得 3 天会员体验。多邀多得，上不封顶。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        // 可接入 UIActivityViewController 或分享链接
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
                .padding(24)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
    }
}

// MARK: - 账户与安全

struct AccountSecurityView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("账户与安全")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 0) {
                    ProfileMenuList(items: [
                        ProfileMenuItem(id: "login", title: "登录状态", subtitle: "未登录", icon: "person.crop.circle"),
                        ProfileMenuItem(id: "device", title: "登录设备管理", subtitle: "查看已登录设备", icon: "desktopcomputer"),
                        ProfileMenuItem(id: "pwd", title: "修改密码", subtitle: "登录后可用", icon: "lock.rotation")
                    ]) { _ in }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
    }
}

// MARK: - 会员说明

struct MemberExplainView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("会员说明")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

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
                .padding(20)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
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
    @Environment(\.dismiss) private var dismiss
    @State private var expandedId: String?

    private let items: [FAQItem] = [
        FAQItem(id: "1", question: "如何收藏词汇或句子？", answer: "在学习页中，点击词汇或句子旁的星标即可加入收藏；再次点击可取消。收藏内容会在「我的」—「我的收藏」中显示。"),
        FAQItem(id: "2", question: "翻译历史会同步吗？", answer: "当前版本翻译记录仅保存在本机。登录后，我们将在后续版本支持跨设备同步。"),
        FAQItem(id: "3", question: "如何关闭自动续费？", answer: "iOS：设置 — Apple ID — 订阅 — 选择本应用 — 取消订阅。取消后当前周期内仍可继续使用会员权益。"),
        FAQItem(id: "4", question: "忘记密码怎么办？", answer: "在登录页点击「忘记密码」，按提示通过注册邮箱或手机号找回。若无法找回，请联系在线客服。"),
        FAQItem(id: "5", question: "如何联系客服？", answer: "请进入「我的」—「服务与支持」—「在线客服」，查看工作时间与联系方式。")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("常见问题")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ForEach(items) { item in
                    FAQRow(question: item.question, answer: item.answer, isExpanded: expandedId == item.id) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedId = expandedId == item.id ? nil : item.id
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
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
                }
            }
            .padding(16)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 关于我们

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("关于我们")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 12) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppTheme.accentStrong)
                    Text("AI 助理")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("版本 1.0.0")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("AI 助理致力于用智能对话、多语翻译与情景学习，帮助你更高效地沟通与成长。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
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
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text(content)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
    }
}

// MARK: - 在线客服

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("在线客服")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 16) {
                    Label("服务时间", systemImage: "clock")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("工作日 9:00 — 18:00")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    Label("客服邮箱", systemImage: "envelope")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Button("support@ai-assistant.example.com") {
                        if let url = URL(string: "mailto:support@ai-assistant.example.com") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.accentStrong)

                    Label("常见问题", systemImage: "questionmark.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("建议先查看「常见问题」页，可更快得到解答。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
    }
}
