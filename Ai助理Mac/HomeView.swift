import SwiftUI

/// 首页视图 - 完全按照参考图设计
struct HomeView: View {
    @State private var inputText = ""
    @State private var isListening = false
    @State private var showQuickActions = false
    @StateObject private var viewModel = ChatViewModel()
    
    private let quickActions: [(title: String, icon: String, prompt: String)] = [
        ("垃圾清理", "trash.fill", "帮我清理系统垃圾文件"),
        ("电脑加速", "bolt.fill", "优化电脑运行速度"),
        ("录音总结", "mic.fill", "整理录音内容要点"),
        ("AI PPT", "rectangle.stack.fill", "帮我制作一个PPT"),
        ("AI写作", "pencil.line", "帮我写一篇文章"),
        ("更多", "chevron.down", "")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏：左侧时钟+新对话，右侧用户+反馈
            HomeTopBar()
            
            // 主内容区
            VStack(spacing: 0) {
                Spacer()
                
                // AI头像和问候
                VStack(spacing: 24) {
                    // AI头像（浅蓝色头发动漫风格，有绿色在线状态点）
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.92, blue: 0.98),
                                        Color(red: 0.9, green: 0.94, blue: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                        
                        Image(systemName: "face.smiling.fill")
                            .font(.system(size: 55))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.5, green: 0.7, blue: 0.95),
                                        Color(red: 0.6, green: 0.75, blue: 0.98)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // 绿色在线状态点
                        Circle()
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.3))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: 40, y: -40)
                    }
                    
                    // 问候语和副标题
                    VStack(spacing: 10) {
                        Text("Hi,有什么需要我帮忙的吗~")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                        
                        Text("电脑异常修复、畅聊陪伴、办公学习样样精通~")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                    }
                }
                
                Spacer()
                
                // 快捷功能（点击加号时在输入框上方一排显示）
                VStack(spacing: 12) {
                    if showQuickActions {
                        HomeQuickActionRow(items: quickActions) { prompt in
                            if !prompt.isEmpty {
                                viewModel.inputText = prompt
                                viewModel.sendMessage()
                            }
                            showQuickActions = false
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // 输入框：回形针、输入、剪刀、麦克风、发送、加号
                    HomeInputField(
                        text: $inputText,
                        isListening: isListening,
                        onAttach: {},
                        onScissors: {},
                        onVoice: { isListening.toggle() },
                        onSend: {
                            if !inputText.isEmpty {
                                viewModel.inputText = inputText
                                viewModel.sendMessage()
                                inputText = ""
                            }
                        },
                        onPlus: { showQuickActions.toggle() }
                    )
                    .padding(.horizontal, 24)
                }
                .animation(.easeInOut(duration: 0.2), value: showQuickActions)
                
                VStack(spacing: 0) {
                    // 底部免责声明
                    Text("AI全能助理生成内容可能存在误差,请核查重要信息。")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.6, green: 0.6, blue: 0.6))
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
        }
        .background(Color.white)
    }
}

/// 顶部栏：左侧时钟+新对话，右侧用户+反馈
struct HomeTopBar: View {
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：时钟、新对话
            Button(action: {}) {
                Image(systemName: "clock")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.unifiedButtonBorder)
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("历史记录")
            
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.unifiedButtonBorder)
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新对话")
            
            Spacer()
            
            // 右侧：用户头像、反馈
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.unifiedButtonBorder)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("用户")
            
            Button(action: {}) {
                Text("反馈")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.unifiedButtonBorder)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("反馈")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

/// 首页输入框：大圆角矩形，左侧回形针，中间输入，右侧剪刀、麦克风、发送、加号
struct HomeInputField: View {
    @Binding var text: String
    let isListening: Bool
    let onAttach: () -> Void
    let onScissors: () -> Void
    let onVoice: () -> Void
    let onSend: () -> Void
    var onPlus: () -> Void = {}
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左侧回形针（上下居中）
            Button(action: onAttach) {
                Image(systemName: "paperclip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.unifiedButtonBorder)
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .accessibilityLabel("附件")
            
            // 直接使用整块区域输入，无内嵌小框
            TextField("输入您的问题,或告诉我要做什么...", text: $text, axis: .vertical)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .onSubmit { onSend() }
            
            // 右侧：剪刀、麦克风、发送、加号（上下居中）
            HStack(spacing: 10) {
                Button(action: onScissors) {
                    Image(systemName: "scissors")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.unifiedButtonBorder)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("剪切")
                
                Button(action: onVoice) {
                    Image(systemName: isListening ? "waveform.circle.fill" : "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isListening ? .white : AppTheme.unifiedButtonBorder)
                        .frame(width: 32, height: 32)
                        .background(isListening ? AppTheme.unifiedButtonPrimary : Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: isListening ? 0 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isListening ? "正在听" : "语音输入")
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(canSend ? .white : AppTheme.unifiedButtonBorder)
                        .frame(width: 32, height: 32)
                        .background(canSend ? AppTheme.unifiedButtonPrimary : Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: canSend ? 0 : 1))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("发送")
                
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.unifiedButtonBorder)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("更多功能")
            }
            .padding(.trailing, 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.unifiedButtonBorder.opacity(0.3), lineWidth: 1)
        )
    }
}

/// 首页快捷操作按钮行
struct HomeQuickActionRow: View {
    let items: [(title: String, icon: String, prompt: String)]
    let onTap: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    Button {
                        onTap(item.prompt)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.unifiedButtonBorder)
                                .frame(width: 18, height: 18)
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.unifiedButtonBorder)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.unifiedButtonBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 52)
    }
}
