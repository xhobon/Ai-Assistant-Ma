import SwiftUI

enum MainTab: Int, CaseIterable {
    case assistant
    case translate
    case learning
    case settings

    var title: String {
        switch self {
        case .assistant: return "首页"
        case .translate: return "翻译"
        case .learning: return "学习"
        case .settings: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .assistant: return "brain.head.profile"
        case .translate: return "character.bubble"
        case .learning: return "book.fill"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .assistant
    @ObservedObject private var appearance = AppearanceStore.shared
    @State private var copyToastMessage: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            tabRoot(.assistant)
                .tabItem { Label(MainTab.assistant.title, systemImage: MainTab.assistant.icon) }
                .tag(MainTab.assistant)

            tabRoot(.translate)
                .tabItem { Label(MainTab.translate.title, systemImage: MainTab.translate.icon) }
                .tag(MainTab.translate)

            tabRoot(.learning)
                .tabItem { Label(MainTab.learning.title, systemImage: MainTab.learning.icon) }
                .tag(MainTab.learning)

            tabRoot(.settings)
                .tabItem { Label(MainTab.settings.title, systemImage: MainTab.settings.icon) }
                .tag(MainTab.settings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .onChange(of: selectedTab) { _, _ in
            SpeechService.shared.stopSpeaking()
        }
        .preferredColorScheme(appearance.colorScheme)
        .toast(message: $copyToastMessage)
        .onReceive(NotificationCenter.default.publisher(for: .globalCopySucceeded)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                copyToastMessage = "已复制到剪贴板"
            }
        }
    }

    @ViewBuilder
    private func page(for tab: MainTab) -> some View {
        switch tab {
        case .assistant:
            AIAssistantDesignedHomeView()
        case .translate:
            AITranslateHomeView()
        case .learning:
            IndonesianLearningView()
        case .settings:
            MyDesignedView()
        }
    }

    private func tabRoot(_ tab: MainTab) -> some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                page(for: tab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    ContentView()
}
