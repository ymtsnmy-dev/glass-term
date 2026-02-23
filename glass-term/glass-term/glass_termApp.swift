import SwiftUI

@main
struct glass_termApp: App {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            TabbedTerminalRootView(sessionManager: sessionManager)
                .environmentObject(themeManager)
        }
        .commands {
            CommandMenu("Copy Stack") {
                Button("Toggle Copy Stack") {
                    NotificationCenter.default.post(
                        name: .toggleCopyStackDrawer,
                        object: nil,
                        userInfo: ["sessionID": sessionManager.activeSessionID]
                    )
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(sessionManager.activeDisplayMode == .rawMode)
            }

            CommandMenu("Theme") {
                Button("Use Default Theme") {
                    themeManager.setDefaultTheme()
                }

                Button("Use Glass Theme") {
                    themeManager.setGlassTheme()
                }

                Divider()

                Button("Toggle Theme") {
                    themeManager.toggleTheme()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}
