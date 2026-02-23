import SwiftUI

struct TabBarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var tabFrames: [UUID: CGRect] = [:]

    struct Item: Identifiable, Equatable {
        enum SessionState: Equatable {
            case running
            case idle
            case exited
        }

        let id: UUID
        let title: String
        let subtitle: String?
        let state: SessionState
        let isActive: Bool
    }

    let items: [Item]
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        let isGlass = themeManager.activeTheme.isGlass

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            TabPillView(
                                item: item,
                                isGlass: isGlass,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        onSelect(item.id)
                                    }
                                },
                                onClose: {
                                    onClose(item.id)
                                }
                            )
                            .background {
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(
                                            key: TabPillFramePreferenceKey.self,
                                            value: [item.id: proxy.frame(in: .named(TabBarLayout.coordinateSpaceName))]
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                NewTabOrbButton(isGlass: isGlass, action: onAdd)
                    .padding(.trailing, 2)
            }
            .padding(.horizontal, 10)
            .padding(.top, isGlass ? 8 : 0)
            .padding(.bottom, isGlass ? 8 : 0)
            .coordinateSpace(name: TabBarLayout.coordinateSpaceName)
            .background {
                if isGlass {
                    Color.clear
                        .glassSurface(.tabStrip())
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.90))
                        .shadow(color: Color.black.opacity(0.20), radius: 8, x: 0, y: 3)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let activeFrame = activeTabFrame {
                    ActiveTabUnderline(frame: activeFrame, isGlass: isGlass)
                        .allowsHitTesting(false)
                }
            }
        }
        .onPreferenceChange(TabPillFramePreferenceKey.self) { newValue in
            withAnimation(.easeInOut(duration: 0.15)) {
                tabFrames = newValue
            }
        }
        .padding(.horizontal, isGlass ? 8 : 0)
    }

    private var activeTabFrame: CGRect? {
        guard let active = items.first(where: \.isActive) else { return nil }
        return tabFrames[active.id]
    }
}

private enum TabBarLayout {
    static let coordinateSpaceName = "glass-term-tab-bar"
}

private struct TabPillView: View {
    let item: TabBarView.Item
    let isGlass: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    private var showsClose: Bool {
        isHovered
    }

    private var pillCornerRadius: CGFloat { 15 }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    SessionStatusDot(state: item.state, isGlass: isGlass)

                    HStack(spacing: 6) {
                        Text(item.title)
                            .lineLimit(1)
                            .font(.system(size: 12, weight: item.isActive ? .semibold : .medium))
                            .foregroundStyle(primaryTextColor)

                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .lineLimit(1)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 2)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select session \(item.title)")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(closeIconColor)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(showsClose ? 1 : 0)
            .allowsHitTesting(showsClose)
            .accessibilityLabel("Close session \(item.title)")
            .padding(.trailing, 4)
        }
        .background { pillBackground }
        .overlay { pillStroke }
        .overlay { pillEdgeHighlights }
        .if(isGlass) { view in
            view.glassSurface(.tabPill(isActive: item.isActive, isHovered: isHovered))
        }
        .shadow(color: glowColor, radius: item.isActive ? 10 : (isHovered ? 5 : 0), x: 0, y: item.isActive ? 2 : 0)
        .scaleEffect(!item.isActive && isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: item.isActive)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var pillBackground: some View {
        if isGlass {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(item.isActive ? 0.95 : 0.75)
        }
    }

    @ViewBuilder
    private var pillStroke: some View {
        let shape = RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
        if isGlass {
            EmptyView()
        } else {
            shape.stroke(Color.white.opacity(item.isActive ? 0.22 : 0.10), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var pillEdgeHighlights: some View {
        if isGlass {
            EmptyView()
        } else {
            EmptyView()
        }
    }

    private var primaryTextColor: Color {
        if isGlass {
            switch item.state {
            case .exited:
                return Color(.sRGB, red: 0.95, green: 0.92, blue: 0.98, opacity: item.isActive ? 0.98 : 0.88)
            case .running, .idle:
                return item.isActive
                    ? Color(.sRGB, red: 0.86, green: 0.97, blue: 1.00, opacity: 0.98)
                    : Color(.sRGB, red: 0.72, green: 0.88, blue: 0.96, opacity: 0.88)
            }
        }
        return item.isActive ? .white : Color.white.opacity(0.85)
    }

    private var secondaryTextColor: Color {
        if isGlass {
            return item.isActive
                ? Color(.sRGB, red: 0.52, green: 0.90, blue: 1.0, opacity: 0.88)
                : Color(.sRGB, red: 0.62, green: 0.80, blue: 0.92, opacity: 0.66)
        }
        return Color.white.opacity(0.65)
    }

    private var closeIconColor: Color {
        if isGlass {
            return item.isActive
                ? Color(.sRGB, red: 0.80, green: 0.95, blue: 1.00, opacity: 0.88)
                : Color(.sRGB, red: 0.74, green: 0.88, blue: 0.98, opacity: 0.80)
        }
        return Color.white.opacity(0.8)
    }

    private var glowColor: Color {
        guard isGlass else { return .clear }
        if item.isActive {
            return Color(.sRGB, red: 0.44, green: 0.88, blue: 1.00, opacity: 0.16)
        }
        if isHovered {
            return Color.white.opacity(0.08)
        }
        return .clear
    }
}

private struct SessionStatusDot: View {
    let state: TabBarView.Item.SessionState
    let isGlass: Bool

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(isGlass ? 0.95 : 0.85),
                        dotColor,
                        dotColor.opacity(isGlass ? 0.25 : 0.0),
                    ],
                    center: .center,
                    startRadius: 0.3,
                    endRadius: isGlass ? 5 : 3
                )
            )
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(isGlass ? 0.10 : 0.18), lineWidth: 0.5)
            }
            .shadow(color: dotColor.opacity(isGlass ? 0.55 : 0), radius: isGlass ? 5 : 0, x: 0, y: 0)
    }

    private var dotColor: Color {
        switch state {
        case .running:
            return isGlass
                ? GlassTokens.Accent.success.opacity(0.98)
                : Color.green.opacity(0.95)
        case .idle:
            return isGlass
                ? GlassTokens.Accent.idle.opacity(0.92)
                : Color.white.opacity(0.72)
        case .exited:
            return isGlass
                ? GlassTokens.Accent.failure.opacity(0.95)
                : Color.red.opacity(0.9)
        }
    }
}

