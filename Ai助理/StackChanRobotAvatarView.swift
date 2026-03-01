import SwiftUI

struct StackChanRobotAvatarView: View {
    let emotion: StackChanEmotion
    let blink: Bool
    let mouthOpen: Bool
    let gazeX: CGFloat
    let isListening: Bool
    let isSpeaking: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let bob = CGFloat(sin(t * 1.6)) * 4.0
            let tilt = Angle(degrees: sin(t * 1.2) * 2.1)
            let earWiggle = Angle(degrees: sin(t * 2.2) * 3.8)

            ZStack {
                RadialGradient(
                    colors: [
                        Color.cyan.opacity(0.42),
                        Color.cyan.opacity(0.18),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 24,
                    endRadius: 180
                )
                .blur(radius: 12)

                head(earWiggle: earWiggle)
                    .rotationEffect(tilt)
                    .offset(y: bob)
                    .shadow(color: Color.cyan.opacity(0.28), radius: 20, x: 0, y: 10)
            }
            .padding(.horizontal, 4)
        }
    }

    private func head(earWiggle: Angle) -> some View {
        ZStack {
            topEars(earWiggle: earWiggle)
                .offset(y: -70)

            HStack(spacing: 178) {
                sidePad
                sidePad
            }
            .offset(y: -2)

            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 0.91, green: 0.98, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 238, height: 176)
                .overlay(
                    RoundedRectangle(cornerRadius: 52, style: .continuous)
                        .stroke(Color.cyan.opacity(0.36), lineWidth: 1.4)
                )

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.00, green: 0.10, blue: 0.28),
                            Color(red: 0.01, green: 0.22, blue: 0.48),
                            Color(red: 0.00, green: 0.34, blue: 0.64)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 192, height: 136)
                .overlay(faceGrid.opacity(0.18))
                .overlay(faceLayer)
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(Color.cyan.opacity(0.28), lineWidth: 1.0)
                )
        }
    }

    private var sidePad: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white,
                        Color(red: 1.0, green: 0.88, blue: 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 28, height: 50)
            .overlay(
                Capsule()
                    .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
            )
    }

    private func topEars(earWiggle: Angle) -> some View {
        HStack(spacing: 16) {
            Capsule()
                .fill(LinearGradient(colors: [Color.white, Color.cyan.opacity(0.42)], startPoint: .top, endPoint: .bottom))
                .frame(width: 20, height: 54)
                .rotationEffect(.degrees(-20) + earWiggle)
            Capsule()
                .fill(LinearGradient(colors: [Color.white, Color.cyan.opacity(0.42)], startPoint: .top, endPoint: .bottom))
                .frame(width: 20, height: 42)
                .rotationEffect(.degrees(20) - earWiggle)
        }
    }

    private var faceLayer: some View {
        ZStack {
            HStack(spacing: 64) {
                eyebrow
                eyebrow
            }
            .offset(y: -32)

            HStack(spacing: 52) {
                eye
                eye
            }
            .offset(x: gazeX * 0.6, y: -4)

            Circle()
                .fill(faceAccent)
                .frame(width: mouthSize, height: mouthSize)
                .offset(y: 28)
                .scaleEffect(isSpeaking || mouthOpen ? 1.2 : 1.0)
        }
    }

    private var mouthSize: CGFloat {
        if isSpeaking || mouthOpen { return 18 }
        return emotion == .sad ? 10 : 13
    }

    private var eyebrow: some View {
        Capsule()
            .fill(faceAccent.opacity(0.92))
            .frame(width: 30, height: 10)
            .rotationEffect(eyebrowAngle)
    }

    private var eyebrowAngle: Angle {
        switch emotion {
        case .angry: return .degrees(-16)
        case .sad: return .degrees(16)
        default: return .degrees(10)
        }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(faceAccent)
            .frame(width: 30, height: eyeHeight)
    }

    private var eyeHeight: CGFloat {
        if blink { return 5 }
        switch emotion {
        case .sad: return 18
        case .thinking: return 24
        default: return 44
        }
    }

    private var faceAccent: Color {
        switch emotion {
        case .angry: return Color(red: 1.0, green: 0.69, blue: 0.26)
        case .sad: return Color(red: 0.62, green: 0.86, blue: 1.0)
        case .listening: return Color(red: 0.47, green: 1.0, blue: 0.84)
        default: return Color(red: 0.50, green: 0.99, blue: 1.0)
        }
    }

    private var faceGrid: some View {
        GeometryReader { geo in
            Path { path in
                let spacing: CGFloat = 18
                stride(from: 0, through: geo.size.width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                stride(from: 0, through: geo.size.height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.cyan.opacity(0.56), lineWidth: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
    }
}

struct StackChanRobotHeadBadgeView: View {
    let emotion: StackChanEmotion
    let blink: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.white, Color.cyan.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.00, green: 0.15, blue: 0.39), Color(red: 0.00, green: 0.31, blue: 0.66)], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 34)
                .overlay(
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.cyan.opacity(0.95))
                            .frame(width: 6, height: blink ? 2 : 10)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.cyan.opacity(0.95))
                            .frame(width: 6, height: blink ? 2 : 10)
                    }
                )
                .overlay(
                    Circle()
                        .fill(emotion == .angry ? Color.orange : Color.cyan)
                        .frame(width: 5, height: 5)
                        .offset(y: 10)
                )

            VStack {
                Capsule()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: 9, height: 16)
                    .rotationEffect(.degrees(-15))
                Spacer()
            }
            .frame(height: 56)
            .offset(y: -17)
        }
    }
}
