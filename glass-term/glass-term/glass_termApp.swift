import SwiftUI

@main
struct glass_termApp: App {
    @StateObject private var session = TerminalSessionController()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
    }
}
