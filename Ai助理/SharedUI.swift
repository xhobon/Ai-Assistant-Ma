import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 设计系统
struct ModernDesignSystem {
    
    // MARK: - 间距
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - 字体
    struct Typography {
        static let heroTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let heroSubtitle = Font.system(size: 20, weight: .medium, design: .rounded)
        static let pageTitle = Font.system(size: 24, weight: .bold, design: .default)
        static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .default)
        static let cardTitle = Font.system(size: 18, weight: .semibold, design: .default)
        static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
        static let button = Font.system(size: 16, weight: .semibold, design: .default)
        static let caption = Font.system(size: 11, weight: .medium, design: .default)
        static let label = Font.system(size: 12, weight: .medium, design: .default)
        static let neon = Font.system(size: 18, weight: .bold, design: .default)
        static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let digital = Font.system(size: 16, weight: .light, design: .default)
    }
    
    // MARK: - 圆角
    struct CornerRadius {
        static let micro: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let xxlarge: CGFloat = 24
        static let round: CGFloat = 1000
        static let sharp: CGFloat = 0
        static let tablet: CGFloat = 28
    }
    
    // MARK: - 阴影（柔和灰，无发光）
    struct Shadow {
        static let small = (color: Color.black.opacity(0.06), radius: CGFloat(6), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.08), radius: CGFloat(12), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.10), radius: CGFloat(20), y: CGFloat(6))
        static let xlarge = (color: Color.black.opacity(0.12), radius: CGFloat(30), y: CGFloat(8))
        static let neon = (color: Color.black.opacity(0.08), radius: CGFloat(12), y: CGFloat(3))
        static let electric = (color: Color.black.opacity(0.08), radius: CGFloat(14), y: CGFloat(3))
        static let glow = (color: Color.black.opacity(0.06), radius: CGFloat(10), y: CGFloat(2))
        static let pulse = (color: Color.black.opacity(0.08), radius: CGFloat(16), y: CGFloat(4))
    }
    
    // MARK: - 动画
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.12)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        
        static let buttonPress = SwiftUI.Animation.easeInOut(duration: 0.08)
        static let cardAppear = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.85)
        static let contentTransition = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let modalPresentation = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let tabSwitch = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let neonGlow = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let pulse = SwiftUI.Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        static let shimmer = SwiftUI.Animation.linear(duration: 2.5).repeatForever(autoreverses: false)
        static let loading = SwiftUI.Animation.linear(duration: 1.2).repeatForever(autoreverses: false)
        static let glitch = SwiftUI.Animation.easeInOut(duration: 0.1)
        static let hologram = SwiftUI.Animation.spring(response: 0.8, dampingFraction: 0.9)
        static let cyberpunk = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let matrix = SwiftUI.Animation.linear(duration: 3.0).repeatForever(autoreverses: false)
        static let electric = SwiftUI.Animation.easeInOut(duration: 0.3)
    }
    
    // MARK: - 微交互
    struct MicroInteractions {
        static let buttonScale: CGFloat = 0.97
        static let cardHoverScale: CGFloat = 1.01
        static let neonPulseScale: CGFloat = 1.02
        static let iconRotation: Angle = .degrees(180)
        static let shadowOffset: CGFloat = 6
        static let highlightOpacity: Double = 0.08
        static let glowIntensity: Double = 0.3
        static let glassBlur: CGFloat = 12.0
        static let neonSpread: CGFloat = 4.0
        static let hologramOpacity: Double = 0.4
        static let electricIntensity: Double = 0.4
    }
}

// MARK: - 色彩系统（AI 助理风格：专业、现代、可信）
struct ModernColorSystem {

    // MARK: - 浅色主题（微暖灰白）
    struct LightTheme {
        static let backgroundPrimary = Color(red: 0.96, green: 0.97, blue: 0.985)
        static let backgroundSecondary = Color(red: 0.92, green: 0.94, blue: 0.97)
        static let backgroundTertiary = Color(red: 0.88, green: 0.91, blue: 0.95)
        static let surfaceElevated = Color.white
        static let glassBackground = Color.white.opacity(0.93)
        static let glassBorder = Color.black.opacity(0.11)
    }

    // MARK: - 深色主题（备用）
    struct DarkTheme {
        static let backgroundPrimary = Color(red: 0.09, green: 0.10, blue: 0.14)
        static let backgroundSecondary = Color(red: 0.13, green: 0.15, blue: 0.20)
        static let backgroundTertiary = Color(red: 0.18, green: 0.21, blue: 0.28)
        static let surfaceElevated = Color(red: 0.15, green: 0.18, blue: 0.25)
        static let glassBackground = Color.white.opacity(0.12)
        static let glassBorder = Color.white.opacity(0.22)
    }

    // MARK: - AI 助理主色（靛蓝·紫·青）
    struct AIPrimary {
        static let indigo = Color(red: 0.39, green: 0.40, blue: 0.95)      // 主色
        static let indigoDark = Color(red: 0.31, green: 0.27, blue: 0.90)  // 按钮/强调
        static let violet = Color(red: 0.51, green: 0.42, blue: 0.93)     // 辅助
        static let teal = Color(red: 0.08, green: 0.72, blue: 0.65)       // 成功/完成
        static let amber = Color(red: 0.98, green: 0.58, blue: 0.24)      // 温暖/语音
        static let coral = Color(red: 0.95, green: 0.45, blue: 0.42)      // 警示/录音
    }

    // MARK: - 兼容旧引用
    struct Neon {
        static let cyan = AIPrimary.teal
        static let magenta = AIPrimary.violet
        static let electricBlue = AIPrimary.indigo
        static let neonGreen = AIPrimary.teal
        static let neonPurple = AIPrimary.violet
        static let neonOrange = AIPrimary.amber
    }
    
    // MARK: - 蓝色阶
    struct Primary {
        static let blue50 = Color(red: 0.93, green: 0.96, blue: 1.0)
        static let blue100 = Color(red: 0.85, green: 0.92, blue: 1.0)
        static let blue200 = Color(red: 0.70, green: 0.85, blue: 1.0)
        static let blue300 = Color(red: 0.50, green: 0.75, blue: 1.0)
        static let blue400 = Color(red: 0.30, green: 0.62, blue: 0.98)
        static let blue500 = Color(red: 0.18, green: 0.52, blue: 0.92)
        static let blue600 = Color(red: 0.12, green: 0.42, blue: 0.82)
        static let blue700 = Color(red: 0.08, green: 0.32, blue: 0.68)
        static let blue800 = Color(red: 0.05, green: 0.24, blue: 0.52)
        static let blue900 = Color(red: 0.03, green: 0.16, blue: 0.38)
    }
    
    // MARK: - 语义色（与主色协调）
    struct Semantic {
        static let success = AIPrimary.teal
        static let warning = AIPrimary.amber
        static let error = AIPrimary.coral
        static let info = AIPrimary.indigo
    }
    
    // MARK: - 中性灰（偏暖、柔和）
    struct Neutral {
        static let white = Color.white
        static let gray50 = Color(red: 0.985, green: 0.982, blue: 0.98)
        static let gray100 = Color(red: 0.96, green: 0.958, blue: 0.96)
        static let gray200 = Color(red: 0.91, green: 0.908, blue: 0.91)
        static let gray300 = Color(red: 0.82, green: 0.816, blue: 0.82)
        static let gray400 = Color(red: 0.58, green: 0.576, blue: 0.58)
        static let gray500 = Color(red: 0.45, green: 0.448, blue: 0.45)
        static let gray600 = Color(red: 0.33, green: 0.326, blue: 0.33)
        static let gray700 = Color(red: 0.24, green: 0.235, blue: 0.24)
        static let gray800 = Color(red: 0.16, green: 0.157, blue: 0.16)
        static let gray900 = Color(red: 0.11, green: 0.106, blue: 0.11)
        static let black = Color.black
    }
    
