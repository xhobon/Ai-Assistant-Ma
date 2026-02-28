import SwiftUI

struct AIAssistantDesignedHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var inputText = ""

    private let topTags = ["学习问答", "模拟面试", "文章创作", "代码辅助"]

    private let writingTools: [AssistantToolItem] = [
        .init(title: "全文生成", icon: "doc.text", tint: Color(red: 0.89, green: 0.93, blue: 1.0), destination: .writing),
        .init(title: "PPT生成", icon: "rectangle.stack", tint: Color(red: 0.98, green: 0.91, blue: 0.95), destination: .ppt),
        .init(title: "改写润色", icon: "pencil.and.outline", tint: Color(red: 0.98, green: 0.92, blue: 0.96), destination: .chat),
        .init(title: "单句扩写", icon: "wand.and.stars", tint: Color(red: 0.88, green: 0.97, blue: 1.0), destination: .chat),
        .init(title: "文章续写", icon: "arrow.triangle.branch", tint: Color(red: 0.88, green: 0.97, blue: 1.0), destination: .chat)
    ]

    private let careerTools: [String] = ["职业规划", "简历优化", "简历生成", "模拟面试"]
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                topBar
                heroCard
                toolSection(title: "辅助·智能写作", items: writingTools)
                compactSection(title: "辅助·就业实习", items: careerTools)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: pageMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI小酱")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("剩余：5000字")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 10) {
                iconTopButton(system: "magnifyingglass", label: "搜索")
                iconTopButton(system: "clock", label: "历史")
            }
        }
    }

    private func iconTopButton(system: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.74, green: 0.83, blue: 1.0))
                        .frame(width: 46, height: 46)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0.26, green: 0.38, blue: 0.93))
                }
                Text("你好，我是小酱问问～")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
            }

            NavigationLink {
                AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
            } label: {
                HStack(spacing: 10) {
                    Text(inputText.isEmpty ? "点击输入聊天内容" : inputText)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(inputText.isEmpty ? AppTheme.textTertiary : AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 38, height: 38)
                        .background(Color(red: 0.92, green: 0.95, blue: 1.0))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.37, green: 0.36, blue: 0.95), lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.81, green: 0.88, blue: 1.0), Color(red: 0.82, green: 0.92, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func toolSection(title: String, items: [AssistantToolItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items) { item in
                    NavigationLink {
                        destinationView(item.destination)
                    } label: {
                        HStack {
                            Text(item.title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(item.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func compactSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func destinationView(_ destination: AssistantEntryDestination) -> some View {
        switch destination {
        case .chat:
            AIAssistantChatView(title: "AI助理", allowLocalExecution: false)
        case .writing:
            WritingStudioView()
        case .ppt:
            PPTStudioView()
        }
    }
}

private struct AssistantToolItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let destination: AssistantEntryDestination
}

private enum AssistantEntryDestination {
    case chat
    case writing
    case ppt
}
