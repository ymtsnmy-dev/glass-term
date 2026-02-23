import SwiftUI

struct BlockListView: View {
    @ObservedObject var session: TerminalSessionController
    let onCopyBlock: (Block) -> Void

    init(
        session: TerminalSessionController,
        onCopyBlock: @escaping (Block) -> Void = { _ in }
    ) {
        self.session = session
        self.onCopyBlock = onCopyBlock
    }

    var body: some View {
        if session.displayMode == .rawMode {
            EmptyView()
        } else {
            if session.blocks.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    Text("Ready")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(session.blocks, id: \.id) { block in
                            BlockCardView(block: block) {
                                onCopyBlock(block)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}
