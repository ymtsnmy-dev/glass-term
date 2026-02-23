import SwiftUI

enum GlassTheme {
    static let value = Theme(
        id: "glass",
        name: "Glass",
        backgroundStyle: .glass,
        terminalBackgroundColor: .black,
        blockCardBackground: GlassTokens.BlockCard.panelStyle.fill,
        blockCardCornerRadius: GlassTokens.BlockCard.cornerRadius,
        blockCardBorder: ThemeBorderStyle(
            color: GlassTokens.BlockCard.panelStyle.stroke.color,
            lineWidth: GlassTokens.BlockCard.panelStyle.stroke.width
        ),
        blockPrimaryTextColor: GlassTokens.Text.blockPrimary,
        blockSecondaryTextColor: GlassTokens.Text.blockSecondary,
        blockStderrTextColor: GlassTokens.Text.blockStderr
    )
}
