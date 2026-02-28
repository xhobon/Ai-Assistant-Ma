import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AITranslateHomeView: View {
    @StateObject private var viewModel = TranslateViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let quickPhrases = [
        "你好，很高兴认识你",
        "请问洗手间在哪里？",
        "谢谢你的帮助",
        "我想预订一个房间"
    ]
    private var pageMaxWidth: CGFloat {
        horizontalSizeClass == .compact ? .infinity : 760
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                TranslateShowcaseCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                ModernTranslationQuickLinksRow(history: viewModel.history)
                    .padding(.horizontal, 16)

                DualTranslationInputCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                ModernTranslationActionBar(viewModel: viewModel)
                    .padding(.horizontal, 16)

                TranslateQuickPhraseSection(
                    phrases: quickPhrases,
                    onSelect: { phrase in
                        viewModel.sourceText = phrase
                        viewModel.translatedText = ""
                        viewModel.scheduleAutoTranslate()
                    }
                )
                .padding(.horizontal, 16)

                ModernTranslationHistorySection(history: viewModel.history)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
            .padding(.top, 10)
            .frame(maxWidth: pageMaxWidth, alignment: .top)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollIndicators(.automatic)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            hideKeyboard()
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
}

private struct TranslateShowcaseCard: View {
    @ObservedObject var viewModel: TranslateViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI翻译")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("文本 · 语音 · 双向翻译")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button {
                    viewModel.clearHistory()
                } label: {
                    Text("清空记录")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                featurePill(
                    title: "实时语音",
                    subtitle: "边说边译",
                    systemImage: "waveform.circle.fill",
                    tint: AppTheme.primary
                )
                featurePill(
                    title: "历史同步",
                    subtitle: "本地可回看",
                    systemImage: "clock.arrow.circlepath",
                    tint: AppTheme.accentWarm
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.87, green: 0.93, blue: 1.0),
                            Color(red: 0.94, green: 0.96, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func featurePill(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TranslateQuickPhraseSection: View {
    let phrases: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常用短句")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(phrases, id: \.self) { phrase in
                        Button {
                            onSelect(phrase)
                        } label: {
                            Text(phrase)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.surface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ModernTranslateHeroHeader: View {
    var body: some View {
        ModernHeroHeader(
            systemImage: "globe",
            title: "AI翻译",
            subtitle: "即时翻译 · 语音与文本同步",
            badgeText: "双向互译",
            headline: "输入文本或使用语音开始翻译",
            subheadline: "支持实时语音翻译与历史记录同步",
            style: .gradient
        )
    }
}

// 翻译页紧凑页头（省空间）
struct TranslatePageCompactHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "globe")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                Text("AI翻译")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text("输入文本或使用语音开始 · 支持实时语音与历史同步")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// 向后兼容
struct TranslateHeroHeader: View {
    var body: some View {
        ModernTranslateHeroHeader()
    }
}

struct ModernTranslationQuickLinksRow: View {
    let history: [TranslationEntry]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                VStack(spacing: 10) {
                    quickVoiceEntry
                    quickHistoryEntry
                }
            } else {
                HStack(spacing: 10) {
                    quickVoiceEntry
                    quickHistoryEntry
                }
            }
        }
    }

    private var quickVoiceEntry: some View {
        NavigationLink {
            RealTimeTranslationView()
        } label: {
            ModernTranslationQuickLinkCard(
                title: "实时语音翻译",
                subtitle: "双语对话实时输出",
                systemImage: "waveform.circle.fill",
                accent: AppTheme.primary
            )
        }
        .buttonStyle(.plain)
    }

    private var quickHistoryEntry: some View {
        NavigationLink {
            AllTranslationRecordsView(history: history)
        } label: {
            ModernTranslationQuickInfoCard(
                title: "翻译记录",
                subtitle: "点击查看全部",
                systemImage: "clock.arrow.circlepath",
                count: history.count
            )
        }
        .buttonStyle(.plain)
    }
}

// 向后兼容
struct TranslationQuickLinksRow: View {
    var history: [TranslationEntry] = []
    var body: some View {
        ModernTranslationQuickLinksRow(history: history)
    }
}

struct TranslationQuickLinkCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TranslationQuickInfoCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surfaceMuted)
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TranslationInputCard: View {
    @ObservedObject var viewModel: TranslateViewModel

    var body: some View {
        VStack(spacing: 14) {
            TranslationInputHeader(
                sourceLang: viewModel.sourceLang.name,
                targetLang: viewModel.targetLang.name,
                onSwap: viewModel.swapLanguages
            )

            TranslationInputField(
                title: viewModel.sourceLang.name,
                placeholder: "输入文本或使用语音",
                text: $viewModel.sourceText,
                tint: AppTheme.textPrimary,
                isEditable: true,
                onMic: { viewModel.toggleListening(side: .left) }
            )

            TranslationInputField(
                title: viewModel.targetLang.name,
                placeholder: "Masukkan teks",
                text: .constant(viewModel.translatedText),
                tint: AppTheme.brandBlue,
                isEditable: false,
                onMic: { viewModel.toggleListening(side: .right) }
            )
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 4)
    }
}

struct TranslationInputHeader: View {
    let sourceLang: String
    let targetLang: String
    var onSwap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(sourceLang)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(targetLang)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Button(action: onSwap) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("切换")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accentStrong)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.accentStrong.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }
}

