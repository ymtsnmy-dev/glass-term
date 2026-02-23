import Foundation
import SwiftUI

struct BlockCardView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let block: Block
    let onCopy: () -> Void

    init(block: Block, onCopy: @escaping () -> Void = {}) {
        self.block = block
        self.onCopy = onCopy
    }

    var body: some View {
        let theme = themeManager.activeTheme

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(block.status.statusSymbol)
                    .foregroundStyle(theme.blockPrimaryTextColor)
                Text(Self.timestampFormatter.string(from: block.startedAt))
                    .foregroundStyle(theme.blockSecondaryTextColor)
                Spacer(minLength: 0)
                Button("Copy") {
                    onCopy()
                }
            }

            Text("$ \(block.command)")
                .foregroundStyle(theme.blockPrimaryTextColor)

            Divider()

            if !block.stdout.isEmpty {
                Text(verbatim: block.stdout)
                    .foregroundStyle(theme.blockPrimaryTextColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !block.stderr.isEmpty {
                Text(verbatim: block.stderr)
                    .foregroundStyle(theme.blockStderrTextColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(.body, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: theme.blockCardCornerRadius, style: .continuous)
                .fill(theme.blockCardBackground)
        )
        .overlay {
            if let border = theme.blockCardBorder {
                RoundedRectangle(cornerRadius: theme.blockCardCornerRadius, style: .continuous)
                    .stroke(border.color, lineWidth: border.lineWidth)
            }
        }
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
