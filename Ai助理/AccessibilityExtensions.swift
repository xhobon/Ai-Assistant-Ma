import SwiftUI

// MARK: - 触觉反馈类型枚举
enum HapticFeedbackType {
    case light, medium, heavy, success, error, warning, selection
}

// MARK: - 用户体验增强扩展
extension View {
    // 智能toast
    func smartToast(
        _ message: String,
        type: SmartToast.ToastType,
        duration: TimeInterval = 3.0,
        isPresented: Binding<Bool>
    ) -> some View {
        self.overlay(
            SmartToast(message, type: type, duration: duration, isPresented: isPresented)
        )
    }
    
    // 无障碍增强
    func accessibleButton(
        title: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        AccessibleButton(title, hint: hint, action: action)
    }
    
    // 智能动画
    func smartAppear(isVisible: Bool) -> some View {
        PageTransition(isVisible: isVisible) {
            self
        }
    }
    
    // 触觉反馈
    func addHaptic(_ type: HapticFeedbackType) -> some View {
        self.onTapGesture {
            switch type {
            case .light: HapticFeedback.light()
            case .medium: HapticFeedback.medium()
            case .heavy: HapticFeedback.heavy()
            case .success: HapticFeedback.success()
            case .error: HapticFeedback.error()
            case .warning: HapticFeedback.warning()
            case .selection: HapticFeedback.selectionChanged()
            }
        }
    }
    
}