struct TranslationInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let tint: Color
    let isEditable: Bool
    var onMic: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(tint.opacity(0.8))
                Spacer()
                Button(action: onMic) {
                    Image(systemName: "mic.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            if isEditable {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    TextEditor(text: $text)
                        .font(.title3.weight(.semibold))
                        .frame(minHeight: 52)
                        .foregroundStyle(AppTheme.inputText)
                        .scrollContentBackground(.hidden)
                }
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(4)
            }
        }
        .padding(12)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TranslationResultCard: View {
    @ObservedObject var viewModel: TranslateViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("翻译结果")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !viewModel.translatedText.isEmpty {
                    Text("可播放")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            ResultRow(
                title: viewModel.sourceLang.name,
                text: viewModel.sourceText.isEmpty ? "你好" : viewModel.sourceText,
                tint: AppTheme.textPrimary,
                onPlay: viewModel.playResult
            )

            Divider().opacity(0.2)

            ResultRow(
                title: viewModel.targetLang.name,
                text: viewModel.translatedText.isEmpty ? "Halo" : viewModel.translatedText,
                tint: AppTheme.brandBlue,
                onPlay: viewModel.playResult
            )
        }
        .padding(18)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 4)
    }
}

struct ResultRow: View {
    let title: String
    let text: String
    let tint: Color
    var onPlay: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(tint.opacity(0.8))
                Text(text)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Spacer()
            PlayButton(tint: tint, action: onPlay)
        }
    }
}

struct VoiceStatusBar: View {
    let isListening: Bool
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isListening ? AppTheme.accentStrong.opacity(0.18) : AppTheme.textSecondary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: isListening ? "waveform" : "waveform.slash")
                    .foregroundStyle(isListening ? AppTheme.accentStrong : AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isListening ? "语音识别中" : "语音待机")
                    .font(.subheadline.weight(.semibold))
                Text(isListening ? "说完自动翻译，可点击停止" : "说完自动识别语言并翻译，可手动停止")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: onToggle) {
                Text(isListening ? "停止" : "开始")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isListening ? AppTheme.accentStrong.opacity(0.18) : AppTheme.brandBlue.opacity(0.15))
                    .foregroundStyle(isListening ? AppTheme.accentStrong : AppTheme.brandBlue)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.softShadow.opacity(0.8), radius: 6, x: 0, y: 3)
    }
}

struct TranslationActionBar: View {
    @ObservedObject var viewModel: TranslateViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { viewModel.swapLanguages() }) {
                    HStack(spacing: 6) {
                        Text(viewModel.sourceLang.name)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption.weight(.semibold))
                        Text(viewModel.targetLang.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.unifiedButtonBorder)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Button { viewModel.translate() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text(viewModel.isTranslating ? "翻译中..." : "立即翻译")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(viewModel.sourceText.isEmpty ? AppTheme.unifiedButtonPrimary.opacity(0.5) : AppTheme.unifiedButtonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.sourceText.isEmpty)
            }

            HStack(spacing: 12) {
                TranslationActionTile(title: viewModel.isListening ? "停止听译" : "听译", systemImage: "mic", tint: AppTheme.brandBlue) {
                    viewModel.toggleListening(side: .left)
                }
                TranslationActionTile(title: "复制结果", systemImage: "doc.on.doc", tint: AppTheme.textSecondary) {
                    viewModel.copyResult()
                }
                TranslationActionTile(title: "朗读结果", systemImage: "speaker.wave.2", tint: AppTheme.accentWarm) {
                    viewModel.playResult()
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.softShadow.opacity(0.8), radius: 6, x: 0, y: 3)
    }
}

