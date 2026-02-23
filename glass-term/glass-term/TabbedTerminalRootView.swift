import SwiftUI

struct TabbedTerminalRootView: View {
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            rootBackground

            VStack(spacing: 0) {
                TabBarView(
                    items: sessionManager.sessions.map { session in
                        TabBarView.Item(
                            id: session.id,
                            title: session.title,
                            isActive: session.id == sessionManager.activeSessionID,
                            isTerminated: session.isTerminated
                        )
                    },
                    onSelect: { sessionManager.activateSession(id: $0) },
                    onClose: { sessionManager.closeSession(id: $0) },
                    onAdd: { _ = sessionManager.createSession() }
                )

                Divider()

                if let activeSession = sessionManager.activeSession {
                    ContentView(sessionID: activeSession.id, session: activeSession.controller)
                        .id(activeSession.id)
                }
            }
        }
    }

    @ViewBuilder
    private var rootBackground: some View {
        switch themeManager.activeTheme.backgroundStyle {
        case .solid:
            themeManager.activeTheme.terminalBackgroundColor
                .ignoresSafeArea()
        case .glass:
            GlassBackgroundView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
