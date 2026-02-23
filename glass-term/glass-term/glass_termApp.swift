import SwiftUI

@main
struct glass_termApp: App {
    @StateObject private var session = TerminalSessionController()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
        .commands {
            CommandMenu("Copy Stack") {
                Button("Toggle Copy Stack") {
                    NotificationCenter.default.post(name: .toggleCopyStackDrawer, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(session.displayMode == .rawMode)
            }
        }
    }
}
