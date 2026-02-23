import SwiftUI

struct InputBarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var commandText = ""
    @FocusState private var isCommandFieldFocused: Bool

    let onFocusCommandField: () -> Void
    let onSubmitCommand: (String) -> Void

    init(
        onFocusCommandField: @escaping () -> Void = {},
        onSubmitCommand: @escaping (String) -> Void
    ) {
        self.onFocusCommandField = onFocusCommandField
        self.onSubmitCommand = onSubmitCommand
    }

    var body: some View {
        let isGlass = themeManager.activeTheme.isGlass

        HStack(spacing: 8) {
            Text("$")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isGlass ? GlassTokens.InputBar.prompt : .secondary)

            TextField("Type a command", text: $commandText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isGlass ? GlassTokens.InputBar.text : .primary)
                .focused($isCommandFieldFocused)
                .onSubmit(submit)
                .onChange(of: isCommandFieldFocused) { _, isFocused in
                    guard isFocused else { return }
                    onFocusCommandField()
                }

            Button("Run", action: submit)
                .disabled(trimmedCommand.isEmpty)
                .if(isGlass) { view in
                    view.buttonStyle(GlassButtonStyle(tokenSet: GlassTokens.ChromeButtons.runStates))
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            if isGlass {
                Color.clear
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .if(isGlass) { view in
            view
                .glassSurface(.inputBar(isFocused: isCommandFieldFocused))
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GlassTokens.Accent.primary.opacity(isCommandFieldFocused ? 0.14 : 0.0), lineWidth: 1)
                        .blur(radius: isCommandFieldFocused ? 5 : 0)
                        .opacity(isCommandFieldFocused ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .animation(.easeInOut(duration: 0.15), value: isCommandFieldFocused)
        }
    }

    private var trimmedCommand: String {
        commandText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        let command = trimmedCommand
        guard !command.isEmpty else { return }
        onSubmitCommand(command)
        commandText = ""
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
