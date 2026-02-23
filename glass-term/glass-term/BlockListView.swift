import SwiftUI

struct BlockListView: View {
    @ObservedObject var session: TerminalSessionController
    let scrollToBottomTrigger: UInt64
    let onCopyBlock: (Block) -> Void
    @State private var bottomAnchorID = UUID()

    init(
        session: TerminalSessionController,
        scrollToBottomTrigger: UInt64 = 0,
        onCopyBlock: @escaping (Block) -> Void = { _ in }
    ) {
        self.session = session
        self.scrollToBottomTrigger = scrollToBottomTrigger
        self.onCopyBlock = onCopyBlock
    }

    var body: some View {
        if session.displayMode == .rawMode {
            EmptyView()
        } else {
            if session.blocks.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    Label("Ready", systemImage: "terminal")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Ready")
                        .help("Ready")
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(session.blocks.enumerated()), id: \.element.id) { entry in
                                BlockCardView(
                                    block: entry.element,
                                    isLatest: entry.offset == session.blocks.count - 1
                                ) {
                                    onCopyBlock(entry.element)
                                }
                            }
                            Color.clear
                                .frame(height: 1)
                                .id(bottomAnchorID)
                        }
                        .padding(.vertical, 14)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: scrollToBottomTrigger) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: session.blocks.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            let action = {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }

            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    action()
                }
            } else {
                action()
            }
        }
    }
}
