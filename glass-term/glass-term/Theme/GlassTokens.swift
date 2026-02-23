import CoreGraphics
import SwiftUI

enum GlassTokens {
    static let noiseAssetName: String? = nil

    enum Accent {
        static let primary = Color(.sRGB, red: 0.42, green: 0.90, blue: 1.00, opacity: 1.0)   // focus / active
        static let secondary = Color(.sRGB, red: 0.66, green: 0.52, blue: 1.00, opacity: 1.0) // depth / edge tint

        static let success = Color(.sRGB, red: 0.33, green: 0.96, blue: 0.84, opacity: 1.0)
        static let warning = Color(.sRGB, red: 1.00, green: 0.78, blue: 0.36, opacity: 1.0)
        static let failure = Color(.sRGB, red: 1.00, green: 0.47, blue: 0.55, opacity: 1.0)
        static let idle = Color(.sRGB, red: 0.70, green: 0.88, blue: 1.00, opacity: 1.0)
    }

    enum Background {
        static let overlayTint = Color(.sRGB, red: 0.040, green: 0.060, blue: 0.095, opacity: 0.16)
        static let topGlow = Color(.sRGB, red: 0.380, green: 0.840, blue: 1.000, opacity: 0.08)
        static let noiseOpacity: Double = 0.045
    }

    enum Text {
        static let blockPrimary = Color(.sRGB, red: 0.760, green: 0.955, blue: 1.000, opacity: 0.97)
        static let blockSecondary = Color(.sRGB, red: 0.680, green: 0.860, blue: 0.980, opacity: 0.82)
        static let blockStderr = Color(.sRGB, red: 1.000, green: 0.700, blue: 0.860, opacity: 0.96)
        static let buttonLabel = Color(.sRGB, red: 0.865, green: 0.965, blue: 1.000, opacity: 0.97)
    }

