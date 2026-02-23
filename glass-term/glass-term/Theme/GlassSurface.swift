import SwiftUI

struct GlassSurfaceSpec {
    let cornerRadius: CGFloat
    let tint: Color
    let materialOpacity: Double
    let outerStrokeColor: Color
    let innerStrokeColor: Color
    let topEdgeColors: [Color]
    let bottomEdgeColors: [Color]
    let rimGlowColor: Color?
    let rimGlowOpacity: Double
    let rimGlowRadius: CGFloat
    let noiseOpacity: Double
    let nearShadowColor: Color
    let nearShadowRadius: CGFloat
    let nearShadowX: CGFloat
    let nearShadowY: CGFloat
    let farShadowColor: Color
    let farShadowRadius: CGFloat
    let farShadowX: CGFloat
    let farShadowY: CGFloat
}

extension GlassSurfaceSpec {
    static func tabStrip() -> Self {
        .init(
            cornerRadius: 16,
            tint: Color(.sRGB, red: 0.84, green: 0.92, blue: 1.00, opacity: 0.030),
            materialOpacity: 0.97,
            outerStrokeColor: Color.white.opacity(0.14),
            innerStrokeColor: Color.white.opacity(0.09),
            topEdgeColors: [
                Color.white.opacity(0.17),
                GlassTokens.Accent.primary.opacity(0.11),
                GlassTokens.Accent.secondary.opacity(0.04),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(0.025),
                GlassTokens.Accent.primary.opacity(0.035),
                Color.clear,
            ],
            rimGlowColor: GlassTokens.Accent.secondary,
            rimGlowOpacity: 0.07,
            rimGlowRadius: 11,
            noiseOpacity: 0.015,
            nearShadowColor: Color.black.opacity(0.09),
            nearShadowRadius: 6,
            nearShadowX: 0,
            nearShadowY: 2,
            farShadowColor: Color.black.opacity(0.05),
            farShadowRadius: 12,
            farShadowX: 0,
            farShadowY: 5
        )
    }

    static func tabPill(isActive: Bool, isHovered: Bool) -> Self {
        .init(
            cornerRadius: 15,
            tint: Color(.sRGB, red: 0.95, green: 0.99, blue: 1.00, opacity: isActive ? 0.095 : (isHovered ? 0.065 : 0.045)),
            materialOpacity: isActive ? 0.95 : 0.88,
            outerStrokeColor: Color.white.opacity(isActive ? 0.15 : (isHovered ? 0.12 : 0.10)),
            innerStrokeColor: Color.white.opacity(isActive ? 0.10 : 0.07),
            topEdgeColors: [
                Color.white.opacity(isActive ? 0.23 : (isHovered ? 0.17 : 0.11)),
                GlassTokens.Accent.primary.opacity(isActive ? 0.14 : 0.07),
                GlassTokens.Accent.secondary.opacity(isActive ? 0.05 : 0.02),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(isActive ? 0.04 : 0.02),
                GlassTokens.Accent.primary.opacity(isActive ? 0.07 : 0.025),
                Color.clear,
            ],
            rimGlowColor: isActive ? GlassTokens.Accent.primary : nil,
            rimGlowOpacity: isActive ? 0.13 : 0.0,
            rimGlowRadius: isActive ? 10 : 0,
            noiseOpacity: 0.0,
            nearShadowColor: Color.black.opacity(isActive ? 0.08 : 0.05),
            nearShadowRadius: isActive ? 5 : 3,
            nearShadowX: 0,
            nearShadowY: 2,
            farShadowColor: (isActive ? GlassTokens.Accent.primary : Color.black).opacity(isActive ? 0.12 : 0.0),
            farShadowRadius: isActive ? 9 : 0,
            farShadowX: 0,
            farShadowY: 2
        )
    }

    static func blockCard(isLatest: Bool = false) -> Self {
        .init(
            cornerRadius: GlassTokens.BlockCard.cornerRadius,
            tint: Color(.sRGB, red: 0.95, green: 0.99, blue: 1.00, opacity: 0.040),
            materialOpacity: 0.95,
            outerStrokeColor: Color.white.opacity(isLatest ? 0.15 : 0.13),
            innerStrokeColor: Color.white.opacity(0.09),
            topEdgeColors: [
                Color.white.opacity(isLatest ? 0.17 : 0.15),
                GlassTokens.Accent.primary.opacity(isLatest ? 0.115 : 0.10),
                GlassTokens.Accent.secondary.opacity(0.03),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(0.02),
                GlassTokens.Accent.primary.opacity(0.03),
                Color.clear,
            ],
            rimGlowColor: nil,
            rimGlowOpacity: 0,
            rimGlowRadius: 0,
            noiseOpacity: 0.015,
            nearShadowColor: Color.black.opacity(0.07),
            nearShadowRadius: 4,
            nearShadowX: 0,
            nearShadowY: 2,
            farShadowColor: Color.black.opacity(0.035),
            farShadowRadius: 10,
            farShadowX: 0,
            farShadowY: 4
        )
    }