    // MARK: - 系统色彩适配
    #if os(iOS)
    @available(iOS 15.0, *)
    struct System {
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
        static let groupedBackground = Color(UIColor.systemGroupedBackground)
        static let label = Color(UIColor.label)
        static let secondaryLabel = Color(UIColor.secondaryLabel)
        static let tertiaryLabel = Color(UIColor.tertiaryLabel)
        static let separator = Color(UIColor.separator)
        static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    }
    #elseif os(macOS)
    struct System {
        static let background = Color(NSColor.windowBackgroundColor)
        static let secondaryBackground = Color(NSColor.controlBackgroundColor)
        static let tertiaryBackground = Color(NSColor.controlBackgroundColor)
        static let groupedBackground = Color(NSColor.windowBackgroundColor)
        static let label = Color(NSColor.labelColor)
        static let secondaryLabel = Color(NSColor.secondaryLabelColor)
        static let tertiaryLabel = Color(NSColor.tertiaryLabelColor)
        static let separator = Color(NSColor.separatorColor)
        static let opaqueSeparator = Color(NSColor.separatorColor)
    }
    #endif
}

// MARK: - 主题配色（AI 助理：专业·现代·可信）
struct AppTheme {
    static let primary = Color(red: 0.05, green: 0.38, blue: 0.84)
    static let primaryVariant = Color(red: 0.03, green: 0.29, blue: 0.66)
    static let secondary = Color(red: 0.03, green: 0.56, blue: 0.62)

    struct TopBar {
        static let height: CGFloat = 44
        static let backButtonSize: CGFloat = 44
        static let sideSlotWidth: CGFloat = 52
        static let backIconFont = Font.system(size: 18, weight: .semibold)
        static let titleFont = Font.system(size: 18, weight: .semibold)
    }

    private static var isDark: Bool {
        AppearanceStore.shared.mode == .dark
    }

    // 浅色 / 深色背景
    static var background: Color {
        isDark ? ModernColorSystem.DarkTheme.backgroundPrimary : ModernColorSystem.LightTheme.backgroundPrimary
    }
    static var backgroundSecondary: Color {
        isDark ? ModernColorSystem.DarkTheme.backgroundSecondary : ModernColorSystem.LightTheme.backgroundSecondary
    }
    static var backgroundTertiary: Color {
        isDark ? ModernColorSystem.DarkTheme.backgroundTertiary : ModernColorSystem.LightTheme.backgroundTertiary
    }
    static var surface: Color {
        isDark ? ModernColorSystem.DarkTheme.surfaceElevated : ModernColorSystem.LightTheme.surfaceElevated
    }
    static var surfaceMuted: Color {
        isDark ? ModernColorSystem.DarkTheme.backgroundTertiary : ModernColorSystem.LightTheme.backgroundSecondary
    }
    static var surfaceElevated: Color {
        isDark ? ModernColorSystem.DarkTheme.surfaceElevated : ModernColorSystem.LightTheme.surfaceElevated
    }

    static var glassBackground: Color {
        isDark ? ModernColorSystem.DarkTheme.glassBackground : ModernColorSystem.LightTheme.glassBackground
    }
    static var glassBorder: Color {
        isDark ? ModernColorSystem.DarkTheme.glassBorder : ModernColorSystem.LightTheme.glassBorder
    }

    // 文字层级
    static var textPrimary: Color {
        isDark ? ModernColorSystem.Neutral.gray50 : ModernColorSystem.Neutral.gray900
    }
    static var textSecondary: Color {
        isDark ? ModernColorSystem.Neutral.gray200 : ModernColorSystem.Neutral.gray700
    }
    static var textTertiary: Color {
        isDark ? ModernColorSystem.Neutral.gray300 : ModernColorSystem.Neutral.gray600
    }
    static var textMuted: Color {
        isDark ? ModernColorSystem.Neutral.gray400 : ModernColorSystem.Neutral.gray500
    }
    static let textOnPrimary = Color.white
    /// 输入框内文字颜色（黑色/白色），确保与背景对比清晰
    static var inputText: Color {
        isDark ? Color.white : Color.black
    }
    /// 输入框占位符颜色
    static var inputPlaceholder: Color {
        isDark ? ModernColorSystem.Neutral.gray500 : Color(white: 0.42)
    }

    static let success = ModernColorSystem.Semantic.success
    static let warning = ModernColorSystem.Semantic.warning
    static let error = ModernColorSystem.Semantic.error
    static let info = ModernColorSystem.Semantic.info

    static let accent = primary
    static let accentStrong = primaryVariant
    static let accentWarm = Color(red: 0.88, green: 0.52, blue: 0.13)
    static let accentPurple = Color(red: 0.18, green: 0.48, blue: 0.83)
    static let brandBlue = primary

    // 统一按钮样式：主按钮蓝色填充，次按钮清透蓝边
    static let unifiedButtonPrimary = Color(red: 0.05, green: 0.38, blue: 0.84)
    static let unifiedButtonBorder = Color(red: 0.08, green: 0.34, blue: 0.72)

    // 边框与阴影
    static var border: Color {
        isDark ? ModernColorSystem.DarkTheme.glassBorder : ModernColorSystem.LightTheme.glassBorder
    }
    static var borderStrong: Color {
        isDark ? Color.white.opacity(0.26) : Color.black.opacity(0.18)
    }
    static let neonGlow = primary.opacity(0.25)
    static var softShadow: Color {
        isDark ? Color.black.opacity(0.7) : Color.black.opacity(0.08)
    }
    static var mediumShadow: Color {
        isDark ? Color.black.opacity(0.8) : Color.black.opacity(0.10)
    }
    static var glowShadow: Color {
        isDark ? Color.black.opacity(0.9) : Color.black.opacity(0.06)
    }
    
