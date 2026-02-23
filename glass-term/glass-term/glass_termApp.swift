import SwiftUI

@main
struct glass_termApp: App {
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            TabbedTerminalRootView(sessionManager: sessionManager)
        }
        .commands {
            CommandMenu("Copy Stack") {
                Button("Toggle Copy Stack") {
                    NotificationCenter.default.post(name: .toggleCopyStackDrawer, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(sessionManager.activeDisplayMode == .rawMode)
            }
        }
    }
}
