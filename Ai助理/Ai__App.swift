//
//  Ai__App.swift
//  Ai助理
//
//  Created by Akun on 20/02/26.
//

import SwiftUI
import UserNotifications

// iOS 主入口（保留原有页面布局与功能）
@main
struct Ai__App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var languageStore = AppLanguageStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.locale)
                .id(languageStore.current.rawValue)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        ReminderService.shared.registerCategories()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let noteId = userInfo["noteId"] as? String {
            ReminderService.shared.handleAction(noteId: noteId, actionId: response.actionIdentifier)
        }
    }
}