private struct NewTabOrbButton: View {
    let isGlass: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(isGlass ? Color(.sRGB, red: 0.95, green: 0.99, blue: 1.0, opacity: 0.08) : Color.white.opacity(0.10))
                    .background {
                        if isGlass {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.10),
                                            Color(.sRGB, red: 0.40, green: 0.86, blue: 1.0, opacity: 0.06),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .overlay {
                        Circle()
                            .stroke(isGlass ? Color.white.opacity(0.11) : Color.white.opacity(0.18), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(isGlass ? 0.24 : 0.18))
                            .frame(width: 9, height: 1)
                            .padding(.top, 3)
                    }
                    .frame(width: 20, height: 20)

                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isGlass ? Color(.sRGB, red: 0.85, green: 0.97, blue: 1.0, opacity: 0.95) : Color.white)
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(NewTabOrbPressStyle())
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(color: isGlass ? Color(.sRGB, red: 0.36, green: 0.86, blue: 1.0, opacity: isHovered ? 0.18 : 0.08) : .clear, radius: isHovered ? 8 : 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("New tab")
    }
}

private struct NewTabOrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ActiveTabUnderline: View {
    let frame: CGRect
    let isGlass: Bool

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: underlineColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: frame.width, height: 1)
            .overlay {
                Rectangle()
                    .fill(underlineGlow)
                    .frame(height: isGlass ? 2 : 1)
                    .blur(radius: isGlass ? 3 : 0)
                    .opacity(isGlass ? 0.75 : 0)
            }
            .offset(x: frame.minX, y: -1)
            .animation(.easeInOut(duration: 0.15), value: frame.minX)
            .animation(.easeInOut(duration: 0.15), value: frame.width)
    }

    private var underlineColors: [Color] {
        if isGlass {
            return [
                Color(.sRGB, red: 0.30, green: 0.88, blue: 1.00, opacity: 0.00),
                GlassTokens.Accent.secondary.opacity(0.16),
                Color(.sRGB, red: 0.74, green: 0.98, blue: 1.00, opacity: 0.90),
                GlassTokens.Accent.secondary.opacity(0.10),
                Color(.sRGB, red: 0.30, green: 0.88, blue: 1.00, opacity: 0.00),
            ]
        }
        return [Color.clear, Color.white.opacity(0.6), Color.clear]
    }

    private var underlineGlow: Color {
        isGlass ? Color(.sRGB, red: 0.38, green: 0.90, blue: 1.00, opacity: 0.35) : .clear
    }
}

private struct TabPillFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
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
