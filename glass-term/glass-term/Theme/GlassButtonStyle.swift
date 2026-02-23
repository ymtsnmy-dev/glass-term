import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    let tokenSet: GlassButtonTokenSet

    init(tokenSet: GlassButtonTokenSet = GlassTokens.CopyButton.states) {
        self.tokenSet = tokenSet
    }

    func makeBody(configuration: Configuration) -> some View {
        GlassButtonBody(configuration: configuration, tokenSet: tokenSet)
    }
}

private struct GlassButtonBody: View {
    let configuration: GlassButtonStyle.Configuration
    let tokenSet: GlassButtonTokenSet

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var visualToken: GlassButtonVisualToken {
        if !isEnabled {
            return tokenSet.normal
        }
        if configuration.isPressed {
            return tokenSet.pressed
        }
        if isHovered {
            return tokenSet.hover
        }
        return tokenSet.normal
    }

    var body: some View {
        configuration.label
            .font(.system(size: tokenSet.metrics.fontSize, weight: tokenSet.metrics.fontWeight))
            .foregroundStyle(visualToken.textColor.opacity(isEnabled ? 1 : 0.55))
            .lineLimit(1)
            .padding(.horizontal, tokenSet.metrics.horizontalPadding)
            .padding(.vertical, tokenSet.metrics.verticalPadding)
            .frame(minHeight: tokenSet.metrics.minHeight)
            .contentShape(RoundedRectangle(cornerRadius: tokenSet.metrics.cornerRadius, style: .continuous))
            .background {
                GlassPanelBackground(
                    cornerRadius: tokenSet.metrics.cornerRadius,
                    token: visualToken.panel
                )
            }
            .scaleEffect(configuration.isPressed ? tokenSet.metrics.pressedScale : 1.0)
            .opacity(isEnabled ? 1.0 : 0.75)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
