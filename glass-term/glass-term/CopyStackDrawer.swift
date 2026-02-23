import SwiftUI

struct CopyStackDrawer: View {
    @ObservedObject var manager: CopyQueueManager
    let onClose: () -> Void

    init(manager: CopyQueueManager, onClose: @escaping () -> Void = {}) {
        self.manager = manager
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(manager.items.enumerated()), id: \.element.id) { entry in
                        itemCard(entry.element, index: entry.offset)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 16, x: -6, y: 0)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Copy Stack")
                    .font(.headline)
                Spacer(minLength: 0)
                Text("\(manager.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Close") {
                    onClose()
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape, modifiers: [])
            }

            HStack(spacing: 8) {
                Button("Copy All") {
                    manager.copyAllToPasteboard()
                }
                .disabled(manager.items.isEmpty)

                Button("Clear") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.clear()
                    }
                }
                .disabled(manager.items.isEmpty)
            }
            .buttonStyle(.bordered)
        }
    }

    private func itemCard(_ item: CopiedBlock, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("#\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(Self.timestampFormatter.string(from: item.copiedAt))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.remove(id: item.id)
                    }
                } label: {
                    Text("Remove")
                }
                .buttonStyle(.borderless)
            }

            Text(verbatim: item.formattedText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