    enum BlockCard {
        static let cornerRadius: CGFloat = 16
        static let separator = Color(.sRGB, red: 0.840, green: 0.950, blue: 1.000, opacity: 0.18)
        static let panelStyle = GlassPanelToken(
            fill: Color(.sRGB, red: 0.935, green: 0.975, blue: 1.000, opacity: 0.042),
            stroke: GlassStrokeToken(
                color: Color(.sRGB, red: 0.920, green: 0.980, blue: 1.000, opacity: 0.11),
                width: 1
            ),
            highlight: GlassHighlightGradientToken(
                startX: 0.08,
                startY: 0.00,
                endX: 0.92,
                endY: 0.48,
                stops: [
                    .init(color: Color(.sRGB, red: 0.980, green: 1.000, blue: 1.000, opacity: 0.24), location: 0.0),
                    .init(color: Color(.sRGB, red: 0.620, green: 0.900, blue: 1.000, opacity: 0.14), location: 0.34),
                    .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.00), location: 1.0),
                ]
            ),
            innerShadow: GlassInnerShadowToken(
                color: Color(.sRGB, red: 0.020, green: 0.040, blue: 0.070, opacity: 0.18),
                x: 0,
                y: 1,
                blur: 1.8,
                lineWidth: 1.0
            ),
            noiseOpacity: 0.0
        )
    }

    enum TerminalSurface {
        static let cornerRadius: CGFloat = 0
        static let panelStyle = GlassPanelToken(
            fill: Color(.sRGB, red: 0.055, green: 0.070, blue: 0.095, opacity: 0.26),
            stroke: GlassStrokeToken(
                color: Color(.sRGB, red: 0.980, green: 0.995, blue: 1.000, opacity: 0.10),
                width: 1
            ),
            highlight: GlassHighlightGradientToken(
                startX: 0.20,
                startY: 0.00,
                endX: 0.80,
                endY: 0.52,
                stops: [
                    .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.14), location: 0.0),
                    .init(color: Color(.sRGB, red: 0.780, green: 0.900, blue: 1.000, opacity: 0.06), location: 0.32),
                    .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.00), location: 1.0),
                ]
            ),
            innerShadow: GlassInnerShadowToken(
                color: Color(.sRGB, red: 0.000, green: 0.000, blue: 0.000, opacity: 0.20),
                x: 0,
                y: 1,
                blur: 1.5,
                lineWidth: 1.0
            ),
            noiseOpacity: 0.0
        )

        static let auroraTopBlue = Color(.sRGB, red: 0.360, green: 0.700, blue: 1.000, opacity: 0.16)
        static let auroraRightGreen = Color(.sRGB, red: 0.250, green: 0.980, blue: 0.650, opacity: 0.12)
        static let auroraLeftViolet = Color(.sRGB, red: 0.420, green: 0.430, blue: 0.980, opacity: 0.08)
        static let vignette = Color(.sRGB, red: 0.010, green: 0.015, blue: 0.025, opacity: 0.36)
    }

    enum RawTerminal {
        static let cornerRadius: CGFloat = 16

        static let containerPanel = GlassPanelToken(
            fill: Color(.sRGB, red: 0.930, green: 0.975, blue: 1.000, opacity: 0.040),
            stroke: .init(
                color: Color(.sRGB, red: 0.820, green: 0.950, blue: 1.000, opacity: 0.11),
                width: 1
            ),
            highlight: .init(
                startX: 0.08,
                startY: 0.00,
                endX: 0.92,
                endY: 0.42,
                stops: [
                    .init(color: Color(.sRGB, red: 0.900, green: 1.000, blue: 1.000, opacity: 0.22), location: 0.0),
                    .init(color: Color(.sRGB, red: 0.380, green: 0.860, blue: 1.000, opacity: 0.12), location: 0.28),
                    .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.00), location: 1.0),
                ]
            ),
            innerShadow: .init(
                color: Color(.sRGB, red: 0.000, green: 0.000, blue: 0.000, opacity: 0.18),
                x: 0,
                y: 1,
                blur: 1.6,
                lineWidth: 1
            ),
            noiseOpacity: 0
        )

        static let terminalBackground = Color(.sRGB, red: 0.025, green: 0.060, blue: 0.100, opacity: 0.34)
        static let terminalText = Color(.sRGB, red: 0.640, green: 0.930, blue: 1.000, opacity: 0.98)
        static let terminalCursor = Color(.sRGB, red: 0.840, green: 1.000, blue: 1.000, opacity: 0.98)
    }

    enum TabBar {
        static let strip = GlassPanelToken(
            fill: Color(.sRGB, red: 0.070, green: 0.085, blue: 0.115, opacity: 0.18),
            stroke: .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.10), width: 1),
            highlight: .init(
                startX: 0.0,
                startY: 0.0,
                endX: 1.0,
                endY: 0.8,
                stops: [
                    .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.18), location: 0),
                    .init(color: Color(.sRGB, red: 0.840, green: 0.920, blue: 1.000, opacity: 0.05), location: 0.35),
                    .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0), location: 1),
                ]
            ),
            innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.22), x: 0, y: 1, blur: 1.5, lineWidth: 1),
            noiseOpacity: 0
        )

        static let activeChip = GlassPanelToken(
            fill: Color(.sRGB, red: 0.960, green: 0.985, blue: 1.000, opacity: 0.10),
            stroke: .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.12), width: 1),
            highlight: .init(
                startX: 0.1, startY: 0, endX: 0.9, endY: 1,
                stops: [
                    .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.22), location: 0),
                    .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.00), location: 1),
                ]
            ),
            innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.18), x: 0, y: 1, blur: 1.2, lineWidth: 1),
            noiseOpacity: 0
        )

        static let inactiveChip = GlassPanelToken(
            fill: Color(.sRGB, red: 0.960, green: 0.985, blue: 1.000, opacity: 0.045),
            stroke: .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.09), width: 1),
            highlight: .init(
                startX: 0.1, startY: 0, endX: 0.9, endY: 1,
                stops: [
                    .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.10), location: 0),
                    .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.00), location: 1),
                ]
            ),
            innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.16), x: 0, y: 1, blur: 1.0, lineWidth: 1),
            noiseOpacity: 0
        )

        static let separator = Color(.sRGB, red: 0.870, green: 0.960, blue: 1.000, opacity: 0.12)
    }

    enum InputBar {
        static let panel = GlassPanelToken(
            fill: Color(.sRGB, red: 0.080, green: 0.095, blue: 0.130, opacity: 0.26),
            stroke: .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.10), width: 1),
            highlight: .init(
                startX: 0.0, startY: 0.0, endX: 1.0, endY: 0.7,
                stops: [
                    .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.18), location: 0),
                    .init(color: Color(.sRGB, red: 0.82, green: 0.92, blue: 1.0, opacity: 0.07), location: 0.38),
                    .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.00), location: 1),
                ]
            ),
            innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.22), x: 0, y: 1, blur: 1.5, lineWidth: 1),
            noiseOpacity: 0
        )

        static let prompt = Color(.sRGB, red: 0.430, green: 0.920, blue: 1.000, opacity: 0.90)
        static let text = Color(.sRGB, red: 0.820, green: 0.965, blue: 1.000, opacity: 0.97)
        static let borderGlow = Color(.sRGB, red: 0.320, green: 0.850, blue: 1.000, opacity: 0.12)
    }

    enum CopyButton {
        static let cornerRadius: CGFloat = 9
        static let minHeight: CGFloat = 24
        static let horizontalPadding: CGFloat = 9
        static let verticalPadding: CGFloat = 4
        static let fontSize: CGFloat = 11

        static let states = GlassButtonTokenSet(
            normal: normal,
            hover: hover,
            pressed: pressed,
            metrics: .init(
                cornerRadius: cornerRadius,
                minHeight: minHeight,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                fontSize: fontSize,
                fontWeight: .semibold,
                pressedScale: 0.985
            )
        )

        static let normal = GlassButtonVisualToken(
            panel: GlassPanelToken(
                fill: Color(.sRGB, red: 0.970, green: 0.990, blue: 1.000, opacity: 0.055),
                stroke: .init(
                    color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.10),
                    width: 1
                ),
                highlight: .init(
                    startX: 0.50,
                    startY: 0.00,
                    endX: 0.50,
                    endY: 0.90,
                    stops: [
                        .init(color: Color(.sRGB, red: 0.900, green: 0.980, blue: 1.000, opacity: 0.16), location: 0.0),
                        .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.00), location: 1.0),
                    ]
                ),
                innerShadow: .init(
                    color: Color(.sRGB, red: 0.000, green: 0.000, blue: 0.000, opacity: 0.22),
                    x: 0,
                    y: 1,
                    blur: 1.5,
                    lineWidth: 1.0
                ),
                noiseOpacity: 0.0
            ),
            textColor: Text.buttonLabel
        )

        static let hover = GlassButtonVisualToken(
            panel: GlassPanelToken(
                fill: Color(.sRGB, red: 0.970, green: 0.990, blue: 1.000, opacity: 0.075),
                stroke: .init(
                    color: Color(.sRGB, red: 0.760, green: 0.950, blue: 1.000, opacity: 0.12),
                    width: 1
                ),
                highlight: .init(
                    startX: 0.50,
                    startY: 0.00,
                    endX: 0.50,
                    endY: 0.88,
                    stops: [
                        .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.19), location: 0.0),
                        .init(color: Accent.primary.opacity(0.10), location: 0.28),
                        .init(color: Accent.secondary.opacity(0.04), location: 0.52),
                        .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.00), location: 1.0),
                    ]
                ),
                innerShadow: .init(
                    color: Color(.sRGB, red: 0.000, green: 0.000, blue: 0.000, opacity: 0.20),
                    x: 0,
                    y: 1,
                    blur: 1.5,
                    lineWidth: 1.0
                ),
                noiseOpacity: 0.0
            ),
            textColor: Color(.sRGB, red: 0.900, green: 0.980, blue: 1.000, opacity: 0.98)
        )

        static let pressed = GlassButtonVisualToken(
            panel: GlassPanelToken(
                fill: Color(.sRGB, red: 0.910, green: 0.950, blue: 0.990, opacity: 0.080),
                stroke: .init(
                    color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.10),
                    width: 1
                ),
                highlight: .init(
                    startX: 0.50,
                    startY: 0.00,
                    endX: 0.50,
                    endY: 0.75,
                    stops: [
                        .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.08), location: 0.0),
                        .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.00), location: 1.0),
                    ]
                ),
                innerShadow: .init(
                    color: Color(.sRGB, red: 0.000, green: 0.000, blue: 0.000, opacity: 0.26),
                    x: 0,
                    y: 1,
                    blur: 1.0,
                    lineWidth: 1.0
                ),
                noiseOpacity: 0.0
            ),
            textColor: Text.buttonLabel
        )
    }

    enum ChromeButtons {
        static let compactIconStates = GlassButtonTokenSet(
            normal: .init(
                panel: GlassPanelToken(
                    fill: Color(.sRGB, red: 0.970, green: 0.990, blue: 1.000, opacity: 0.060),
                    stroke: .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.10), width: 1),
                    highlight: .init(startX: 0.5, startY: 0, endX: 0.5, endY: 1, stops: [
                        .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.14), location: 0),
                        .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0), location: 1),
                    ]),
                    innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.20), x: 0, y: 1, blur: 1.2, lineWidth: 1),
                    noiseOpacity: 0
                ),
                textColor: Text.buttonLabel
            ),
            hover: .init(
                panel: GlassPanelToken(
                    fill: Color(.sRGB, red: 0.970, green: 0.990, blue: 1.000, opacity: 0.090),
                    stroke: .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.12), width: 1),
                    highlight: .init(startX: 0.5, startY: 0, endX: 0.5, endY: 1, stops: [
                        .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.18), location: 0),
                        .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0), location: 1),
                    ]),
                    innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.18), x: 0, y: 1, blur: 1.2, lineWidth: 1),
                    noiseOpacity: 0
                ),
                textColor: Text.buttonLabel
            ),
            pressed: .init(
                panel: GlassPanelToken(
                    fill: Color(.sRGB, red: 0.920, green: 0.950, blue: 0.990, opacity: 0.095),
                    stroke: .init(color: Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 0.09), width: 1),
                    highlight: .init(startX: 0.5, startY: 0, endX: 0.5, endY: 1, stops: [
                        .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.08), location: 0),
                        .init(color: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0), location: 1),
                    ]),
                    innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.22), x: 0, y: 1, blur: 1.0, lineWidth: 1),
                    noiseOpacity: 0
                ),
                textColor: Text.buttonLabel
            ),
            metrics: .init(
                cornerRadius: 9,
                minHeight: 28,
                horizontalPadding: 8,
                verticalPadding: 4,
                fontSize: 12,
                fontWeight: .semibold,
                pressedScale: 0.985
            )
        )

        static let runStates = GlassButtonTokenSet(
            normal: .init(
                panel: GlassPanelToken(
                    fill: Color(.sRGB, red: 0.440, green: 0.920, blue: 0.720, opacity: 0.12),
                    stroke: .init(color: Color(.sRGB, red: 0.700, green: 1.000, blue: 0.900, opacity: 0.25), width: 1),
                    highlight: .init(startX: 0.5, startY: 0, endX: 0.5, endY: 1, stops: [
                        .init(color: Color(.sRGB, red: 0.90, green: 1.00, blue: 0.97, opacity: 0.20), location: 0),
                        .init(color: Color(.sRGB, red: 0.90, green: 1.00, blue: 0.97, opacity: 0), location: 1),
                    ]),
                    innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.24), x: 0, y: 1, blur: 1.2, lineWidth: 1),
                    noiseOpacity: 0
                ),
                textColor: Color(.sRGB, red: 0.930, green: 1.000, blue: 0.980, opacity: 0.98)
            ),
            hover: .init(
                panel: GlassPanelToken(
                    fill: Color(.sRGB, red: 0.440, green: 0.920, blue: 0.720, opacity: 0.17),
                    stroke: .init(color: Color(.sRGB, red: 0.760, green: 1.000, blue: 0.920, opacity: 0.30), width: 1),
                    highlight: .init(startX: 0.5, startY: 0, endX: 0.5, endY: 1, stops: [
                        .init(color: Color(.sRGB, red: 0.94, green: 1.00, blue: 0.98, opacity: 0.26), location: 0),
                        .init(color: Color(.sRGB, red: 0.94, green: 1.00, blue: 0.98, opacity: 0), location: 1),
                    ]),
                    innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.22), x: 0, y: 1, blur: 1.2, lineWidth: 1),
                    noiseOpacity: 0
                ),
                textColor: Color(.sRGB, red: 0.950, green: 1.000, blue: 0.985, opacity: 0.99)
            ),
            pressed: .init(
                panel: GlassPanelToken(
                    fill: Color(.sRGB, red: 0.360, green: 0.800, blue: 0.620, opacity: 0.18),
                    stroke: .init(color: Color(.sRGB, red: 0.680, green: 0.950, blue: 0.860, opacity: 0.22), width: 1),
                    highlight: .init(startX: 0.5, startY: 0, endX: 0.5, endY: 1, stops: [
                        .init(color: Color(.sRGB, red: 0.94, green: 1.00, blue: 0.98, opacity: 0.12), location: 0),
                        .init(color: Color(.sRGB, red: 0.94, green: 1.00, blue: 0.98, opacity: 0), location: 1),
                    ]),
                    innerShadow: .init(color: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.28), x: 0, y: 1, blur: 1.0, lineWidth: 1),
                    noiseOpacity: 0
                ),
                textColor: Color(.sRGB, red: 0.920, green: 1.000, blue: 0.975, opacity: 0.96)
            ),
            metrics: .init(
                cornerRadius: 10,
                minHeight: 30,
                horizontalPadding: 12,
                verticalPadding: 5,
                fontSize: 12,
                fontWeight: .semibold,
                pressedScale: 0.985
            )
        )
    }
}

struct GlassStrokeToken {
    let color: Color
    let width: CGFloat
}

struct GlassHighlightGradientToken {
    let startX: Double
    let startY: Double
    let endX: Double
    let endY: Double
    let stops: [Gradient.Stop]

    var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .init(x: startX, y: startY),
            endPoint: .init(x: endX, y: endY)
        )
    }
}

struct GlassInnerShadowToken {
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat
    let lineWidth: CGFloat
}

struct GlassPanelToken {
    let fill: Color
    let stroke: GlassStrokeToken
    let highlight: GlassHighlightGradientToken
    let innerShadow: GlassInnerShadowToken
    let noiseOpacity: Double
}

struct GlassButtonVisualToken {
    let panel: GlassPanelToken
    let textColor: Color
}

struct GlassButtonMetricsToken {
    let cornerRadius: CGFloat
    let minHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let pressedScale: CGFloat
}

struct GlassButtonTokenSet {
    let normal: GlassButtonVisualToken
    let hover: GlassButtonVisualToken
    let pressed: GlassButtonVisualToken
    let metrics: GlassButtonMetricsToken
}
