import Foundation
import SwiftUI

struct BlockCardView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let block: Block
    let isLatest: Bool
    let onCopy: () -> Void

    init(block: Block, isLatest: Bool = false, onCopy: @escaping () -> Void = {}) {
        self.block = block
        self.isLatest = isLatest
        self.onCopy = onCopy
    }

    var body: some View {
        let theme = themeManager.activeTheme

        Group {
            if theme.isGlass {
                GlassPanel(
                    cornerRadius: GlassTokens.BlockCard.cornerRadius,
                    token: GlassTokens.BlockCard.panelStyle
                ) {
                    cardContent(theme: theme)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .glassSurface(.blockCard(isLatest: isLatest))
                .overlay(alignment: .top) {
                    if isLatest {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                GlassTokens.Accent.primary.opacity(0.11),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                        .padding(.top, 1)
                        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.BlockCard.cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    }
                }
            } else {
                cardContent(theme: theme)
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
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func cardContent(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                statusIndicator(theme: theme)
                Text(Self.timestampFormatter.string(from: block.startedAt))
                    .foregroundStyle(timestampColor(theme: theme))
                Spacer(minLength: 0)
                copyButton(theme: theme)
            }

            Text("$ \(block.command)")
                .foregroundStyle(theme.blockPrimaryTextColor)

            if theme.isGlass {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [GlassTokens.BlockCard.separator, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.top, 2)
            } else {
                Divider()
            }

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
    }

    @ViewBuilder
    private func statusIndicator(theme: Theme) -> some View {
        let color = statusColor(theme: theme)
        let glow = statusGlowColor

        Text(block.status.statusSymbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: theme.isGlass ? glow.opacity(0.28) : .clear, radius: 5, x: 0, y: 0)
            .overlay {
                if theme.isGlass {
                    Text(block.status.statusSymbol)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(glow.opacity(0.14))
                        .blur(radius: 2.5)
                }
            }
            .frame(width: 12, alignment: .leading)
    }

    private func statusColor(theme: Theme) -> Color {
        guard theme.isGlass else { return theme.blockPrimaryTextColor }

        switch block.status {
        case .running:
            return GlassTokens.Accent.primary.opacity(0.96)
        case .success:
            return GlassTokens.Accent.success.opacity(0.96)
        case .failure:
            return GlassTokens.Accent.failure.opacity(0.96)
        case .interrupted:
            return GlassTokens.Accent.warning.opacity(0.94)
        }
    }

    private var statusGlowColor: Color {
        switch block.status {
        case .running:
            return GlassTokens.Accent.primary
        case .success:
            return GlassTokens.Accent.success
        case .failure:
            return GlassTokens.Accent.failure
        case .interrupted:
            return GlassTokens.Accent.warning
        }
    }

    private func timestampColor(theme: Theme) -> Color {
        if theme.isGlass {
            return GlassTokens.Text.blockSecondary.opacity(0.94)
        }
        return theme.blockSecondaryTextColor
    }

    @ViewBuilder
    private func copyButton(theme: Theme) -> some View {
        Button {
            onCopy()
        } label: {
            Label("Copy block", systemImage: "doc.on.doc")
                .labelStyle(.iconOnly)
        }
        .help("Copy block")
        .accessibilityLabel("Copy block")
        .if(theme.isGlass) { view in
            view.buttonStyle(GlassButtonStyle())
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private extension View {
    @ViewBuilder
    func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private extension BlockStatus {
    var statusSymbol: String {
        switch self {
        case .running:
            return "●"
        case .success:
            return "✓"
        case .failure:
            return "✗"
        case .interrupted:
            return "⊘"
        }
    }
}
