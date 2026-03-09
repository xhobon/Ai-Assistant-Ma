//
//  Ai__App.swift
//  Ai助理
//
//  Created by Akun on 20/02/26.
//

import SwiftUI
import SwiftData

// iOS 主入口（保留原有页面布局与功能）
#if os(iOS)
@main
#endif
struct Ai__App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
