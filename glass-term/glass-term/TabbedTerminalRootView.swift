import SwiftUI

struct TabbedTerminalRootView: View {
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            rootBackground

            if themeManager.activeTheme.isGlass {
                FrostedBackgroundLayer()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                TabBarView(
                    items: sessionManager.sessions.map { session in
                        TabBarView.Item(
                            id: session.id,
                            title: tabPrimaryTitle(for: session),
                            subtitle: tabSubtitle(for: session),
                            state: tabState(for: session),
                            isActive: session.id == sessionManager.activeSessionID,
                        )
                    },
                    onSelect: { sessionManager.activateSession(id: $0) },
                    onClose: { sessionManager.closeSession(id: $0) },
                    onAdd: { _ = sessionManager.createSession() }
                )

                if themeManager.activeTheme.isGlass {
                    Color.clear
                        .frame(height: 4)
                } else {
                    Divider()
                }

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

    private func tabState(for session: TerminalSession) -> TabBarView.Item.SessionState {
        if session.isTerminated {
            return .exited
        }
        if session.id == sessionManager.activeSessionID {
            return .running
        }
        return .idle
    }

    private func tabPrimaryTitle(for session: TerminalSession) -> String {
        let windowTitle = session.controller.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !windowTitle.isEmpty, windowTitle != "glass-term" else {
            return "zsh"
        }

        let tokens = windowTitle.split(separator: " ").map(String.init)
        if let first = tokens.first, !looksLikePathToken(first) {
            return first
        }

        return "zsh"
    }

    private func tabSubtitle(for session: TerminalSession) -> String? {
        let windowTitle = session.controller.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if let pathToken = windowTitle
            .split(separator: " ")
            .map(String.init)
            .reversed()
            .first(where: looksLikePathToken) {
            return condensedPathTail(from: pathToken)
        }

        if let sessionNumber = session.title.split(separator: " ").last, session.title.hasPrefix("Tab ") {
            return "session \(sessionNumber)"
        }

        return nil
    }

    private func looksLikePathToken(_ token: String) -> Bool {
        token.contains("/") || token == "~" || token.hasPrefix("~/")
    }

    private func condensedPathTail(from token: String) -> String {
        let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: "[](){}<>:,;"))
        if cleaned == "~" { return "~" }
        if cleaned.hasPrefix("~/") {
            let tail = String(cleaned.dropFirst(2)).split(separator: "/").last.map(String.init) ?? ""
            return tail.isEmpty ? "~" : "~/" + tail
        }
        let tail = cleaned.split(separator: "/").last.map(String.init) ?? cleaned
        return tail.isEmpty ? cleaned : tail
    }
}

private struct FrostedBackgroundLayer: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            GlassTokens.Background.overlayTint

            LinearGradient(
                colors: [
                    GlassTokens.Background.topGlow,
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )

            LiquidGlassNoiseOverlay(opacity: GlassTokens.Background.noiseOpacity)
                .blendMode(.screen)
        }
    }
}

private struct LiquidGlassNoiseOverlay: View {
    let opacity: Double

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let step: CGFloat = 10
            let columns = max(1, Int(size.width / step) + 2)
            let rows = max(1, Int(size.height / step) + 2)

            for y in 0..<rows {
                for x in 0..<columns {
                    let seed = noiseHash(x: x, y: y)
                    guard seed > 0.78 else { continue }

                    let jitterX = (noiseHash(x: x + 911, y: y + 173) - 0.5) * 3.0
                    let jitterY = (noiseHash(x: x + 431, y: y + 661) - 0.5) * 3.0
                    let alpha = ((seed - 0.78) / 0.22) * opacity

                    let rect = CGRect(
                        x: CGFloat(x) * step + jitterX,
                        y: CGFloat(y) * step + jitterY,
                        width: 1.2,
                        height: 1.2
                    )

                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
        }
        .opacity(1.0)
    }

    private func noiseHash(x: Int, y: Int) -> Double {
        var n = UInt64(bitPattern: Int64(x &* 73856093 ^ y &* 19349663))
        n ^= (n << 13)
        n ^= (n >> 7)
        n ^= (n << 17)
        return Double(n & 0xFFFF) / Double(0xFFFF)
    }
}