struct ActionChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}

struct TranslationActionTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.unifiedButtonBorder)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct TranslationHistorySection: View {
    let history: [TranslationEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("翻译历史")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("最近 10 条")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if history.isEmpty {
                Text("暂无翻译记录")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(history.prefix(10)) { item in
                    TranslationHistoryRow(entry: item)
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 4)
    }
}

struct TranslationHistoryRow: View {
    let entry: TranslationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.sourceText)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(entry.targetText)
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(12)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MicButton: View {
    var tint: Color = AppTheme.textSecondary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic")
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(AppTheme.background)
                .clipShape(Circle())
        }
    }
}

struct PlayButton: View {
    var tint: Color = AppTheme.textPrimary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
        }
    }
}

struct IconActionButton: View {
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.brandBlue)
        }
    }
}

struct CircleSwapButton: View {
    var action: () -> Void = {}

    var body: some View {
        UnifiedAppIconButton(systemImage: "arrow.left.arrow.right") {
            action()
        }
        .offset(y: 8)
    }
}

struct RealTimeTranslationView: View {
    @StateObject private var viewModel = RealTimeTranslateViewModel()
    @Environment(\.dismiss) private var dismiss

    private var isRecording: Bool {
        viewModel.isLeftRecording || viewModel.isRightRecording
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                RealTimeCompactHeader(isRecording: isRecording, onClose: { dismiss() })
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.entries) { entry in
                                VStack(spacing: 8) {
                                    if entry.sourceLanguage == .chinese {
                                        // 原文是中文：中文为“原文气泡”，印尼文为“译文气泡”
                                        RealtimeSpeechBubble(
                                            title: "中文",
                                            text: entry.chinese,
                                            placeholder: "",
                                            languageTint: AppTheme.accentWarm,
                                            alignTrailing: true,
                                            isSource: true,
                                            languageForSpeech: "zh-CN",
                                            onCopy: { ClipboardService.copy(entry.chinese) }
                                        )
                                        RealtimeSpeechBubble(
                                            title: "印度尼西亚语",
                                            text: entry.indonesian,
                                            placeholder: "",
                                            languageTint: AppTheme.brandBlue,
                                            isSource: false,
                                            languageForSpeech: "id-ID",
                                            onCopy: { ClipboardService.copy(entry.indonesian) }
                                        )
                                    } else {
                                        // 原文是印尼文：印尼文为“原文气泡”，中文为“译文气泡”
                                        RealtimeSpeechBubble(
                                            title: "印度尼西亚语",
                                            text: entry.indonesian,
                                            placeholder: "",
                                            languageTint: AppTheme.brandBlue,
                                            isSource: true,
                                            languageForSpeech: "id-ID",
                                            onCopy: { ClipboardService.copy(entry.indonesian) }
                                        )
                                        RealtimeSpeechBubble(
                                            title: "中文",
                                            text: entry.chinese,
                                            placeholder: "",
                                            languageTint: AppTheme.accentWarm,
                                            alignTrailing: true,
                                            isSource: false,
                                            languageForSpeech: "zh-CN",
                                            onCopy: { ClipboardService.copy(entry.chinese) }
                                        )
                                    }
                                }
                            }
                            VStack(spacing: 8) {
                                if viewModel.currentSourceLanguage == .chinese {
                                    // 当前原文预期为中文：中文为“原文气泡”，印尼文为“译文气泡”
                                    let chineseText = viewModel.rightText.isEmpty ? viewModel.rightTranslated : viewModel.rightText
                                    let indonesianText = viewModel.leftText.isEmpty ? viewModel.leftTranslated : viewModel.leftText
                                    RealtimeSpeechBubble(
                                        title: "中文",
                                        text: chineseText,
                                        placeholder: (viewModel.isTranslating && viewModel.rightText.isEmpty) ? "翻译中..." : "等待语音...",
                                        languageTint: AppTheme.accentWarm,
                                        alignTrailing: true,
                                        isSource: true,
                                        languageForSpeech: "zh-CN",
                                        onCopy: { ClipboardService.copy(chineseText) }
                                    )
                                    RealtimeSpeechBubble(
                                        title: "印度尼西亚语",
                                        text: indonesianText,
                                        placeholder: (viewModel.isTranslating && viewModel.leftText.isEmpty) ? "翻译中..." : "等待语音...",
                                        languageTint: AppTheme.brandBlue,
                                        isSource: false,
                                        languageForSpeech: "id-ID",
                                        onCopy: { ClipboardService.copy(indonesianText) }
                                    )
                                } else {
                                    // 当前原文预期为印尼文：印尼文为“原文气泡”，中文为“译文气泡”
                                    let indonesianText = viewModel.leftText.isEmpty ? viewModel.leftTranslated : viewModel.leftText
                                    let chineseText = viewModel.rightText.isEmpty ? viewModel.rightTranslated : viewModel.rightText
                                    RealtimeSpeechBubble(
                                        title: "印度尼西亚语",
                                        text: indonesianText,
                                        placeholder: (viewModel.isTranslating && viewModel.leftText.isEmpty) ? "翻译中..." : "等待语音...",
                                        languageTint: AppTheme.brandBlue,
                                        isSource: true,
                                        languageForSpeech: "id-ID",
                                        onCopy: { ClipboardService.copy(indonesianText) }
                                    )
                                    RealtimeSpeechBubble(
                                        title: "中文",
                                        text: chineseText,
                                        placeholder: (viewModel.isTranslating && viewModel.rightText.isEmpty) ? "翻译中..." : "等待语音...",
                                        languageTint: AppTheme.accentWarm,
                                        alignTrailing: true,
                                        isSource: false,
                                        languageForSpeech: "zh-CN",
                                        onCopy: { ClipboardService.copy(chineseText) }
                                    )
                                }
                            }
                            .id("current")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.borderStrong.opacity(0.85), lineWidth: 1.1)
                    )
                    .shadow(color: AppTheme.softShadow, radius: 12, x: 0, y: 5)
                    .onChange(of: viewModel.entries.count) { _, _ in
                        withAnimation { proxy.scrollTo("current", anchor: .bottom) }
                    }
                }
                .padding(.horizontal, 14)

                VoiceControlBar(
                    isLeftRecording: viewModel.isLeftRecording,
                    isRightRecording: viewModel.isRightRecording,
                    onLeft: viewModel.toggleLeft,
                    onRight: viewModel.toggleRight
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .navigationTitle("实时语音翻译")
        .alert("提示", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct RealTimeHeader: View {
    let isRecording: Bool
    var onClose: () -> Void

    var body: some View {
        UnifiedHeroHeader(
            systemImage: "chevron.left",
            title: "实时语音翻译",
            subtitle: "双语对话实时输出",
            badgeText: isRecording ? "录音中" : "待机",
            headline: "轻触下方按钮开始对话",
            subheadline: "系统将自动识别语言并实时生成文本",
            leadingAction: onClose
        )
    }
}

// 实时翻译页紧凑页头（二级页面用）
struct RealTimeCompactHeader: View {
    let isRecording: Bool
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.textOnPrimary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.primary.opacity(0.24), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("实时语音翻译")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("双语对话实时输出")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 10)
            Text(isRecording ? "录音中" : "待机")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isRecording ? AppTheme.accentWarm : AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.surfaceMuted)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(AppTheme.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 3)
    }
}