    // 渐变（品牌蓝 → 青）
    static let primaryGradient = LinearGradient(
        colors: [
            primary,
            secondary
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                isDark ? ModernColorSystem.DarkTheme.backgroundPrimary : ModernColorSystem.LightTheme.backgroundPrimary,
                primary.opacity(isDark ? 0.22 : 0.08),
                secondary.opacity(isDark ? 0.18 : 0.06),
                isDark ? ModernColorSystem.DarkTheme.backgroundSecondary : ModernColorSystem.LightTheme.backgroundSecondary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                background,
                backgroundSecondary,
                backgroundTertiary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 与 Tab 容器一致的页面背景，各子页面统一使用
    static var pageBackground: LinearGradient {
        LinearGradient(
            colors: [
                isDark ? Color(red: 0.07, green: 0.09, blue: 0.13) : Color(red: 0.93, green: 0.95, blue: 0.985),
                isDark ? Color(red: 0.09, green: 0.12, blue: 0.18) : Color(red: 0.89, green: 0.92, blue: 0.97),
                isDark ? Color(red: 0.07, green: 0.10, blue: 0.16) : Color(red: 0.95, green: 0.97, blue: 0.995)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                surfaceElevated,
                backgroundTertiary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var neonGradient: LinearGradient {
        LinearGradient(
        colors: [
            primary,
            secondary
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
        )
    }
    
    static var glassGradient: LinearGradient {
        LinearGradient(
            colors: [
                isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.9),
                glassBackground,
                isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static let pulseGradient = LinearGradient(
        colors: [
            primary.opacity(0.35),
            secondary.opacity(0.28)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 现代卡片样式
enum ModernCardStyle {
    case neon      // 霓虹卡片
    case glass     // 玻璃态卡片
    case hologram  // 全息卡片
    case cyber     // 赛博朋克卡片
    case electric  // 电光卡片
    case minimal   // 极简卡片
    case elevated  // 浮动卡片
    case outlined  // 轮廓卡片
}

// MARK: - 科技感输入框组件
struct ModernTextField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String?
    let style: TextFieldStyle
    let isSecure: Bool
    
    enum TextFieldStyle {
        case neon     // 霓虹风格
        case glass    // 玻璃态风格
        case cyber    // 赛博朋克风格
        case hologram // 全息风格
        case electric // 电光风格
    }
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        systemImage: String? = nil,
        style: TextFieldStyle = .neon,
        isSecure: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.systemImage = systemImage
        self.style = style
        self.isSecure = isSecure
    }
    
    @State private var isFocused = false
    @FocusState private var focusState: Bool
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(isFocused ? 1.1 : 1.0)
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(ModernDesignSystem.Typography.body)
            .foregroundStyle(AppTheme.inputText)
            .focused($focusState)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .overlay(inputBorder)
        .shadow(color: inputShadow.color, radius: inputShadow.radius, x: 0, y: inputShadow.y)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .onChange(of: focusState) { _, newValue in
            withAnimation(ModernDesignSystem.Animation.cyberpunk) {
                isFocused = newValue
            }
        }
    }
    
    private var iconColor: Color {
        switch style {
        case .neon, .electric:
            return isFocused ? ModernColorSystem.Neon.cyan : AppTheme.textTertiary
        case .glass:
            return AppTheme.textSecondary
        case .cyber:
            return isFocused ? AppTheme.accent : AppTheme.textTertiary
        case .hologram:
            return isFocused ? ModernColorSystem.Neon.magenta : AppTheme.textTertiary
        }
    }
    
    @ViewBuilder
    private var inputBackground: some View {
        switch style {
        case .neon:
            AppTheme.backgroundTertiary
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernColorSystem.Neon.cyan.opacity(isFocused ? 0.6 : 0.2), lineWidth: 1)
                )
        case .glass:
            AppTheme.glassBackground
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        case .cyber:
            AppTheme.surface
        case .hologram:
            AppTheme.pulseGradient
                .opacity(isFocused ? 0.3 : 0.1)
        case .electric:
            AppTheme.backgroundTertiary
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernColorSystem.Neon.electricBlue.opacity(isFocused ? 0.6 : 0.2), lineWidth: 1)
                )
        }
    }
    
    @ViewBuilder
    private var inputBorder: some View {
        switch style {
        case .neon:
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [ModernColorSystem.Neon.cyan, ModernColorSystem.Neon.electricBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ).opacity(isFocused ? 1.0 : 0.3),
                    lineWidth: 2
                )
        case .cyber:
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(AppTheme.border, lineWidth: 1)
                .shadow(color: AppTheme.softShadow.opacity(0.5), radius: 2, x: 0, y: 1)
        case .hologram:
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [ModernColorSystem.Neon.magenta, ModernColorSystem.Neon.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ).opacity(isFocused ? 0.8 : 0.2),
                    lineWidth: 1
                )
        case .electric:
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernColorSystem.Neon.electricBlue.opacity(isFocused ? 1.0 : 0.3), lineWidth: 2)
        case .glass:
            EmptyView()
        }
    }
    
    private var inputShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch style {
        case .neon:
            return isFocused ? ModernDesignSystem.Shadow.neon : ModernDesignSystem.Shadow.small
        case .cyber:
            return (AppTheme.softShadow, 4, 2)
        case .hologram:
            return isFocused ? ModernDesignSystem.Shadow.pulse : (Color.clear, 0, 0)
        case .electric:
            return isFocused ? ModernDesignSystem.Shadow.electric : ModernDesignSystem.Shadow.small
        default:
            return ModernDesignSystem.Shadow.small
        }
    }
}

// MARK: - 科技感微交互组件

// 霓虹发光效果
struct NeonGlowEffect: ViewModifier {
    let color: Color
    let intensity: Double
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(intensity * 0.6), radius: radius * 1.5, x: 0, y: 0)
            .shadow(color: color.opacity(intensity * 0.3), radius: radius * 2, x: 0, y: 0)
    }
}

// 电光闪烁效果
struct ElectricPulseEffect: View {
    @State private var isPulsing = false
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
            .stroke(color, lineWidth: 2)
            .opacity(isPulsing ? 1.0 : 0.3)
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(ModernDesignSystem.Animation.electric, value: isPulsing)
            .onAppear {
                withAnimation(ModernDesignSystem.Animation.electric) {
                    isPulsing.toggle()
                }
            }
    }
}

// 全息投影效果
struct HologramEffect: ViewModifier {
    @State private var shimmerOffset: CGFloat = -200
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(opacity),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .mask(content)
                    .onAppear {
                        withAnimation(ModernDesignSystem.Animation.shimmer) {
                            shimmerOffset = 200
                        }
                    }
            )
    }
}

// 科技感背景
struct TechBackground: View {
    let style: BackgroundStyle
    @State private var particleOffset: CGFloat = 0
    
    enum BackgroundStyle {
        case matrix    // 矩阵风格
        case grid      // 网格风格
        case particles // 粒子风格
        case cyber     // 赛博朋克风格
    }
    
    var body: some View {
        AppTheme.backgroundGradient
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var matrixBackground: some View {
        Canvas { context, size in
            for i in stride(from: 0, to: size.height, by: 20) {
                for j in stride(from: 0, to: size.width, by: 15) {
                    if Bool.random() {
                        let rect = CGRect(x: j, y: i, width: 2, height: 10)
                        context.fill(
                            Path(rect),
                            with: .color(ModernColorSystem.Neon.neonGreen.opacity(Double.random(in: 0.3...0.8)))
                        )
                    }
                }
            }
        }
        .opacity(0.1)
    }
    
    @ViewBuilder
    private var gridBackground: some View {
        Canvas { context, size in
            // 垂直线
            for i in stride(from: 0, to: size.width, by: 30) {
                let path = Path { path in
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i, y: size.height))
                }
                context.stroke(path, with: .color(AppTheme.border), lineWidth: 0.5)
            }
            
            // 水平线
            for i in stride(from: 0, to: size.height, by: 30) {
                let path = Path { path in
                    path.move(to: CGPoint(x: 0, y: i))
                    path.addLine(to: CGPoint(x: size.width, y: i))
                }
                context.stroke(path, with: .color(AppTheme.border), lineWidth: 0.5)
            }
        }
        .opacity(0.3)
    }
    
    @ViewBuilder
    private var particlesBackground: some View {
        Canvas { context, size in
            for _ in 0..<50 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let radius = CGFloat.random(in: 1...3)
                
                let circle = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                context.fill(
                    circle,
                    with: .color(ModernColorSystem.Neon.cyan.opacity(Double.random(in: 0.2...0.6)))
                )
            }
        }
        .opacity(0.6)
    }
    
    @ViewBuilder
    private var cyberBackground: some View {
        Canvas { context, size in
            // 赛博朋克风格的线条
            for _ in 0..<10 {
                let startX = CGFloat.random(in: 0...size.width)
                let startY: CGFloat = 0
                let endX = CGFloat.random(in: 0...size.width)
                let endY: CGFloat = size.height
                
                var path = Path()
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
                
                let color = [ModernColorSystem.Neon.cyan, ModernColorSystem.Neon.magenta, ModernColorSystem.Neon.electricBlue].randomElement()!
                context.stroke(path, with: .color(color.opacity(0.2)), lineWidth: CGFloat.random(in: 1...3))
            }
        }
        .opacity(0.3)
    }
}

