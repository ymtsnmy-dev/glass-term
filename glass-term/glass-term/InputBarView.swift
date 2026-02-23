import SwiftUI

struct InputBarView: View {
    @State private var commandText = ""

    let onSubmitCommand: (String) -> Void

    init(onSubmitCommand: @escaping (String) -> Void) {
        self.onSubmitCommand = onSubmitCommand
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            TextField("Type a command", text: $commandText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .onSubmit(submit)

            Button("Run", action: submit)
                .disabled(trimmedCommand.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
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