private struct RealTimeLiveBanner: View {
    let isRecording: Bool
    let sourceLanguage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isRecording ? "waveform.badge.mic" : "mic.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isRecording ? AppTheme.primary : AppTheme.textSecondary)
                .frame(width: 30, height: 30)
                .background((isRecording ? AppTheme.primary : AppTheme.textSecondary).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(isRecording ? "正在监听语音输入" : "等待语音输入")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("当前主讲语言：\(sourceLanguage)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 8)
            Text(isRecording ? "实时中" : "空闲")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isRecording ? AppTheme.primary : AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.surfaceMuted)
                .clipShape(Capsule())
        }
        .padding(10)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.borderStrong.opacity(0.75), lineWidth: 1)
        )
    }
}

struct RealTimeStatusStrip: View {
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isRecording ? AppTheme.accentWarm.opacity(0.2) : AppTheme.surfaceMuted)
                    .frame(width: 40, height: 40)
                Image(systemName: isRecording ? "waveform" : "waveform.slash")
                    .foregroundStyle(isRecording ? AppTheme.accentWarm : AppTheme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isRecording ? "正在识别语音" : "等待语音输入")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(isRecording ? "说话时请保持手机稳定" : "点击任一语言按钮开始")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Text(isRecording ? "正在输入" : "待机中")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isRecording ? AppTheme.accentWarm : AppTheme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppTheme.surfaceMuted)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct RealTimeWaveformPanel: View {
    let isLeftActive: Bool
    let isRightActive: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("语音波形监测")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Text(isLeftActive || isRightActive ? "正在识别" : "等待语音")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            WaveformRow(title: "印尼语", isActive: isLeftActive, tint: AppTheme.brandBlue)
            WaveformRow(title: "中文", isActive: isRightActive, tint: AppTheme.accentWarm)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct WaveformRow: View {
    let title: String
    let isActive: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 52, alignment: .leading)

            WaveformBars(isActive: isActive, tint: tint)
        }
    }
}

