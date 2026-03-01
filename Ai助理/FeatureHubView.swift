import SwiftUI

struct FeatureHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                capabilitySection
                learningSection
                tipsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("扩展功能")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("功能扩展中心")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("这里承接非核心流程，主页面保持轻量与高频操作。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.88, green: 0.93, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var capabilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("翻译扩展")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            FeatureRow(title: "实时语音翻译", subtitle: "边说边译并自动播报", icon: "waveform.badge.mic") {
                RealTimeTranslationView()
            }
            FeatureRow(title: "文本翻译主页", subtitle: "导入音频/视频并转写翻译", icon: "character.bubble.fill") {
                AITranslateHomeView()
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("学习扩展")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            FeatureRow(title: "学习页主页", subtitle: "词汇、短句与分类学习", icon: "book.fill") {
                IndonesianLearningView()
            }
            FeatureRow(title: "写作工作台", subtitle: "全文生成、改写与续写", icon: "square.and.pencil") {
                WritingStudioView()
            }
            FeatureRow(title: "PPT 工作台", subtitle: "PPT 生成与结构建议", icon: "rectangle.stack.fill") {
                PPTStudioView()
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说明")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("核心页只保留高频主流程；扩展功能与低频入口统一放在这里，避免页面拥挤。")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FeatureRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 34, height: 34)
                    .background(Color(red: 0.91, green: 0.95, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(10)
            .background(AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

