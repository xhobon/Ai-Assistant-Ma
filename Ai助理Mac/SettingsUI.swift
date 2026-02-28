import SwiftUI

// MARK: - Settings UI Kit (shared layout/components)

struct SettingsPage<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var trailing: AnyView? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsHeader(title: title, trailing: trailing, onBack: { dismiss() })
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.automatic)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .hideNavigationBarOnMac()
    }
}

struct SettingsHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var onBack: () -> Void

    var body: some View {
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
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Group {
                if let trailing { trailing }
                else { Color.clear.frame(width: 36, height: 36) }
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            content()
        }
        .glassCard()
    }
}

struct SettingsRow: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var tint: Color = AppTheme.textPrimary
    var isDestructive: Bool = false
    var showChevron: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDestructive ? Color.red : tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isDestructive ? Color.red : AppTheme.textPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if let value, !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
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
        .buttonStyle(.plain)
        .disabled(action == nil)
        .opacity(action == nil ? 0.7 : 1)
    }
}

struct SettingsInlineToggleRow: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
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

// MARK: - Toast

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
            .shadow(color: AppTheme.softShadow, radius: 10, x: 0, y: 6)
            .padding(.top, 10)
    }
}

struct ToastPresenter: ViewModifier {
    @Binding var message: String?
    let duration: Duration

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let message {
                ToastView(text: message)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: duration)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.message = nil
                        }
                    }
            }
        }
    }
}

extension View {
    func toast(message: Binding<String?>, duration: Duration = .seconds(1.6)) -> some View {
        modifier(ToastPresenter(message: message, duration: duration))
    }
}

