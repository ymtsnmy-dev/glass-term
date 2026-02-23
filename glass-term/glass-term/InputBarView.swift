import AppKit
import SwiftUI

struct InputBarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var commandText = ""
    @State private var isCommandFieldFocused = false
    @State private var completions: [CommandCompletionSuggestion] = []
    @State private var selectedCompletionIndex = 0

    let workingDirectoryDisplay: String
    let completionBaseDirectoryPath: String?
    let onFocusCommandField: () -> Void
    let onSubmitCommand: (String) -> Void

    init(
        workingDirectoryDisplay: String = "~",
        completionBaseDirectoryPath: String? = nil,
        onFocusCommandField: @escaping () -> Void = {},
        onSubmitCommand: @escaping (String) -> Void
    ) {
        self.workingDirectoryDisplay = workingDirectoryDisplay
        self.completionBaseDirectoryPath = completionBaseDirectoryPath
        self.onFocusCommandField = onFocusCommandField
        self.onSubmitCommand = onSubmitCommand
    }

    var body: some View {
        let isGlass = themeManager.activeTheme.isGlass

        HStack(spacing: 8) {
            Text(workingDirectoryDisplay)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isGlass ? GlassTokens.InputBar.text.opacity(0.8) : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(workingDirectoryDisplay)

            Text("$")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isGlass ? GlassTokens.InputBar.prompt : .secondary)

            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .leading) {
                    if commandText.isEmpty {
                        Image(systemName: "terminal")
                            .foregroundStyle(isGlass ? GlassTokens.InputBar.text.opacity(0.5) : .secondary)
                            .allowsHitTesting(false)
                    }

                    CommandInputTextField(
                        text: $commandText,
                        isFocused: $isCommandFieldFocused,
                        onSubmit: submit,
                        onTab: handleTabCompletion,
                        onMoveUp: { handleCompletionSelectionMove(delta: -1) },
                        onMoveDown: { handleCompletionSelectionMove(delta: 1) }
                    )
                    .frame(height: 22)
                    .accessibilityLabel("Command input")
                    .help("Command input")
                }

                if !completions.isEmpty {
                    completionList(isGlass: isGlass)
                }
            }
            .onChange(of: commandText) { _, _ in
                if !completions.isEmpty {
                    completions = []
                    selectedCompletionIndex = 0
                }
            }
            .onChange(of: isCommandFieldFocused) { _, isFocused in
                if isFocused {
                    onFocusCommandField()
                } else {
                    completions = []
                    selectedCompletionIndex = 0
                }
            }

            Button(action: submit) {
                Label("Run command", systemImage: "play.fill")
                    .labelStyle(.iconOnly)
            }
            .help("Run command")
            .accessibilityLabel("Run command")
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
                        .fill(
                            RadialGradient(
                                colors: [
                                    GlassTokens.Accent.primary.opacity(isCommandFieldFocused ? 0.07 : 0.0),
                                    Color.clear,
                                ],
                                center: .leading,
                                startRadius: 4,
                                endRadius: 72
                            )
                        )
                        .opacity(isCommandFieldFocused ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GlassTokens.Accent.primary.opacity(isCommandFieldFocused ? 0.13 : 0.0), lineWidth: 1)
                        .blur(radius: isCommandFieldFocused ? 4 : 0)
                        .opacity(isCommandFieldFocused ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .animation(.easeInOut(duration: 0.14), value: isCommandFieldFocused)
        }
    }

    private var trimmedCommand: String {
        commandText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func completionList(isGlass: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(completions.indices, id: \.self) { index in
                let suggestion = completions[index]
                Button {
                    applyCompletion(at: index)
                } label: {
                    CompletionSuggestionRow(
                        suggestion: suggestion,
                        isSelected: index == selectedCompletionIndex,
                        isGlass: isGlass
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isGlass ? GlassTokens.InputBar.panel.fill : Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isGlass ? GlassTokens.InputBar.text.opacity(0.08) : Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func submit() {
        let command = trimmedCommand
        guard !command.isEmpty else { return }
        onSubmitCommand(command)
        commandText = ""
        completions = []
        selectedCompletionIndex = 0
    }

    private func loadCompletions() {
        let suggestions = CommandCompletionEngine.suggestions(
            for: commandText,
            baseDirectoryPath: completionBaseDirectoryPath
        )
        completions = Array(suggestions.prefix(8))
        if completions.isEmpty {
            selectedCompletionIndex = 0
        } else {
            selectedCompletionIndex = min(selectedCompletionIndex, completions.count - 1)
        }
    }

    private func handleCompletionSelectionMove(delta: Int) -> Bool {
        guard !completions.isEmpty else { return false }
        let count = completions.count
        selectedCompletionIndex = (selectedCompletionIndex + delta % count + count) % count
        return true
    }

    private func handleTabCompletion() {
        guard isCommandFieldFocused else { return }
        if completions.isEmpty {
            loadCompletions()
            if completions.count == 1 {
                applyCompletion(at: 0)
            }
            return
        }
        applyCompletion(at: selectedCompletionIndex)
    }

    private func applyCompletion(at index: Int) {
        guard completions.indices.contains(index) else { return }
        let suggestion = completions[index]
        commandText = suggestion.replacement(commandText)
        completions = []
        selectedCompletionIndex = 0
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

private struct CommandCompletionSuggestion: Identifiable, Equatable {
    enum Kind: Equatable {
        case command
        case directory
    }

    let id: String
    let displayText: String
    let kind: Kind
    let replacement: (String) -> String

    static func == (lhs: CommandCompletionSuggestion, rhs: CommandCompletionSuggestion) -> Bool {
        lhs.id == rhs.id && lhs.displayText == rhs.displayText && lhs.kind == rhs.kind
    }
}

private struct CompletionSuggestionRow: View {
    let suggestion: CommandCompletionSuggestion
    let isSelected: Bool
    let isGlass: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(suggestion.displayText)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .foregroundStyle(isGlass ? GlassTokens.InputBar.text : .primary)

            Spacer(minLength: 0)

            if suggestion.kind == .directory {
                Text("dir")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isGlass ? GlassTokens.InputBar.text.opacity(0.65) : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectionBackground)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isGlass ? GlassTokens.Accent.primary.opacity(0.16) : Color.accentColor.opacity(0.14))
        } else {
            Color.clear
        }
    }
}

private enum CommandCompletionEngine {
    private static let builtins: [String] = [
        "cd", "pwd", "ls", "echo", "cat", "mkdir", "rm", "mv", "cp", "touch",
        "grep", "find", "git", "open", "clear", "which", "python3", "node", "npm"
    ]

    static func suggestions(for commandLine: String, baseDirectoryPath: String?) -> [CommandCompletionSuggestion] {
        if let cdContext = parseCDContext(commandLine) {
            return cdSuggestions(for: cdContext, baseDirectoryPath: baseDirectoryPath)
        }
        if let pathContext = parsePathArgumentContext(commandLine) {
            return directorySuggestions(
                token: pathContext.token,
                replacementRange: pathContext.replacementRange,
                baseDirectoryPath: baseDirectoryPath
            )
        }
        return commandNameSuggestions(for: commandLine)
    }

    private static func commandNameSuggestions(for commandLine: String) -> [CommandCompletionSuggestion] {
        guard !commandLine.contains(" ") else { return [] }
        let prefix = commandLine
        let lowerPrefix = prefix.lowercased()
        guard !lowerPrefix.isEmpty else { return [] }

        return availableCommands()
            .filter { $0.lowercased().hasPrefix(lowerPrefix) }
            .prefix(8)
            .map { name in
                CommandCompletionSuggestion(
                    id: "cmd:\(name)",
                    displayText: name,
                    kind: .command,
                    replacement: { _ in name }
                )
            }
    }

    private struct CDContext {
        let token: String
        let replacementRange: Range<String.Index>
    }

    private static func parseCDContext(_ commandLine: String) -> CDContext? {
        let trimmedLeading = commandLine.drop(while: \.isWhitespace)
        guard trimmedLeading.hasPrefix("cd") else { return nil }

        let cdEnd = trimmedLeading.index(trimmedLeading.startIndex, offsetBy: 2)
        let remainder = trimmedLeading[cdEnd...]
        guard remainder.isEmpty || remainder.first?.isWhitespace == true else { return nil }

        if remainder.isEmpty {
            return nil
        }

        let remainderStart = commandLine.index(commandLine.endIndex, offsetBy: -remainder.count)
        let tokenStart = commandLine[remainderStart...].firstIndex(where: { !$0.isWhitespace }) ?? commandLine.endIndex
        let trailing = commandLine[tokenStart...]

        guard !trailing.contains(where: \.isWhitespace) else { return nil }

        return CDContext(token: String(trailing), replacementRange: tokenStart..<commandLine.endIndex)
    }

    private static func cdSuggestions(for context: CDContext, baseDirectoryPath: String?) -> [CommandCompletionSuggestion] {
        directorySuggestions(
            token: context.token,
            replacementRange: context.replacementRange,
            baseDirectoryPath: baseDirectoryPath
        )
    }

    private struct PathArgumentContext {
        let token: String
        let replacementRange: Range<String.Index>
    }

    private static func parsePathArgumentContext(_ commandLine: String) -> PathArgumentContext? {
        guard let firstNonWhitespace = commandLine.firstIndex(where: { !$0.isWhitespace }) else {
            return nil
        }

        let tailFromFirstToken = commandLine[firstNonWhitespace...]
        guard tailFromFirstToken.contains(where: \.isWhitespace) else {
            return nil
        }

        // Keep behavior predictable: skip shell operators/quotes for now.
        if commandLine.contains("&&") || commandLine.contains("||") || commandLine.contains("|") || commandLine.contains(";") {
            return nil
        }

        let tokenStart: String.Index
        if commandLine.last?.isWhitespace == true {
            tokenStart = commandLine.endIndex
        } else {
            guard let lastWhitespace = commandLine.lastIndex(where: \.isWhitespace) else {
                return nil
            }
            tokenStart = commandLine.index(after: lastWhitespace)
        }

        let token = String(commandLine[tokenStart...])
        if token.contains("\"") || token.contains("'") {
            return nil
        }

        return PathArgumentContext(token: token, replacementRange: tokenStart..<commandLine.endIndex)
    }

    private static func directorySuggestions(
        token: String,
        replacementRange: Range<String.Index>,
        baseDirectoryPath: String?
    ) -> [CommandCompletionSuggestion] {
        let resolvedBase = (baseDirectoryPath?.isEmpty == false ? baseDirectoryPath : FileManager.default.homeDirectoryForCurrentUser.path) ?? NSHomeDirectory()
        let fm = FileManager.default

        let (searchDirectory, typedPrefix, displayPrefix) = resolveDirectorySearchContext(
            token: token,
            baseDirectoryPath: resolvedBase
        )

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: searchDirectory, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        let showHidden = typedPrefix.hasPrefix(".")
        let names: [String]
        do {
            names = try fm.contentsOfDirectory(atPath: searchDirectory)
        } catch {
            return []
        }

        let normalizedPrefix = typedPrefix.lowercased()
        let candidates = names.compactMap { name -> String? in
            guard showHidden || !name.hasPrefix(".") else { return nil }
            guard normalizedPrefix.isEmpty || name.lowercased().hasPrefix(normalizedPrefix) else { return nil }
            let fullPath = (searchDirectory as NSString).appendingPathComponent(name)
            var isChildDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isChildDir), isChildDir.boolValue else {
                return nil
            }
            return name
        }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return candidates.map { name in
            let rawPath = displayPrefix + name + "/"
            let escapedPath = shellEscapePath(rawPath)
            let displayText = rawPath
            return CommandCompletionSuggestion(
                id: "dir:\(rawPath)",
                displayText: displayText,
                kind: .directory,
                replacement: { commandLine in
                    var updated = commandLine
                    updated.replaceSubrange(replacementRange, with: escapedPath)
                    return updated
                }
            )
        }
    }

    private static func resolveDirectorySearchContext(token: String, baseDirectoryPath: String) -> (searchDirectory: String, typedPrefix: String, displayPrefix: String) {
        let expandedToken = expandTilde(token)
        let tokenNSString = expandedToken as NSString

        if token.isEmpty {
            return (baseDirectoryPath, "", "")
        }

        let hasSlash = expandedToken.contains("/")
        let endsWithSlash = expandedToken.hasSuffix("/")

        if endsWithSlash {
            let searchDirectory = absolutePath(from: expandedToken, baseDirectoryPath: baseDirectoryPath)
            let displayPrefix = token
            return (searchDirectory, "", displayPrefix)
        }

        if hasSlash {
            let directoryPart = tokenNSString.deletingLastPathComponent
            let prefixPart = tokenNSString.lastPathComponent
            let searchDirectory = absolutePath(from: directoryPart, baseDirectoryPath: baseDirectoryPath)
            let displayPrefix = directoryPart.isEmpty ? "" : directoryPart + "/"
            return (searchDirectory, prefixPart, displayPrefix)
        }

        return (baseDirectoryPath, token, "")
    }

    private static func absolutePath(from tokenPath: String, baseDirectoryPath: String) -> String {
        if tokenPath.hasPrefix("/") {
            return (tokenPath as NSString).standardizingPath
        }
        let joined = (baseDirectoryPath as NSString).appendingPathComponent(tokenPath)
        return (joined as NSString).standardizingPath
    }

    private static func expandTilde(_ token: String) -> String {
        guard token.hasPrefix("~") else { return token }
        return (token as NSString).expandingTildeInPath
    }

    private static func shellEscapePath(_ path: String) -> String {
        var escaped = ""
        let specials = CharacterSet(charactersIn: " \\\"'`()[]{}&;|<>$*?!")
        for scalar in path.unicodeScalars {
            if specials.contains(scalar) {
                escaped.append("\\")
            }
            escaped.unicodeScalars.append(scalar)
        }
        return escaped
    }

    private static func availableCommands() -> [String] {
        CommandInventory.shared.commands
    }

    private final class CommandInventory {
        static let shared = CommandInventory()
        let commands: [String]

        private init() {
            var all = Set(builtins)
            let fm = FileManager.default
            let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
                .split(separator: ":")
                .map(String.init)

            for entry in pathEntries where !entry.isEmpty {
                guard let children = try? fm.contentsOfDirectory(atPath: entry) else { continue }
                for name in children where !name.isEmpty && !name.hasPrefix(".") {
                    let fullPath = (entry as NSString).appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }
                    guard fm.isExecutableFile(atPath: fullPath) else { continue }
                    all.insert(name)
                }
            }

            commands = all.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
    }
}

private struct CommandInputTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let onSubmit: () -> Void
    let onTab: () -> Void
    let onMoveUp: () -> Bool
    let onMoveDown: () -> Bool

    func makeNSView(context: Context) -> CompletionNSTextField {
        let field = CompletionNSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.delegate = context.coordinator
        field.lineBreakMode = .byClipping
        field.maximumNumberOfLines = 1
        field.usesSingleLineMode = true
        field.stringValue = text
        DispatchQueue.main.async {
            if field.window?.firstResponder !== field {
                field.window?.makeFirstResponder(field)
            }
        }
        return field
    }

    func updateNSView(_ nsView: CompletionNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.textColor = NSColor.labelColor
        if isFocused, nsView.currentEditor() == nil {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: $isFocused,
            onSubmit: onSubmit,
            onTab: onTab,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool
        private let onSubmit: () -> Void
        private let onTab: () -> Void
        private let onMoveUp: () -> Bool
        private let onMoveDown: () -> Bool

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            onSubmit: @escaping () -> Void,
            onTab: @escaping () -> Void,
            onMoveUp: @escaping () -> Bool,
            onMoveDown: @escaping () -> Bool
        ) {
            _text = text
            _isFocused = isFocused
            self.onSubmit = onSubmit
            self.onTab = onTab
            self.onMoveUp = onMoveUp
            self.onMoveDown = onMoveDown
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let updated = field.stringValue
            if text != updated {
                text = updated
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            _ = obj
            if !isFocused {
                isFocused = true
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            _ = obj
            if isFocused {
                isFocused = false
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            _ = control
            _ = textView

            switch NSStringFromSelector(commandSelector) {
            case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
                onSubmit()
                return true
            case "insertTab:", "insertBacktab:":
                onTab()
                return true
            case "moveUp:":
                return onMoveUp()
            case "moveDown:":
                return onMoveDown()
            default:
                return false
            }
        }
    }
}

private final class CompletionNSTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
}
