//
//  LottiePackApp.swift
//  LottiePack
//
//  Created by Emily Huang on 2026/3/20.
//

import SwiftUI

@main
/// 应用入口：启动后加载主工作区页面。
struct LottiePackApp: App {
    @StateObject private var preferences = AppPreferences.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferences)
        }

        Settings {
            SettingsView()
                .environmentObject(preferences)
        }
        .commands {
            CommandMenu(L10n.tr("language.menu")) {
                ForEach(AppLanguage.allCases) { language in
                    Button(language.displayName) {
                        preferences.language = language
                    }
                }
            }
        }
    }
}