struct WaveformBars: View {
    let isActive: Bool
    let tint: Color
    private let barCount = 14

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    let phase = Double(index) * 0.55
                    let normalized = isActive ? (sin(time * 2.2 + phase) + 1) / 2 : 0.15
                    let height = 6 + normalized * 20

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tint.opacity(isActive ? 0.9 : 0.4))
                        .frame(width: 6, height: height)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.5), value: isActive)
        }
    }
}

struct VoiceControlBar: View {
    let isLeftRecording: Bool
    let isRightRecording: Bool
    var onLeft: () -> Void
    var onRight: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VoiceRecordButton(
                title: "印尼语",
                tint: AppTheme.brandBlue,
                isRecording: isLeftRecording,
                action: onLeft
            )
            Spacer(minLength: 40)
            VoiceRecordButton(
                title: "中文",
                tint: AppTheme.accentWarm,
                isRecording: isRightRecording,
                action: onRight
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.borderStrong.opacity(0.75), lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 3)
    }
}

struct VoiceRecordButton: View {
    let title: String
    let tint: Color
    let isRecording: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isRecording ? tint : tint.opacity(0.14))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(isRecording ? Color.clear : tint.opacity(0.35), lineWidth: 1))
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isRecording ? .white : tint)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .frame(minWidth: 76)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