// MARK: - 科技感Hero头部组件
struct ModernHeroHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let badgeText: String?
    let headline: String
    let subheadline: String
    var leadingAction: (() -> Void)? = nil
    var style: HeroStyle = .gradient

    enum HeroStyle {
        case gradient
        case glass
        case solid
    }

    private var safeTop: CGFloat {
        #if os(iOS)
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 20)
        #elseif os(macOS)
        return 20
        #endif
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景层
            backgroundView
            
            // 装饰性光晕
            if style == .gradient {
                decorativeOrbs
            }

            // 内容层
            contentLayer
        }
        .frame(minHeight: 220 + safeTop)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .gradient:
            AppTheme.heroGradient
                .ignoresSafeArea()
        case .glass:
            ZStack {
                AppTheme.backgroundGradient
                Color.white.opacity(0.8)
            }
        case .solid:
            AppTheme.surface
        }
    }
    
    @ViewBuilder
    private var decorativeOrbs: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 160, height: 160)
                .blur(radius: 20)
                .offset(x: -140, y: -30)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 25)
                .offset(x: 180, y: -50)
            
            Circle()
                .fill(AppTheme.accentWarm.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: -100, y: 200)
        }
    }
    
    @ViewBuilder
    private var contentLayer: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            // 顶部导航栏
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // 左侧按钮
                Group {
                    if let leadingAction = leadingAction {
                        Button(action: leadingAction) {
                            iconButtonContent
                        }
                    } else {
                        iconButtonContent
                    }
                }
                
                // 中间标题区域
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textOnPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textOnPrimary.opacity(0.85))
                }
                
                Spacer()
                
                // 徽章
                if let badgeText = badgeText {
                    Text(badgeText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textOnPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                        )
                }
            }
            
            // 主要内容
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text(headline)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textOnPrimary)
                    .lineLimit(2)
                Text(subheadline)
                    .font(.callout)
                    .foregroundStyle(AppTheme.textOnPrimary.opacity(0.9))
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.top, safeTop + ModernDesignSystem.Spacing.md)
        .padding(.bottom, ModernDesignSystem.Spacing.lg)
    }
    
    @ViewBuilder
    private var iconButtonContent: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textOnPrimary)
            .frame(width: 42, height: 42)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(Color.white.opacity(0.2))
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - 向后兼容的UnifiedHeroHeader
struct UnifiedHeroHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let badgeText: String
    let headline: String
    let subheadline: String
    var leadingAction: (() -> Void)? = nil

    var body: some View {
        ModernHeroHeader(
            systemImage: systemImage,
            title: title,
            subtitle: subtitle,
            badgeText: badgeText.isEmpty ? nil : badgeText,
            headline: headline,
            subheadline: subheadline,
            leadingAction: leadingAction,
            style: .gradient
        )
    }
}

// MARK: - 现代化背景组件
struct ModernBackground: View {
    var style: BackgroundStyle = .gradient
    
    enum BackgroundStyle {
        case gradient
        case glass
        case minimalist
        case decorative
    }
    
    var body: some View {
        ZStack {
            switch style {
            case .gradient:
                AppTheme.backgroundGradient
            case .glass:
                ZStack {
                    AppTheme.backgroundGradient
                    Color.white.opacity(0.7)
                }
            case .minimalist:
                AppTheme.surface
            case .decorative:
                decorativeBackground
            }
        }
    }
    
    @ViewBuilder
    private var decorativeBackground: some View {
        ZStack {
            AppTheme.backgroundGradient
            
            // 装饰性光晕
            Circle()
                .fill(AppTheme.primary.opacity(0.06))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -200, y: -300)
            
            Circle()
                .fill(AppTheme.accentWarm.opacity(0.04))
                .frame(width: 350, height: 350)
                .blur(radius: 70)
                .offset(x: 220, y: -120)
            
            Circle()
                .fill(AppTheme.secondary.opacity(0.05))
                .frame(width: 450, height: 450)
                .blur(radius: 90)
                .offset(x: -150, y: 320)
        }
    }
}

// MARK: - 向后兼容的LiquidGlassBackground
struct LiquidGlassBackground: View {
    var body: some View {
        ModernBackground(style: .decorative)
    }
}

// MARK: - 现代化卡片组件系统

struct ModernCard<Content: View>: View {
    let content: Content
    let style: ModernCardStyle
    let padding: EdgeInsets
    let spacing: CGFloat
    
    init(
        style: ModernCardStyle = .elevated,
        padding: EdgeInsets = EdgeInsets(top: ModernDesignSystem.Spacing.md, leading: ModernDesignSystem.Spacing.md, bottom: ModernDesignSystem.Spacing.md, trailing: ModernDesignSystem.Spacing.md),
        spacing: CGFloat = ModernDesignSystem.Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }
    
    
    @ViewBuilder
    var body: some View {
        content
            .padding(padding)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            .overlay(cardBorder)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        switch style {
        case .neon:
            AppTheme.backgroundTertiary
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(ModernColorSystem.Neon.cyan.opacity(0.3), lineWidth: 1)
                )
        case .glass:
            AppTheme.glassBackground
        case .hologram:
            AppTheme.pulseGradient
                .opacity(0.15)
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [ModernColorSystem.Neon.magenta.opacity(0.4), ModernColorSystem.Neon.cyan.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        case .cyber:
            LinearGradient(
                colors: [AppTheme.backgroundSecondary, AppTheme.backgroundTertiary],
                startPoint: .top,
                endPoint: .bottom
            )
        case .electric:
            LinearGradient(
                colors: [AppTheme.backgroundSecondary, ModernColorSystem.Neon.electricBlue.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .elevated:
            AppTheme.surface
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        case .minimal:
            Color.clear
        case .outlined:
            Color.clear
        }
    }
    
    @ViewBuilder
    private var cardBorder: some View {
        switch style {
        case .neon:
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [ModernColorSystem.Neon.cyan, ModernColorSystem.Neon.electricBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ).opacity(0.8),
                    lineWidth: 2
                )
                .shadow(color: ModernColorSystem.Neon.cyan.opacity(0.4), radius: 8, x: 0, y: 0)
        case .hologram:
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [ModernColorSystem.Neon.magenta, ModernColorSystem.Neon.cyan, ModernColorSystem.Neon.magenta],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        case .cyber:
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(AppTheme.border, lineWidth: 1)
        case .electric:
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(ModernColorSystem.Neon.electricBlue.opacity(0.6), lineWidth: 1)
                .shadow(color: ModernColorSystem.Neon.electricBlue.opacity(0.3), radius: 6, x: 0, y: 0)
        case .elevated:
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(AppTheme.border, lineWidth: 1)
        case .outlined:
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(AppTheme.border, lineWidth: 1)
        default:
            EmptyView()
        }
    }
    
    private var cardCornerRadius: CGFloat {
        switch style {
        case .minimal:
            return ModernDesignSystem.CornerRadius.medium
        case .cyber:
            return ModernDesignSystem.CornerRadius.sharp
        default:
            return ModernDesignSystem.CornerRadius.large
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .neon:
            return ModernColorSystem.Neon.cyan.opacity(0.6)
        case .glass:
            return AppTheme.softShadow
        case .hologram:
            return ModernColorSystem.Neon.magenta.opacity(0.4)
        case .cyber:
            return ModernDesignSystem.Shadow.large.color
        case .electric:
            return ModernColorSystem.Neon.electricBlue.opacity(0.4)
        case .elevated:
            return AppTheme.softShadow
        default:
            return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .neon, .electric:
            return 20
        case .hologram:
            return 25
        case .glass:
            return 18
        case .cyber:
            return ModernDesignSystem.Shadow.large.radius
        case .elevated:
            return 12
        default:
            return 0
        }
    }
    
    private var shadowOffset: CGFloat {
        switch style {
        case .neon, .electric, .hologram:
            return 0
        case .glass:
            return 10
        case .cyber:
            return ModernDesignSystem.Shadow.large.y
        case .elevated:
            return 4
        default:
            return 0
        }
    }
}

// MARK: - Hero卡片组件
struct ModernHeroCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    var style: ModernCardStyle = .elevated

