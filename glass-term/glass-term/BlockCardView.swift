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
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: GlassTokens.BlockCard.cornerRadius, style: .continuous)
                        .fill(.clear)
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color(.sRGB, red: 0.72, green: 0.95, blue: 1.0, opacity: 0.08),
                                    Color.clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 10)
                            .padding(.top, 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.BlockCard.cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: GlassTokens.BlockCard.cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.10), lineWidth: 1)
                        .blur(radius: 1.5)
                        .offset(y: 1)
                        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.BlockCard.cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                }
                .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
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
        .padding(.horizontal)
    }

    @ViewBuilder
    private func cardContent(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(block.status.statusSymbol)
                    .foregroundStyle(theme.blockPrimaryTextColor)
                Text(Self.timestampFormatter.string(from: block.startedAt))
                    .foregroundStyle(theme.blockSecondaryTextColor)
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
    private func copyButton(theme: Theme) -> some View {
        Button("Copy") {
            onCopy()
        }
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