    static func copyDrawerShell() -> Self {
        .init(
            cornerRadius: 18,
            tint: Color(.sRGB, red: 0.91, green: 0.965, blue: 1.00, opacity: 0.030),
            materialOpacity: 0.965,
            outerStrokeColor: Color.white.opacity(0.115),
            innerStrokeColor: Color.white.opacity(0.075),
            topEdgeColors: [
                Color.white.opacity(0.16),
                GlassTokens.Accent.primary.opacity(0.11),
                GlassTokens.Accent.secondary.opacity(0.05),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(0.02),
                GlassTokens.Accent.secondary.opacity(0.03),
                Color.clear,
            ],
            rimGlowColor: GlassTokens.Accent.secondary,
            rimGlowOpacity: 0.07,
            rimGlowRadius: 12,
            noiseOpacity: 0.018,
            nearShadowColor: Color.black.opacity(0.08),
            nearShadowRadius: 8,
            nearShadowX: -2,
            nearShadowY: 0,
            farShadowColor: Color.black.opacity(0.06),
            farShadowRadius: 14,
            farShadowX: -8,
            farShadowY: 0
        )
    }

    static func copyDrawerHeader() -> Self {
        .init(
            cornerRadius: 12,
            tint: Color(.sRGB, red: 0.96, green: 0.995, blue: 1.00, opacity: 0.040),
            materialOpacity: 0.885,
            outerStrokeColor: Color.white.opacity(0.095),
            innerStrokeColor: Color.white.opacity(0.065),
            topEdgeColors: [
                Color.white.opacity(0.14),
                GlassTokens.Accent.primary.opacity(0.09),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(0.02),
                Color.clear,
            ],
            rimGlowColor: nil,
            rimGlowOpacity: 0,
            rimGlowRadius: 0,
            noiseOpacity: 0,
            nearShadowColor: Color.black.opacity(0.06),
            nearShadowRadius: 4,
            nearShadowX: 0,
            nearShadowY: 2,
            farShadowColor: Color.black.opacity(0.03),
            farShadowRadius: 6,
            farShadowX: 0,
            farShadowY: 3
        )
    }

    static func copyDrawerCard() -> Self {
        .init(
            cornerRadius: 12,
            tint: Color(.sRGB, red: 0.975, green: 0.998, blue: 1.00, opacity: 0.034),
            materialOpacity: 0.865,
            outerStrokeColor: Color.white.opacity(0.095),
            innerStrokeColor: Color.white.opacity(0.062),
            topEdgeColors: [
                Color.white.opacity(0.12),
                GlassTokens.Accent.primary.opacity(0.07),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(0.02),
                Color.clear,
            ],
            rimGlowColor: nil,
            rimGlowOpacity: 0,
            rimGlowRadius: 0,
            noiseOpacity: 0,
            nearShadowColor: Color.black.opacity(0.05),
            nearShadowRadius: 3,
            nearShadowX: 0,
            nearShadowY: 1,
            farShadowColor: Color.black.opacity(0.025),
            farShadowRadius: 6,
            farShadowX: 0,
            farShadowY: 3
        )
    }

    static func copyDrawerTextPanel() -> Self {
        .init(
            cornerRadius: 10,
            tint: Color(.sRGB, red: 0.985, green: 1.00, blue: 1.00, opacity: 0.027),
            materialOpacity: 0.815,
            outerStrokeColor: Color.white.opacity(0.085),
            innerStrokeColor: Color.white.opacity(0.055),
            topEdgeColors: [
                Color.white.opacity(0.10),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(0.015),
                Color.clear,
            ],
            rimGlowColor: nil,
            rimGlowOpacity: 0,
            rimGlowRadius: 0,
            noiseOpacity: 0,
            nearShadowColor: Color.black.opacity(0.035),
            nearShadowRadius: 2,
            nearShadowX: 0,
            nearShadowY: 1,
            farShadowColor: Color.black.opacity(0.015),
            farShadowRadius: 4,
            farShadowX: 0,
            farShadowY: 2
        )
    }