    var body: some View {
        ModernCard(style: style) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // 图标区域
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: systemImage)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(accent)
                }
                
                // 文本区域
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .scaleEffect(1.0)
        .animation(ModernDesignSystem.Animation.spring, value: style)
    }
}

// MARK: - 向后兼容的GlassHeroCard
struct GlassHeroCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        ModernHeroCard(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            accent: accent,
            style: .glass
        )
    }
}

// MARK: - 现代化按钮组件系统

struct ModernButton: View {
    let title: String
    let systemImage: String?
    let style: ButtonStyle
    let size: ButtonSize
    let action: () -> Void
    @State private var isPressed = false
    
    enum ButtonStyle {
        case neon      // 霓虹主按钮
        case primary   // 主按钮（同 neon）
        case glass     // 玻璃态按钮
        case hologram  // 全息按钮
        case cyber     // 赛博朋克按钮
        case electric  // 电光按钮
        case outline   // 轮廓按钮
        case ghost     // 幽灵按钮
        case danger    // 危险/ destructive 按钮
    }
    
    enum ButtonSize {
        case small
        case medium
        case large
        
        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium:
                return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            case .large:
                return EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
            }
        }
        
        var font: Font {
            switch self {
            case .small:
                return ModernDesignSystem.Typography.caption
            case .medium:
                return ModernDesignSystem.Typography.button
            case .large:
                return ModernDesignSystem.Typography.cardTitle
            }
        }
    }
    
    init(
        _ title: String,
        systemImage: String? = nil,
        style: ButtonStyle = .neon,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(size.font)
                        .scaleEffect(isPressed ? 1.2 : 1.0)
                }
                Text(title)
                    .font(size.font)
            }
            .padding(size.padding)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
            .scaleEffect(isPressed ? ModernDesignSystem.MicroInteractions.buttonScale : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .pressEvents(
            onPress: { 
                isPressed = true
                HapticFeedback.impact()
            },
            onRelease: { isPressed = false }
        )
        .animation(ModernDesignSystem.Animation.cyberpunk, value: isPressed)
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .neon, .primary:
            AppTheme.neonGradient
        case .glass:
            AppTheme.glassGradient
                .background(.ultraThinMaterial)
        case .hologram:
            AppTheme.pulseGradient
        case .cyber:
            LinearGradient(
                colors: [AppTheme.surface, AppTheme.backgroundSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
        case .electric:
            LinearGradient(
                colors: [ModernColorSystem.Neon.electricBlue, ModernColorSystem.Neon.cyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .outline:
            Color.clear
        case .ghost:
            Color.clear
        case .danger:
            LinearGradient(
                colors: [ModernColorSystem.Semantic.error, ModernColorSystem.Semantic.error.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var buttonForeground: Color {
        switch style {
        case .neon, .primary, .electric:
            return AppTheme.textOnPrimary
        case .glass, .hologram:
            return AppTheme.textPrimary
        case .cyber:
            return AppTheme.primary
        case .outline:
            return AppTheme.neonGlow
        case .ghost:
            return AppTheme.textSecondary
        case .danger:
            return .white
        }
    }
    
    private var buttonCornerRadius: CGFloat {
        switch size {
        case .small:
            return ModernDesignSystem.CornerRadius.medium
        case .medium, .large:
            return ModernDesignSystem.CornerRadius.large
        }
    }
    
    @ViewBuilder
    private var buttonBorder: some View {
        switch style {
        case .outline:
            RoundedRectangle(cornerRadius: buttonCornerRadius)
                .stroke(AppTheme.neonGlow, lineWidth: 1)
        case .hologram:
            RoundedRectangle(cornerRadius: buttonCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [ModernColorSystem.Neon.magenta, ModernColorSystem.Neon.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        case .cyber:
            RoundedRectangle(cornerRadius: buttonCornerRadius)
                .stroke(AppTheme.border, lineWidth: 1)
        case .danger:
            RoundedRectangle(cornerRadius: buttonCornerRadius)
                .stroke(ModernColorSystem.Semantic.error.opacity(0.7), lineWidth: 1)
        default:
            EmptyView()
        }
    }
    
    private var buttonShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        return (Color.clear, 0, 0)
    }
}

// MARK: - 图标按钮组件
struct ModernIconButton: View {
    let systemImage: String
    let style: IconButtonStyle
    let size: IconButtonSize
    let action: () -> Void
    @State private var isPressed = false
    
    enum IconButtonStyle {
        case neon      // 霓虹风格
        case glass     // 玻璃态风格
        case ghost     // 幽灵风格
        case surface   // 表面风格
        case secondary // 次要风格
    }
    
    enum IconButtonSize {
        case small
        case medium
        case large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .caption.weight(.medium)
            case .medium: return .callout.weight(.medium)
            case .large: return .headline.weight(.medium)
            }
        }
    }
    
    init(
        _ systemImage: String,
        style: IconButtonStyle = .glass,
        size: IconButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(size.font)
                .frame(width: size.dimension, height: size.dimension)
                .background(iconBackground)
                .foregroundStyle(iconForeground)
                .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .animation(ModernDesignSystem.Animation.quick, value: isPressed)
    }
    
    @ViewBuilder
    private var iconBackground: some View {
        switch style {
        case .neon:
            AppTheme.neonGradient
        case .glass:
            AppTheme.glassGradient
                .background(.ultraThinMaterial)
        case .ghost:
            Color.clear
        case .surface:
            AppTheme.surface
        case .secondary:
            AppTheme.backgroundTertiary
        }
    }
    
    private var iconForeground: Color {
        switch style {
        case .neon:
            return AppTheme.textOnPrimary
        case .glass:
            return AppTheme.textPrimary
        case .surface:
            return AppTheme.textPrimary
        case .ghost:
            return AppTheme.textSecondary
        case .secondary:
            return AppTheme.textSecondary
        }
    }
    
    private var iconCornerRadius: CGFloat {
        switch size {
        case .small: return ModernDesignSystem.CornerRadius.small
        case .medium, .large: return ModernDesignSystem.CornerRadius.medium
        }
    }
    
    @ViewBuilder
    private var iconBorder: some View {
        switch style {
        case .ghost:
            RoundedRectangle(cornerRadius: iconCornerRadius)
                .stroke(AppTheme.border, lineWidth: 1)
        case .secondary:
            RoundedRectangle(cornerRadius: iconCornerRadius)
                .stroke(AppTheme.border.opacity(0.5), lineWidth: 1)
        default:
            EmptyView()
        }
    }
    
    private var iconShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch style {
        case .secondary:
            return ModernDesignSystem.Shadow.small
        case .surface:
            return (Color.black.opacity(0.03), 4, 2)
        default:
            return (Color.clear, 0, 0)
        }
    }
}

// MARK: - 向后兼容组件
struct GlassIconButton: View {
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        ModernIconButton(systemImage, style: .glass, action: action)
    }
}

struct GlassTinyButton: View {
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        ModernIconButton(systemImage, style: .glass, size: .small, action: action)
    }
}

struct GlassActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        ModernButton(
            title,
            systemImage: systemImage,
            style: .neon,
            action: action
        )
    }
}