struct SpeechBubbleCard: View {
    let title: String
    let text: String
    let placeholder: String
    let tint: Color
    var alignTrailing: Bool = false
    var languageForSpeech: String? = nil
    var onCopy: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 8) {
            HStack {
                if alignTrailing { Spacer(minLength: 0) }
                if let lang = languageForSpeech, !text.isEmpty {
                    HStack(spacing: 8) {
                        Button {
                            SpeechService.shared.speak(text, language: lang)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(tint)
                        }
                        Button {
                            onCopy?()
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption)
                                .foregroundStyle(tint)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(tint.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(tint)
                }
                if !alignTrailing { Spacer(minLength: 0) }
            }
            Text(text.isEmpty ? placeholder : text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint.opacity(text.isEmpty ? 0.7 : 1))
                .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
                .lineLimit(10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
        .background(tint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

/// 实时语音翻译：对话式气泡（贴近 AI 助理对话样式）
struct RealtimeSpeechBubble: View {
    let title: String
    let text: String
    let placeholder: String
    let languageTint: Color
    var alignTrailing: Bool = false
    var isSource: Bool = false
    var languageForSpeech: String? = nil
    var onCopy: (() -> Void)? = nil

    @ObservedObject private var speechService = SpeechService.shared
    private var bubbleBackground: Color {
        isSource ? AppTheme.primaryVariant : AppTheme.surface
    }
    private var bubbleTextColor: Color {
        isSource ? AppTheme.textOnPrimary : AppTheme.textPrimary
    }
    private var bubbleMetaColor: Color {
        isSource ? AppTheme.textOnPrimary.opacity(0.9) : languageTint
    }
    private var bubbleActionColor: Color {
        isSource ? AppTheme.textOnPrimary.opacity(0.92) : AppTheme.textSecondary
    }
    private var bubbleStrokeColor: Color {
        isSource ? AppTheme.primaryVariant.opacity(0.95) : AppTheme.borderStrong.opacity(0.55)
    }

    private var displayedText: String { text }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if alignTrailing { Spacer(minLength: 0) }
            if !alignTrailing {
                RealtimeTranslationAvatar(tint: languageTint, isSource: isSource)
            }

            VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 10) {
                    if alignTrailing { Spacer(minLength: 0) }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(bubbleMetaColor.opacity(0.8))
                            .frame(width: 6, height: 6)
                        Text(title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(bubbleMetaColor)

                    if let lang = languageForSpeech, !displayedText.isEmpty {
                        HStack(spacing: 12) {
                            Button {
                                if speechService.isPlaying {
                                    speechService.stopSpeaking()
                                } else {
                                    SpeechService.shared.speak(displayedText, language: lang)
                                }
                            } label: {
                                Label("朗读", systemImage: speechService.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onCopy?()
                            } label: {
                                Label("复制", systemImage: "doc.on.doc.fill")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.caption)
                        .foregroundStyle(bubbleActionColor)
                    }

                    if !alignTrailing { Spacer(minLength: 0) }
                }

                Text(displayedText.isEmpty ? placeholder : displayedText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(
                        bubbleTextColor.opacity(displayedText.isEmpty ? 0.86 : 1)
                    )
                    .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
                    .multilineTextAlignment(alignTrailing ? .trailing : .leading)
                    .lineLimit(10)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(bubbleStrokeColor, lineWidth: 1)
            )
            .shadow(color: isSource ? AppTheme.primary.opacity(0.26) : AppTheme.softShadow.opacity(0.6), radius: 8, x: 0, y: 3)
            .frame(maxWidth: 520, alignment: alignTrailing ? .trailing : .leading)

            if !alignTrailing { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
    }
}

private struct RealtimeTranslationAvatar: View {
    let tint: Color
    let isSource: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSource ? AppTheme.primary.opacity(0.14) : tint.opacity(0.22))
                .frame(width: 34, height: 34)
            Image(systemName: isSource ? "mic.fill" : "globe.asia.australia.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSource ? AppTheme.primary : tint.opacity(0.9))
        }
        .padding(.top, 2)
    }
}

struct MicCircleButton: View {
    let isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(AppTheme.unifiedButtonPrimary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 现代化翻译组件

struct ModernTranslationQuickLinkCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct ModernTranslationQuickInfoCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let count: Int
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.surfaceMuted)
                    .frame(width: 42, height: 42)
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.primary)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

/// 左右双输入框布局：两个框大小一致、功能相同，支持双向翻译
struct DualTranslationInputCard: View {
    @ObservedObject var viewModel: TranslateViewModel
    @State private var leftExpanded = false
    @State private var rightExpanded = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：中文输入框（可编辑）；回车或 Cmd+Enter 触发翻译
            TranslationInputBox(
                title: viewModel.sourceLang.name,
                text: $viewModel.sourceText,
                placeholder: "输入或点麦克风说\(viewModel.sourceLang.name)/\(viewModel.targetLang.name)，自动识别并翻译",
                isExpanded: $leftExpanded,
                isListening: viewModel.isListening && viewModel.listeningSide == .left,
                onVoice: { viewModel.toggleListening(side: .left) },
                onPlay: {
                    SpeechService.shared.speak(viewModel.sourceText, language: viewModel.sourceLang.speechCode)
                },
                onCopy: {
                    ClipboardService.copy(viewModel.sourceText)
                },
                onClear: {
                    viewModel.sourceText = ""
                },
                language: viewModel.sourceLang,
                onEnterToTranslate: { viewModel.translate() }
            )
            
            // 右侧：印尼文输入框（可编辑）；回车或 Cmd+Enter 触发翻译
            TranslationInputBox(
                title: viewModel.targetLang.name,
                text: $viewModel.translatedText,
                placeholder: "输入或点麦克风说\(viewModel.targetLang.name)/\(viewModel.sourceLang.name)，自动识别并翻译",
                isExpanded: $rightExpanded,
                isListening: viewModel.isListening && viewModel.listeningSide == .right,
                onVoice: { viewModel.toggleListening(side: .right) },
                onPlay: {
                    SpeechService.shared.speak(viewModel.translatedText, language: viewModel.targetLang.speechCode)
                },
                onCopy: {
                    ClipboardService.copy(viewModel.translatedText)
                },
                onClear: {
                    viewModel.translatedText = ""
                },
                language: viewModel.targetLang,
                onEnterToTranslate: { viewModel.translate() }
            )
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

/// 单个翻译输入框组件（左侧或右侧）- 两个框大小一致、功能相同；回车键触发翻译
struct TranslationInputBox: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Binding var isExpanded: Bool
    let isListening: Bool
    let onVoice: () -> Void
    let onPlay: () -> Void
    let onCopy: () -> Void
    let onClear: () -> Void
    let language: LanguageOption
    /// 回车键或 Cmd+Enter 时调用（翻译）
    var onEnterToTranslate: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏：标题 + 字数统计（上方不再重复放朗读/复制按钮）
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                if !text.isEmpty {
                    Text("\(text.count)/5000")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.bottom, 10)
            
            // 输入框区域（可编辑）- 靠上靠左对齐；回车触发翻译
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .allowsHitTesting(false)
                }
                #if os(macOS)
                TranslationPageTextView(text: $text, onEnterToTranslate: onEnterToTranslate ?? {})
                    .font(.subheadline)
                    .frame(minHeight: 200, maxHeight: isExpanded ? 400 : 200)
                #else
                TextEditor(text: $text)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inputText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 200, maxHeight: isExpanded ? 400 : 200)
                #endif
            }
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: isExpanded ? 400 : 200, alignment: .topLeading)
            
            // 底部操作栏：语音播放/文档 + 录音（清空移动到底部操作条的统一按钮）
            HStack(spacing: 8) {
                UnifiedAppIconButton(systemImage: "speaker.wave.2.fill") {
                    onPlay()
                }
                .disabled(text.isEmpty)
                .opacity(text.isEmpty ? 0.6 : 1)
                .accessibilityLabel("语音播放")
                
                UnifiedAppIconButton(systemImage: "doc.on.doc.fill") {
                    onCopy()
                }
                .disabled(text.isEmpty)
                .opacity(text.isEmpty ? 0.6 : 1)
                .accessibilityLabel("复制")
                
                Spacer(minLength: 0)

                UnifiedAppIconButton(systemImage: isListening ? "stop.fill" : "mic.fill", isPrimary: isListening) {
                    onVoice()
                }
                .accessibilityLabel(isListening ? "停止录音" : "语音输入")
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
    }
}

#if os(macOS)
/// 翻译页多行输入框（macOS）：回车触发翻译，Shift+回车换行
struct TranslationPageTextView: NSViewRepresentable {
    @Binding var text: String
    var onEnterToTranslate: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = TranslationPageNSTextView()
        textView.string = text
        textView.onEnterToTranslate = onEnterToTranslate
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        textView.textColor = NSColor.labelColor
        textView.minSize = NSSize(width: 0, height: 200)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TranslationPageNSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.onEnterToTranslate = onEnterToTranslate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationPageTextView
        init(_ parent: TranslationPageTextView) {
            self.parent = parent
        }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// 自定义 NSTextView：回车触发翻译，Shift+回车换行
class TranslationPageNSTextView: NSTextView {
    var onEnterToTranslate: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n"
        if isReturn {
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                onEnterToTranslate?()
            }
        } else {
            super.keyDown(with: event)
        }
    }
}
#endif

