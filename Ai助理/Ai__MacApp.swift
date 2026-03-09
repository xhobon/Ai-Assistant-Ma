//
//  Ai__MacApp.swift
//  Ai助理Mac
//
//  Created by Akun on 2026/2/22.
//

import SwiftUI
import SwiftData

#if os(macOS)
@main
struct Ai__MacApp: App {
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
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .modelContainer(sharedModelContainer)
    }
}
#endif
