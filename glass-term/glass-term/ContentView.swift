import AppKit
import SwiftUI

struct ContentView: View {
    private let sessionID: UUID
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var session: TerminalSessionController
    @ObservedObject private var copyQueueManager: CopyQueueManager
    @State private var hostWindow: NSWindow?
    @State private var isCopyDrawerPresented = false
    @State private var blockListScrollTrigger: UInt64 = 0

    init(sessionID: UUID, session: TerminalSessionController) {
        self.sessionID = sessionID
        self.session = session
        _copyQueueManager = ObservedObject(wrappedValue: session.copyQueueManager)
    }

    var body: some View {
        ZStack {
            contentBackground

            if session.displayMode == .rawMode {
                rawModeContent
            } else {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            BlockListView(
                                session: session,
                                scrollToBottomTrigger: blockListScrollTrigger
                            ) { block in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                                    session.copyQueueManager.append(block: block)
                                    isCopyDrawerPresented = true
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)

                            if isCopyDrawerVisible {
                                CopyStackDrawer(manager: copyQueueManager) {
                                    closeCopyDrawer()
                                }
                                .frame(width: copyDrawerWidth(containerWidth: geometry.size.width))
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }

                        Divider()

                        InputBarView(
                            onFocusCommandField: requestBlockListScrollToBottom
                        ) { command in
                            requestBlockListScrollToBottom()
                            session.sendInput(command + "\n")
                        }
                    }
                }
            }
        }
        .background(
            WindowReader { window in
                hostWindow = window
                if let window {
                    window.title = session.windowTitle
                }
            }
        )
        .onChange(of: session.windowTitle) { _, newTitle in
            hostWindow?.title = newTitle
        }
        .onChange(of: session.bellSequence) { _, _ in
            NSSound.beep()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleCopyStackDrawer)) { notification in
            guard let incomingSessionID = notification.userInfo?["sessionID"] as? UUID else {
                return
            }
            guard incomingSessionID == sessionID else { return }
            toggleCopyDrawer()
        }
        .onChange(of: copyQueueManager.items.isEmpty) { _, isEmpty in
            guard isEmpty else { return }
            closeCopyDrawer()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: copyQueueManager.items.count)
    }

    @ViewBuilder
    private var rawModeContent: some View {
        if themeManager.activeTheme.isGlass {
            GlassPanel(
                cornerRadius: GlassTokens.RawTerminal.cornerRadius,
                token: GlassTokens.RawTerminal.containerPanel
            ) {
                TerminalView(
                    session: session,
                    textColor: GlassTokens.RawTerminal.terminalText,
                    backgroundColor: GlassTokens.RawTerminal.terminalBackground,
                    cursorColor: GlassTokens.RawTerminal.terminalCursor
                )
                .clipShape(RoundedRectangle(cornerRadius: GlassTokens.RawTerminal.cornerRadius, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        } else {
            TerminalView(session: session)
        }
    }

    @ViewBuilder
    private var contentBackground: some View {
        switch themeManager.activeTheme.backgroundStyle {
        case .solid:
            themeManager.activeTheme.terminalBackgroundColor
                .ignoresSafeArea()
        case .glass:
            Color.clear
                .ignoresSafeArea()
        }
    }

    private var isCopyDrawerVisible: Bool {
        isCopyDrawerPresented && !copyQueueManager.items.isEmpty
    }

    private func copyDrawerWidth(containerWidth: CGFloat) -> CGFloat {
        min(380, max(280, containerWidth * 0.28))
    }

    private func closeCopyDrawer() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
            isCopyDrawerPresented = false
        }
    }

    private func toggleCopyDrawer() {
        guard session.displayMode != .rawMode else { return }
        guard !copyQueueManager.items.isEmpty else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
            isCopyDrawerPresented.toggle()
        }
    }

    private func requestBlockListScrollToBottom() {
        guard session.displayMode == .blockMode else { return }
        blockListScrollTrigger &+= 1
    }
}

extension Notification.Name {
    static let toggleCopyStackDrawer = Notification.Name("ToggleCopyStackDrawer")
}

private struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}