struct GlassLinkCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }
}

struct GlassToggleButton: View {
    let title: String
    let systemImage: String
    @Binding var isActive: Bool
    let tint: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            isActive.toggle()
            action?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(GlassButtonStyle(tint: tint, isActive: isActive))
    }
}

struct GlassRecordingButton: View {
    let title: String
    @Binding var isRecording: Bool
    let tint: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            isRecording.toggle()
            action?()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(isRecording ? "点击停止" : "点击开始")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(GlassButtonStyle(tint: tint, isActive: isRecording))
    }
}

struct GlassTag: View {
    let text: String
    var isActive: Bool = false

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isActive ? 0.4 : 0.2), lineWidth: 1)
            )
    }
}

struct GlassButtonStyle: ButtonStyle {
    let tint: Color
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        tint.opacity(
                            configuration.isPressed
                            ? 0.18
                            : (isActive ? 0.14 : 0.10)
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - 统一按钮样式（白底紫边 / 紫色填充，无外框无阴影）
struct UnifiedAppButton: View {
    enum Style {
        case primary   // 紫色填充 + 白字
        case outline   // 白底 + 紫色描边 + 紫字
    }
    let title: String
    var systemImage: String? = nil
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.callout.weight(.semibold))
                }
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(buttonBackground)
            .foregroundStyle(style == .primary ? AppTheme.textOnPrimary : AppTheme.unifiedButtonBorder)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style == .outline ? AppTheme.unifiedButtonBorder : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: style == .primary ? AppTheme.primary.opacity(0.24) : Color.clear,
                radius: style == .primary ? 8 : 0,
                x: 0,
                y: style == .primary ? 4 : 0
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if style == .primary {
            AppTheme.primaryGradient
        } else {
            AppTheme.surface
        }
    }
}

/// 仅图标的统一风格按钮（圆形或圆角矩形）
struct UnifiedAppIconButton: View {
    let systemImage: String
    var isPrimary: Bool = false  // true = 紫色底白图标，false = 白底紫边紫图标
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isPrimary ? .white : AppTheme.unifiedButtonBorder)
                .frame(width: 36, height: 36)
                .background {
                    if isPrimary {
                        AppTheme.primaryGradient
                    } else {
                        AppTheme.surface
                    }
                }
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isPrimary ? Color.clear : AppTheme.unifiedButtonBorder, lineWidth: 1)
                )
                .shadow(
                    color: isPrimary ? AppTheme.primary.opacity(0.22) : Color.clear,
                    radius: isPrimary ? 6 : 0,
                    x: 0,
                    y: isPrimary ? 3 : 0
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 交互扩展
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}



// MARK: - 响应式设计系统
struct ResponsiveLayout {
    static var screenSize: CGSize {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: \.isKeyWindow) {
            return window.bounds.size
        }
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            return windowScene.screen.bounds.size
        }
        return CGSize(width: 393, height: 852)
        #elseif os(macOS)
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) ?? NSApp.mainWindow {
            return window.frame.size
        }
        return NSScreen.main?.visibleFrame.size ?? CGSize(width: 800, height: 600)
        #endif
    }
    
    static var isSmallPhone: Bool {
        screenSize.width < 375
    }
    
    static var isRegularPhone: Bool {
        screenSize.width >= 375 && screenSize.width < 414
    }
    
    static var isLargePhone: Bool {
        screenSize.width >= 414 && screenSize.width < 768
    }
    
    static var isTablet: Bool {
        screenSize.width >= 768
    }
    
    static var isLandscape: Bool {
        screenSize.width > screenSize.height
    }
    
    // 响应式间距
    static func spacing(_ type: SpacingType) -> CGFloat {
        let base = baseSpacing(type)
        let multiplier: CGFloat
        
        switch type {
        case .horizontal:
            multiplier = isSmallPhone ? 0.8 : (isTablet ? 1.5 : 1.0)
        case .vertical:
            multiplier = isSmallPhone ? 0.9 : (isTablet ? 1.2 : 1.0)
        case .card:
            multiplier = isSmallPhone ? 0.7 : (isTablet ? 1.3 : 1.0)
        }
        
        return base * multiplier
    }
    
    enum SpacingType {
        case horizontal, vertical, card
    }
    
    private static func baseSpacing(_ type: SpacingType) -> CGFloat {
        switch type {
        case .horizontal:
            return isSmallPhone ? 16 : 20
        case .vertical:
            return ModernDesignSystem.Spacing.md
        case .card:
            return ModernDesignSystem.Spacing.md
        }
    }
    
    // 响应式网格
    static func gridColumns() -> [GridItem] {
        if isTablet {
            return [
                GridItem(.flexible(), spacing: spacing(.card)),
                GridItem(.flexible(), spacing: spacing(.card)),
                GridItem(.flexible(), spacing: spacing(.card))
            ]
        } else if isLargePhone {
            return [
                GridItem(.flexible(), spacing: spacing(.card)),
                GridItem(.flexible(), spacing: spacing(.card))
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: spacing(.card))
            ]
        }
    }
    
    // 响应式字体大小
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let multiplier: CGFloat = isSmallPhone ? 0.9 : (isTablet ? 1.1 : 1.0)
        return .system(size: size * multiplier, weight: weight)
    }
}

// MARK: - 响应式容器组件
struct ResponsiveContainer<Content: View>: View {
    let content: Content
    let maxWidth: CGFloat?
    let alignment: Alignment
    
    init(
        maxWidth: CGFloat? = nil,
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.maxWidth = maxWidth
        self.alignment = alignment
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: maxWidth ?? .infinity, alignment: alignment)
            .padding(.horizontal, ResponsiveLayout.spacing(.horizontal))
    }
}

// MARK: - 响应式网格组件
struct ResponsiveGrid<Content: View, Data: RandomAccessCollection>: View {
    let data: Data
    let content: (Data.Element) -> Content
    
    init(data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: ResponsiveLayout.gridColumns(), spacing: ResponsiveLayout.spacing(.card)) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                content(item)
            }
        }
    }
}

// MARK: - 响应式Hero组件
struct ResponsiveHeroHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let badgeText: String?
    let headline: String
    let subheadline: String
    var leadingAction: (() -> Void)? = nil
    var style: ModernHeroHeader.HeroStyle = .gradient
    
    var body: some View {
        ModernHeroHeader(
            systemImage: systemImage,
            title: title,
            subtitle: subtitle,
            badgeText: badgeText,
            headline: ResponsiveLayout.isSmallPhone ? 
                String(headline.prefix(20)) + (headline.count > 20 ? "..." : "") : headline,
            subheadline: ResponsiveLayout.isSmallPhone ? 
                String(subheadline.prefix(30)) + (subheadline.count > 30 ? "..." : "") : subheadline,
            leadingAction: leadingAction,
            style: style
        )
    }
}

// MARK: - 响应式卡片网格
struct ResponsiveCardGrid<Item: Identifiable, CardContent: View>: View {
    let items: [Item]
    let cardContent: (Item) -> CardContent
    let maxColumns: Int
    
    init(
        items: [Item],
        maxColumns: Int = 2,
        @ViewBuilder cardContent: @escaping (Item) -> CardContent
    ) {
        self.items = items
        self.maxColumns = maxColumns
        self.cardContent = cardContent
    }
    
