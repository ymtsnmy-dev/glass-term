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
                GlassPanelBackground(cornerRadius: 14, token: GlassTokens.InputBar.panel)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .allowsHitTesting(false)
                    }
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, GlassTokens.InputBar.borderGlow, Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 1)
                            .allowsHitTesting(false)
                    }
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .if(isGlass) { view in
            view
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
                .shadow(color: Color(.sRGB, red: 0.38, green: 0.88, blue: 1.0, opacity: 0.05), radius: 14, x: 0, y: 2)
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
