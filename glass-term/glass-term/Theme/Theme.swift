import CoreGraphics
import SwiftUI

enum ThemeBackgroundStyle {
    case solid
    case glass
}

struct ThemeBorderStyle {
    let color: Color
    let lineWidth: CGFloat
}

struct Theme: Identifiable {
    let id: String
    let name: String
    let backgroundStyle: ThemeBackgroundStyle
    let terminalBackgroundColor: Color
    let blockCardBackground: Color
    let blockCardCornerRadius: CGFloat
    let blockCardBorder: ThemeBorderStyle?
    let blockPrimaryTextColor: Color
    let blockSecondaryTextColor: Color
    let blockStderrTextColor: Color
}
