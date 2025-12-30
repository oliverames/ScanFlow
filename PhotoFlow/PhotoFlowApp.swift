//
//  PhotoFlowApp.swift
//  PhotoFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

@main
struct PhotoFlowApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            MainWindow()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .newItem) {
                Button("Start Scan") {
                    // Trigger scan
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
        #else
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        #endif
    }
}
