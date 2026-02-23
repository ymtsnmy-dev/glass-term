import SwiftUI

struct TabbedTerminalRootView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
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
                ContentView(session: activeSession.controller)
                    .id(activeSession.id)
            }
        }
        .background(Color.black)
    }
}
