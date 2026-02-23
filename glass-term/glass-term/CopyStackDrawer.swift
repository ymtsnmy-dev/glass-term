import SwiftUI

struct CopyStackDrawer: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var manager: CopyQueueManager
    let onClose: () -> Void

    init(manager: CopyQueueManager, onClose: @escaping () -> Void = {}) {
        self.manager = manager
        self.onClose = onClose
    }

    var body: some View {
        let isGlass = themeManager.activeTheme.isGlass

        VStack(alignment: .leading, spacing: 12) {
            header

            if isGlass {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                GlassTokens.Accent.primary.opacity(0.03),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            } else {
                Divider()
            }

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
        .background {
            if isGlass {
                Color.clear
            } else {
                Color.clear.background(.ultraThinMaterial)
            }
        }
        .if(isGlass) { view in
            view
                .glassSurface(.copyDrawerShell())
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    GlassTokens.Accent.primary.opacity(0.03),
                                    Color.clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 18)
                        .allowsHitTesting(false)
                }
        }
        .if(!isGlass) { view in
            view.shadow(color: .black.opacity(0.22), radius: 16, x: -6, y: 0)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var header: some View {
        let isGlass = themeManager.activeTheme.isGlass

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Label("Copy Stack", systemImage: "square.stack.3d.up")
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                    .foregroundStyle(isGlass ? GlassTokens.Text.panelHeading : .primary)
                    .help("Copy Stack")
                    .accessibilityLabel("Copy Stack")
                Spacer(minLength: 0)
                Text("\(manager.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isGlass ? GlassTokens.Text.panelSecondary.opacity(0.92) : .secondary)
                Button {
                    onClose()
                } label: {
                    Label("Close drawer", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .help("Close drawer")
                .accessibilityLabel("Close drawer")
                .buttonStyle(.borderless)
                .foregroundStyle(isGlass ? GlassTokens.Text.chromeLabel.opacity(0.92) : .primary)
                .keyboardShortcut(.escape, modifiers: [])
            }

            HStack(spacing: 8) {
                Button {
                    manager.copyAllToPasteboard()
                } label: {
                    Label("Copy all", systemImage: "doc.on.doc")
                }
                .help("Copy all")
                .accessibilityLabel("Copy all")
                .disabled(manager.items.isEmpty)
                .if(isGlass) { view in
                    view.buttonStyle(GlassButtonStyle())
                }
                .foregroundStyle(isGlass ? GlassTokens.Text.chromeLabel : .primary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.clear()
                    }
                } label: {
                    Label("Clear stack", systemImage: "trash")
                }
                .help("Clear stack")
                .accessibilityLabel("Clear stack")
                .disabled(manager.items.isEmpty)
                .if(isGlass) { view in
                    view.buttonStyle(GlassButtonStyle())
                }
                .foregroundStyle(isGlass ? GlassTokens.Text.chromeLabel : .primary)
            }
            .if(!isGlass) { view in
                view.buttonStyle(.bordered)
            }
        }
        .if(themeManager.activeTheme.isGlass) { view in
            view
                .padding(10)
                .glassSurface(.copyDrawerHeader())
        }
    }

    private func itemCard(_ item: CopiedBlock, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("#\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(themeManager.activeTheme.isGlass ? GlassTokens.Text.panelSecondary : .secondary)
                Text(Self.timestampFormatter.string(from: item.copiedAt))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(themeManager.activeTheme.isGlass ? GlassTokens.Text.blockSecondary.opacity(0.96) : .secondary)
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.remove(id: item.id)
                    }
                } label: {
                    Label("Remove item", systemImage: "xmark.circle")
                        .labelStyle(.iconOnly)
                }
                .help("Remove item")
                .accessibilityLabel("Remove item")
                .buttonStyle(.borderless)
                .foregroundStyle(themeManager.activeTheme.isGlass ? GlassTokens.Text.chromeLabel.opacity(0.90) : .primary)
            }

            Text(verbatim: item.formattedText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(themeManager.activeTheme.isGlass ? GlassTokens.Text.chromeLabel.opacity(0.95) : .primary)
                .padding(10)
                .background {
                    if !themeManager.activeTheme.isGlass {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    }
                }
                .if(themeManager.activeTheme.isGlass) { view in
                    view.glassSurface(.copyDrawerTextPanel())
                }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !themeManager.activeTheme.isGlass {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            }
        }
        .if(themeManager.activeTheme.isGlass) { view in
            view.glassSurface(.copyDrawerCard())
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