// 保留原组件以兼容
struct ModernTranslationInputCard: View {
    @ObservedObject var viewModel: TranslateViewModel
    @State private var isExpanded = false
    
    var body: some View {
        DualTranslationInputCard(viewModel: viewModel)
    }
}

struct ModernTranslationActionBar: View {
    @ObservedObject var viewModel: TranslateViewModel
    private let barHeight: CGFloat = 44
    
    private var canTranslate: Bool {
        let leftHasText = !viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rightHasText = !viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return leftHasText || rightHasText
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.swapLanguages() }) {
                HStack(spacing: 6) {
                    Text(viewModel.sourceLang.name)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption.weight(.semibold))
                    Text(viewModel.targetLang.name)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppTheme.textPrimary)
                .frame(height: barHeight)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.unifiedButtonBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)

            // 清空内容按钮：清空左右两个输入框
            Button(action: {
                viewModel.sourceText = ""
                viewModel.translatedText = ""
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                        .font(.subheadline)
                    Text("清空内容")
                        .font(.subheadline)
                }
                .foregroundStyle(AppTheme.textSecondary)
                .frame(height: barHeight)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canTranslate)

            // 翻译按钮（支持 Cmd+Enter 快捷键）
            Button(action: { viewModel.translate() }) {
                HStack(spacing: 6) {
                    if viewModel.isTranslating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.subheadline)
                        Text("翻译")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(height: barHeight)
                .padding(.horizontal, 20)
                .background(canTranslate ? AppTheme.unifiedButtonPrimary : AppTheme.unifiedButtonPrimary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canTranslate)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

struct ModernTranslationResultCard: View {
    @ObservedObject var viewModel: TranslateViewModel
    @State private var isExpanded = false
    
    var body: some View {
        if !viewModel.translatedText.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("翻译结果")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Button { viewModel.playResult() } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.primary)
                        }
                        Button {
                            ClipboardService.copy(viewModel.translatedText)
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
                Text(viewModel.translatedText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(4)
                    .lineLimit(isExpanded ? nil : 5)
                    .onTapGesture { isExpanded.toggle() }
                if viewModel.translatedText.count > 180 {
                    Button(isExpanded ? "收起" : "展开全文") { isExpanded.toggle() }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .padding(12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
            .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - 全部翻译记录页（支持语音播放与复制）
struct AllTranslationRecordsView: View {
    let history: [TranslationEntry]
    
    var body: some View {
        Group {
            if history.isEmpty {
                ModernEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "暂无翻译记录",
                    subtitle: "您的翻译记录将显示在这里"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(history) { item in
                            TranslationRecordRowWithActions(item: item)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("翻译记录")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct TranslationRecordRowWithActions: View {
    let item: TranslationEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text(item.sourceLang.name)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textOnPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.primary)
                        .clipShape(Capsule())
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(item.targetLang.name)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textOnPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.secondary)
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        SpeechService.shared.speak(item.sourceText, language: item.sourceLang.speechCode)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.primary)
                    }
                    Button {
                        SpeechService.shared.speak(item.targetText, language: item.targetLang.speechCode)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accentWarm)
                    }
                    Button {
                        ClipboardService.copy("\(item.sourceText)\n\n\(item.targetText)")
                    } label: {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.sourceText)
                    .font(.callout)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(isExpanded ? nil : 2)
                Text(item.targetText)
                    .font(.callout)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(isExpanded ? nil : 2)
            }
            if item.sourceText.count > 80 || item.targetText.count > 80 {
                Button {
                    isExpanded.toggle()
                } label: {
                    Text(isExpanded ? "收起" : "展开")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.softShadow, radius: 4, x: 0, y: 2)
    }
}

struct ModernTranslationHistorySection: View {
    let history: [TranslationEntry]
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("翻译记录")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Text("最近 10 条")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            let displayedHistory = Array(history.prefix(10))
            
            LazyVStack(spacing: 8) {
                ForEach(displayedHistory) { item in
                    ModernTranslationHistoryItem(item: item)
                }
            }
            
            if displayedHistory.isEmpty {
                ModernEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "暂无翻译记录",
                    subtitle: "点击上方的翻译记录可查看全部，支持语音播放和复制"
                )
                .padding(.vertical, 20)
            }
        }
    }
}

struct ModernTranslationHistoryItem: View {
    let item: TranslationEntry
    @State private var isExpanded = false
    
    var body: some View {
        ModernCard(style: .outlined) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text(item.sourceLang.name)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.textOnPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                        
                        Text(item.targetLang.name)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.textOnPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.secondary)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button {
                            SpeechService.shared.speak(item.sourceText, language: item.sourceLang.speechCode)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.primary)
                        }
                        Button {
                            SpeechService.shared.speak(item.targetText, language: item.targetLang.speechCode)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.accentWarm)
                        }
                        Button {
                            ClipboardService.copy("\(item.sourceText)\n\n\(item.targetText)")
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    
                    Text(formatDate(item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(item.sourceText)
                        .font(.callout)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    Text(item.targetText)
                        .font(.callout)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                if item.sourceText.count > 100 || item.targetText.count > 100 {
                    Text(isExpanded ? "收起" : "展开")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.primary)
                        .onTapGesture {
                            isExpanded.toggle()
                        }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
