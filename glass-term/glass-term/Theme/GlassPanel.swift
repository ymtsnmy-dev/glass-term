import SwiftUI

struct GlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let token: GlassPanelToken
    private let content: Content

    init(
        cornerRadius: CGFloat,
        token: GlassPanelToken,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.token = token
        self.content = content()
    }

    var body: some View {
        content
            .background {
                GlassPanelBackground(cornerRadius: cornerRadius, token: token)
            }
    }
}

struct GlassPanelBackground: View {
    let cornerRadius: CGFloat
    let token: GlassPanelToken

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape.fill(token.fill)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.070),
                            Color.white.opacity(0.022),
                            Color.black.opacity(0.008),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            shape
                .fill(token.highlight.gradient)
                .blendMode(.screen)

            if let noiseAssetName = GlassTokens.noiseAssetName, token.noiseOpacity > 0 {
                shape
                    .fill(.clear)
                    .overlay {
                        Image(noiseAssetName)
                            .resizable(resizingMode: .tile)
                            .interpolation(.none)
                            .opacity(token.noiseOpacity)
                    }
                    .clipShape(shape)
            }

            // Lightweight inner shadow: blurred inset stroke clipped to the panel shape.
            shape
                .stroke(token.innerShadow.color, lineWidth: token.innerShadow.lineWidth)
                .blur(radius: token.innerShadow.blur)
                .offset(x: token.innerShadow.x, y: token.innerShadow.y)
                .clipShape(shape)
        }
        .overlay {
            shape
                .stroke(token.stroke.color, lineWidth: token.stroke.width)
        }
        .overlay(alignment: .top) {
            shape
                .fill(.clear)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.09),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 3)
                    .padding(.top, 1)
                }
                .clipShape(shape)
        }
        .overlay(alignment: .bottom) {
            shape
                .fill(.clear)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.06),
                            Color(.sRGB, red: 0.55, green: 0.94, blue: 1.0, opacity: 0.09),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 1)
                }
                .clipShape(shape)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
