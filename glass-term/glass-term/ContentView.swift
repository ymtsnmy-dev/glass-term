import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var session: TerminalSessionController
    @ObservedObject private var copyQueueManager: CopyQueueManager
    @State private var hostWindow: NSWindow?
    @State private var isCopyDrawerPresented = false

    init(session: TerminalSessionController) {
        self.session = session
        _copyQueueManager = ObservedObject(wrappedValue: session.copyQueueManager)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if session.displayMode == .rawMode {
                TerminalView(session: session)
            } else {
                VStack(spacing: 0) {
                    BlockListView(session: session) { block in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                            session.copyQueueManager.append(block: block)
                            isCopyDrawerPresented = true
                        }
                    }

                    Divider()

                    InputBarView { command in
                        session.sendInput(command + "\n")
                    }
                }
            }
        }
        .overlay(alignment: .trailing) {
            copyStackOverlay
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleCopyStackDrawer)) { _ in
            toggleCopyDrawer()
        }
        .onChange(of: copyQueueManager.items.isEmpty) { _, isEmpty in
            guard isEmpty else { return }
            closeCopyDrawer()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: copyQueueManager.items.count)
    }

    @ViewBuilder
    private var copyStackOverlay: some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .allowsHitTesting(false)

            if isCopyDrawerPresented && !copyQueueManager.items.isEmpty {
                CopyStackDrawer(manager: copyQueueManager) {
                    closeCopyDrawer()
                }
                    .padding(.vertical, 12)
                    .padding(.trailing, 12)
                    .allowsHitTesting(true)
            }
        }
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