    var body: some View {
        GeometryReader { geometry in
            let columns = calculateColumns(for: geometry.size.width)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: ResponsiveLayout.spacing(.card)), count: columns),
                spacing: ResponsiveLayout.spacing(.card)
            ) {
                ForEach(items) { item in
                    cardContent(item)
                }
            }
        }
    }
    
    private func calculateColumns(for width: CGFloat) -> Int {
        let minCardWidth: CGFloat = 280
        let spacing = ResponsiveLayout.spacing(.card)
        let availableWidth = width - spacing * 2
        let possibleColumns = max(1, min(maxColumns, Int(availableWidth / (minCardWidth + spacing))))
        return possibleColumns
    }
}

// MARK: - 响应式文本组件
struct ResponsiveText: View {
    let text: String
    let style: TextStyle
    let maxLines: Int?
    
    enum TextStyle {
        case largeTitle, title, headline, subheadline, body, caption, footnote
        
        var font: Font {
            switch self {
            case .largeTitle:
                return .largeTitle.weight(.bold)
            case .title:
                return .title2.weight(.bold)
            case .headline:
                return .headline.weight(.semibold)
            case .subheadline:
                return .subheadline.weight(.medium)
            case .body:
                return .body
            case .caption:
                return .caption
            case .footnote:
                return .footnote
            }
        }
        
        var color: Color {
            switch self {
            case .largeTitle, .title, .headline:
                return AppTheme.textPrimary
            case .subheadline, .body:
                return AppTheme.textSecondary
            case .caption, .footnote:
                return AppTheme.textTertiary
            }
        }
    }
    
    init(
        _ text: String,
        style: TextStyle = .body,
        maxLines: Int? = nil
    ) {
        self.text = text
        self.style = style
        self.maxLines = maxLines
    }
    
    var body: some View {
        Text(text)
            .font(style.font)
            .foregroundStyle(style.color)
            .lineLimit(maxLines)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - 高级交互组件
struct InteractiveCard<Content: View>: View {
    let content: Content
    let onTap: (() -> Void)?
    let onLongPress: (() -> Void)?
    let style: ModernCardStyle
    let enableHaptics: Bool
    
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var showHighlight = false
    
    init(
        style: ModernCardStyle = .elevated,
        enableHaptics: Bool = true,
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.enableHaptics = enableHaptics
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.content = content()
    }
    
    var body: some View {
        ModernCard(style: style) {
            content
        }
        .scaleEffect(isPressed ? ModernDesignSystem.MicroInteractions.buttonScale : 
                     isHovered ? ModernDesignSystem.MicroInteractions.cardHoverScale : 1.0)
        .shadow(
            color: shadowColor,
            radius: isPressed ? 4 : (isHovered ? 12 : 8),
            x: 0,
            y: isPressed ? 2 : ModernDesignSystem.MicroInteractions.shadowOffset
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.xlarge)
                .fill(highlightColor)
                .opacity(showHighlight ? 1.0 : 0.0)
        )
        .pressEvents(
            onPress: {
                isPressed = true
                if enableHaptics {
                    HapticFeedback.light()
                }
            },
            onRelease: {
                isPressed = false
                showHighlight = false
            }
        )
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: 10,
            pressing: { pressing in
                if pressing {
                    showHighlight = true
                    if enableHaptics {
                        HapticFeedback.medium()
                    }
                }
            },
            perform: {
                onLongPress?()
            }
        )
        .onTapGesture {
            onTap?()
        }
        .animation(ModernDesignSystem.Animation.spring, value: isPressed)
        .animation(ModernDesignSystem.Animation.standard, value: isHovered)
        .animation(ModernDesignSystem.Animation.quick, value: showHighlight)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .elevated:
            return AppTheme.mediumShadow
        case .glass:
            return Color.black.opacity(0.1)
        default:
            return Color.black.opacity(0.05)
        }
    }
    
    private var highlightColor: Color {
        switch style {
        case .elevated:
            return AppTheme.primary.opacity(ModernDesignSystem.MicroInteractions.highlightOpacity)
        default:
            return AppTheme.border.opacity(ModernDesignSystem.MicroInteractions.highlightOpacity)
        }
    }
}

// MARK: - 触觉反馈系统
struct HapticFeedback {
    static func light() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
    
    static func medium() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
    
    static func heavy() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }
    
    static func impact() {
        medium()
    }
    
    static func success() {
        #if os(iOS)
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    static func error() {
        #if os(iOS)
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    static func warning() {
        #if os(iOS)
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    static func selectionChanged() {
        #if os(iOS)
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
}

// MARK: - 加载动画组件
struct AnimatedLoadingView: View {
    let isLoading: Bool
    let text: String?
    @State private var rotation: Angle = .zero
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(AppTheme.border, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AppTheme.primary,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 24, height: 24)
                    .rotationEffect(rotation)
            }
            
            if let text = text {
                ResponsiveText(text, style: .caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .onAppear {
            if isLoading {
                startRotation()
            }
        }
        .onChange(of: isLoading) { _, newValue in
            if newValue {
                startRotation()
            } else {
                stopRotation()
            }
        }
    }
    
    private func startRotation() {
        withAnimation(ModernDesignSystem.Animation.loading) {
            rotation = .degrees(360)
        }
    }
    
    private func stopRotation() {
        withAnimation(ModernDesignSystem.Animation.quick) {
            rotation = .zero
        }
    }
}

// MARK: - Shimmer加载效果
struct ShimmerView: View {
    @State private var shimmerOffset: CGFloat = -200
    let isLoading: Bool
    
    var body: some View {
        Rectangle()
            .fill(AppTheme.surface)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.surface,
                                AppTheme.surfaceMuted.opacity(0.8),
                                AppTheme.surface
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .mask(
                        Rectangle()
                            .fill(Color.black)
                    )
            )
            .onAppear {
                if isLoading {
                    startShimmer()
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if newValue {
                    startShimmer()
                }
            }
    }
    
    private func startShimmer() {
        withAnimation(ModernDesignSystem.Animation.shimmer) {
            shimmerOffset = 200
        }
    }
}

// MARK: - 页面转场动画
struct PageTransition<Content: View>: View {
    let content: Content
    let isVisible: Bool
    
    init(isVisible: Bool, @ViewBuilder content: () -> Content) {
        self.isVisible = isVisible
        self.content = content()
    }
    
    var body: some View {
        content
            .offset(y: isVisible ? 0 : 50)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(ModernDesignSystem.Animation.modalPresentation, value: isVisible)
    }
}

// MARK: - 弹性动画按钮
struct BouncyButton: View {
    let title: String
    let systemImage: String?
    let style: ModernButton.ButtonStyle
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isAnimating = false
    
    init(
        _ title: String,
        systemImage: String? = nil,
        style: ModernButton.ButtonStyle = .neon,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }
    
    var body: some View {
        ModernButton(title, systemImage: systemImage, style: style) {
            buttonAction()
        }
        .scaleEffect(isPressed ? 0.9 : (isAnimating ? 1.05 : 1.0))
        .animation(
            isPressed ? ModernDesignSystem.Animation.buttonPress :
            ModernDesignSystem.Animation.bouncy,
            value: isPressed
        )
        .animation(ModernDesignSystem.Animation.bouncy, value: isAnimating)
    }
    
    private func buttonAction() {
        HapticFeedback.light()
        isPressed = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
            isAnimating = true
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }
    }
}

// MARK: - 无障碍性增强组件
struct AccessibleButton: View {
    let title: String
    let systemImage: String?
    let hint: String?
    let action: () -> Void
    let style: ModernButton.ButtonStyle
    
    init(
        _ title: String,
        systemImage: String? = nil,
        hint: String? = nil,
        style: ModernButton.ButtonStyle = .neon,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.hint = hint
        self.style = style
        self.action = action
    }
    
    var body: some View {
        ModernButton(title, systemImage: systemImage, style: style, action: action)
            .accessibilityLabel(title)
            .accessibilityHint(hint ?? "点击\(title)")
            .accessibilityAddTraits(.isButton)
    }
}

struct AccessibleCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let onTap: (() -> Void)?
    let content: Content
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        InteractiveCard(onTap: onTap) {
            content
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(onTap != nil ? "双击查看详情" : "")
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }
    
    private var accessibilityLabel: String {
        var label = ""
        if let title = title {
            label += title
        }
        if let subtitle = subtitle {
            label += (label.isEmpty ? "" : "，") + subtitle
        }
        return label.isEmpty ? "卡片" : label
    }
}

// MARK: - 用户体验优化组件
struct ErrorHandlingView<Data, Content: View, ErrorContent: View>: View {
    @Binding var state: ViewState<Data>
    let content: (Data) -> Content
    let errorView: (Error) -> ErrorContent
    
    enum ViewState<T> {
        case idle
        case loading
        case loaded(T)
        case error(Error)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }
    
    init(
        state: Binding<ViewState<Data>>,
        @ViewBuilder content: @escaping (Data) -> Content,
        @ViewBuilder errorView: @escaping (Error) -> ErrorContent
    ) {
        self._state = state
        self.content = content
        self.errorView = errorView
    }
    
    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                AnimatedLoadingView(isLoading: true, text: "加载中...")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let data):
            content(data)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .error(let error):
            errorView(error)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
    }
}

