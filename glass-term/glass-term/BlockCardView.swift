import Foundation
import SwiftUI

struct BlockCardView: View {
    let block: Block
    let onCopy: () -> Void

    init(block: Block, onCopy: @escaping () -> Void = {}) {
        self.block = block
        self.onCopy = onCopy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(block.status.statusSymbol)
                Text(Self.timestampFormatter.string(from: block.startedAt))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Copy", action: onCopy)
            }

            Text("$ \(block.command)")

            Divider()

            if !block.stdout.isEmpty {
                Text(verbatim: block.stdout)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !block.stderr.isEmpty {
                Text(verbatim: block.stderr)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(.body, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private extension BlockStatus {
    var statusSymbol: String {
        switch self {
        case .running:
            return "…"
        case .success:
            return "✓"
        case .failure:
            return "✗"
        case .interrupted:
            return "⊘"
        }
    }
}
