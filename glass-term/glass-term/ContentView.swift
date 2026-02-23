import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var session: TerminalSessionController
    @State private var hostWindow: NSWindow?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if session.displayMode == .rawMode {
                TerminalView(session: session)
            } else {
                VStack(spacing: 0) {
                    BlockListView(session: session)

                    Divider()

                    InputBarView { command in
                        session.sendInput(command + "\n")
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
    }
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
