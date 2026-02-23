import Combine
import Foundation

@MainActor
final class ThemeManager: ObservableObject {
    @Published var activeTheme: Theme

    init() {
        self.activeTheme = GlassTheme.value
    }

    init(initialTheme: Theme) {
        self.activeTheme = initialTheme
    }

    func setTheme(_ theme: Theme) {
        activeTheme = theme
    }

    func setDefaultTheme() {
        setTheme(DefaultTheme.value)
    }

    func setGlassTheme() {
        setTheme(GlassTheme.value)
    }

    func toggleTheme() {
        if activeTheme.id == GlassTheme.value.id {
            setDefaultTheme()
        } else {
            setGlassTheme()
        }
    }
}
