import SwiftUI

enum DefaultTheme {
    static let value = Theme(
        id: "default",
        name: "Default",
        backgroundStyle: .solid,
        terminalBackgroundColor: .black,
        blockCardBackground: Color.white.opacity(0.06),
        blockCardCornerRadius: 12,
        blockCardBorder: nil,
        blockPrimaryTextColor: .white,
        blockSecondaryTextColor: Color.white.opacity(0.72),
        blockStderrTextColor: Color.red.opacity(0.9)
    )
}