    static func inputBar(isFocused: Bool) -> Self {
        .init(
            cornerRadius: 14,
            tint: Color(.sRGB, red: 0.90, green: 0.96, blue: 1.00, opacity: 0.030),
            materialOpacity: 0.97,
            outerStrokeColor: Color.white.opacity(0.115),
            innerStrokeColor: Color.white.opacity(0.075),
            topEdgeColors: [
                Color.white.opacity(0.17),
                GlassTokens.Accent.primary.opacity(isFocused ? 0.14 : 0.09),
                GlassTokens.Accent.secondary.opacity(0.03),
                Color.clear,
            ],
            bottomEdgeColors: [
                Color.clear,
                Color.white.opacity(0.02),
                GlassTokens.Accent.primary.opacity(isFocused ? 0.05 : 0.02),
                Color.clear,
            ],
            rimGlowColor: isFocused ? GlassTokens.Accent.primary : nil,
            rimGlowOpacity: isFocused ? 0.14 : 0.0,
            rimGlowRadius: isFocused ? 10 : 0,
            noiseOpacity: 0.015,
            nearShadowColor: Color.black.opacity(0.08),
            nearShadowRadius: 5,
            nearShadowX: 0,
            nearShadowY: 2,
            farShadowColor: (isFocused ? GlassTokens.Accent.primary : Color.black).opacity(isFocused ? 0.09 : 0.04),
            farShadowRadius: isFocused ? 12 : 10,
            farShadowX: 0,
            farShadowY: isFocused ? 2 : 4
        )
    }
}

struct GlassSurfaceModifier: ViewModifier {
    let spec: GlassSurfaceSpec

    func body(content: Content) -> some View {
        content
            .background {
                GlassSurfaceBackground(spec: spec)
            }
            .shadow(color: spec.nearShadowColor, radius: spec.nearShadowRadius, x: spec.nearShadowX, y: spec.nearShadowY)
            .shadow(color: spec.farShadowColor, radius: spec.farShadowRadius, x: spec.farShadowX, y: spec.farShadowY)
    }
}

extension View {
    func glassSurface(_ spec: GlassSurfaceSpec) -> some View {
        modifier(GlassSurfaceModifier(spec: spec))
    }
}

private struct GlassSurfaceBackground: View {
    let spec: GlassSurfaceSpec

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: spec.cornerRadius, style: .continuous)

        ZStack {
            shape
                .fill(.ultraThinMaterial)
                .opacity(spec.materialOpacity)

            shape.fill(spec.tint)

            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.070),
                        Color.white.opacity(0.025),
                        Color.black.opacity(0.004),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            if spec.noiseOpacity > 0 {
                GlassSurfaceNoiseOverlay(opacity: spec.noiseOpacity)
                    .clipShape(shape)
            }

            if let rimGlowColor = spec.rimGlowColor, spec.rimGlowOpacity > 0 {
                shape
                    .stroke(rimGlowColor.opacity(spec.rimGlowOpacity), lineWidth: 1)
                    .blur(radius: spec.rimGlowRadius)
                    .blendMode(.screen)
            }
        }
        .overlay {
            shape.stroke(spec.outerStrokeColor, lineWidth: 1)
        }
        .overlay {
            shape.inset(by: 1)
                .stroke(spec.innerStrokeColor, lineWidth: 1)
        }
        .overlay(alignment: .top) {
            LinearGradient(colors: spec.topEdgeColors, startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .padding(.horizontal, 4)
                .padding(.top, 1)
                .clipShape(shape)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: spec.bottomEdgeColors, startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .padding(.horizontal, 6)
                .padding(.bottom, 1)
                .clipShape(shape)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GlassSurfaceNoiseOverlay: View {
    let opacity: Double

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let step: CGFloat = 12
            let cols = max(1, Int(size.width / step) + 2)
            let rows = max(1, Int(size.height / step) + 2)

            for y in 0..<rows {
                for x in 0..<cols {
                    let seed = hash(x: x, y: y)
                    guard seed > 0.82 else { continue }

                    let a = ((seed - 0.82) / 0.18) * opacity
                    let jitterX = (hash(x: x + 311, y: y + 919) - 0.5) * 3.0
                    let jitterY = (hash(x: x + 617, y: y + 127) - 0.5) * 3.0

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: CGFloat(x) * step + jitterX,
                            y: CGFloat(y) * step + jitterY,
                            width: 1.1,
                            height: 1.1
                        )),
                        with: .color(.white.opacity(a))
                    )
                }
            }
        }
        .blendMode(.screen)
    }

    private func hash(x: Int, y: Int) -> Double {
        var n = UInt64(bitPattern: Int64(x &* 73856093 ^ y &* 19349663))
        n ^= (n << 13)
        n ^= (n >> 7)
        n ^= (n << 17)
        return Double(n & 0xFFFF) / Double(0xFFFF)
    }
}
