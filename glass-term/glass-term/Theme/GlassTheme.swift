import SwiftUI

enum GlassTheme {
    static let value = Theme(
        id: "glass",
        name: "Glass",
        backgroundStyle: .glass,
        terminalBackgroundColor: .black,
        blockCardBackground: Color.white.opacity(0.10),
        blockCardCornerRadius: 18,
        blockCardBorder: ThemeBorderStyle(color: Color.white.opacity(0.16), lineWidth: 1),
        blockPrimaryTextColor: .white,
        blockSecondaryTextColor: Color.white.opacity(0.78),
        blockStderrTextColor: Color.red.opacity(0.92)
    )
}