struct SmartErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        ModernCard(style: .elevated) {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: errorIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.error)
                    
                    VStack(spacing: ModernDesignSystem.Spacing.xs) {
                        ResponsiveText("出现错误", style: .headline)
                        ResponsiveText(errorMessage, style: .subheadline)
                            .multilineTextAlignment(.center)
                    }
                }
                
                if let retryAction = retryAction {
                    ModernButton("重试", style: .neon, action: retryAction)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("错误提示：\(errorMessage)")
    }
    
    private var errorIcon: String {
        if errorMessage.contains("网络") {
            return "wifi.slash"
        } else if errorMessage.contains("加载") {
            return "exclamationmark.triangle"
        } else {
            return "xmark.circle"
        }
    }
    
    private var errorMessage: String {
        return error.localizedDescription.isEmpty ? "发生了未知错误" : error.localizedDescription
    }
}

// MARK: - 智能通知系统
struct SmartToast: View {
    let message: String
    let type: ToastType
    let duration: TimeInterval
    @Binding var isPresented: Bool
    
    enum ToastType {
        case success, error, warning, info
        
        var color: Color {
            switch self {
            case .success: return AppTheme.success
            case .error: return AppTheme.error
            case .warning: return AppTheme.warning
            case .info: return AppTheme.info
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var haptic: () -> Void {
            switch self {
            case .success: return { DispatchQueue.main.async { HapticFeedback.success() } }
            case .error: return { DispatchQueue.main.async { HapticFeedback.error() } }
            case .warning: return { DispatchQueue.main.async { HapticFeedback.warning() } }
            case .info: return { DispatchQueue.main.async { HapticFeedback.light() } }
            }
        }
    }
    
    init(
        _ message: String,
        type: ToastType = .info,
        duration: TimeInterval = 3.0,
        isPresented: Binding<Bool>
    ) {
        self.message = message
        self.type = type
        self.duration = duration
        self._isPresented = isPresented
    }
    
    var body: some View {
        if isPresented {
            VStack {
                Spacer()
                
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(type.color)
                    
                    ResponsiveText(message, style: .subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.all, ModernDesignSystem.Spacing.md)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large))
                .shadow(color: AppTheme.mediumShadow, radius: 12, x: 0, y: 6)
                .padding(.horizontal, ResponsiveLayout.spacing(.horizontal))
                .padding(.bottom, safeAreaBottom + 40)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(type == .success ? "成功" : type == .error ? "错误" : type == .warning ? "警告" : "提示")：\(message)")
                .accessibilityAddTraits(.isStaticText)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                type.haptic()
                hideAfterDelay()
            }
        }
    }
    
    private func hideAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(ModernDesignSystem.Animation.standard) {
                isPresented = false
            }
        }
    }
    
    private var safeAreaBottom: CGFloat {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
        #elseif os(macOS)
        return 0
        #endif
    }
}

// MARK: - 性能优化组件
struct OptimizedAsyncImage: View {
    let url: URL?
    let placeholder: AnyView
    @State private var imageLoaded = false
    
    init(url: URL?, placeholder: AnyView) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .onAppear {
                    imageLoaded = true
                }
        } placeholder: {
            placeholder
                .overlay(
                    !imageLoaded ? ShimmerView(isLoading: true) : nil
                )
        }
        .clipped()
        .transition(.opacity)
    }
}

// MARK: - Unified page scaffold
struct AppPageScaffold<Content: View>: View {
    var maxWidth: CGFloat? = 980
    var horizontalPadding: CGFloat = 20
    var topPadding: CGFloat = 16
    var bottomPadding: CGFloat = 32
    var spacing: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.10))
                    .frame(width: 380, height: 380)
                    .blur(radius: 80)
                    .offset(x: -220, y: -220)
                Spacer()
            }
            VStack {
                Spacer()
                Circle()
                    .fill(AppTheme.secondary.opacity(0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(x: 210, y: 180)
            }
            ScrollView {
                VStack(spacing: spacing) {
                    content()
                }
                .frame(maxWidth: maxWidth, alignment: .topLeading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.automatic)
        }
        .hideNavigationBarOnMac()
    }
}

// MARK: - 全屏/Sheet 兼容（iOS 全屏，macOS 用 Sheet）
extension View {
    @ViewBuilder
    func fullScreenCoverOrSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #elseif os(macOS)
        self.sheet(isPresented: isPresented, content: content)
        #endif
    }
}

// MARK: - macOS 兼容的导航栏修饰符
extension View {
    @ViewBuilder
    func hideNavigationBarOnMac() -> some View {
        self
    }
    
    @ViewBuilder
    func glassNavigationBar() -> some View {
        #if os(iOS)
        self.toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }
}

// MARK: - 现代化View扩展
extension View {
    func modernCard(style: ModernCardStyle = .elevated) -> some View {
        ModernCard(style: style) {
            self
        }
    }
    
    func glassCard() -> some View {
        modernCard(style: .glass)
    }

    func glassNavigation() -> some View {
        self.glassNavigationBar()
    }

    func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #elseif os(macOS)
        NSApp.sendAction(#selector(NSResponder.resignFirstResponder), to: nil, from: nil)
        #endif
    }
    
    // 响应式容器
    func responsiveContainer(maxWidth: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        ResponsiveContainer(maxWidth: maxWidth, alignment: alignment) {
            self
        }
    }
    
    // 响应式条件修饰符
    @ViewBuilder
    func responsive<V: View>(
        if condition: Bool,
        transform: (Self) -> V
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    // 设备类型修饰符
    @ViewBuilder
    func phone<V: View>(transform: (Self) -> V) -> some View {
        if !ResponsiveLayout.isTablet {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func tablet<V: View>(transform: (Self) -> V) -> some View {
        if ResponsiveLayout.isTablet {
            transform(self)
        } else {
            self
        }
    }
    
    // 安全区域适配
    func safeAreaPadding() -> some View {
        self
            .padding(.top, safeAreaTop)
            .padding(.bottom, safeAreaBottom)
    }
    
    private var safeAreaTop: CGFloat {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 0
        #elseif os(macOS)
        return 0
        #endif
    }
    
    private var safeAreaBottom: CGFloat {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
        #elseif os(macOS)
        return 0
        #endif
    }
}
