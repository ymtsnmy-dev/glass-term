import CoreGraphics
import Combine
import Foundation

public enum DisplayMode: Sendable, Equatable {
    case blockMode
    case rawMode
}

@MainActor
public final class TerminalSessionController: ObservableObject {
    @Published public private(set) var renderVersion: UInt64 = 0
    @Published public private(set) var startupError: String?
    @Published public private(set) var viewportOffsetRows: Int = 0
    @Published public private(set) var windowTitle: String = "glass-term"
    @Published public private(set) var bellSequence: UInt64 = 0
    @Published public private(set) var displayMode: DisplayMode = .blockMode
    @Published public private(set) var isProcessTerminated = false
    @Published public private(set) var processExitCode: Int32?
    @Published public private(set) var trackedWorkingDirectoryPath: String?

    public let process: PTYProcess
    public let emulator: TerminalEmulator
    public let blockBoundaryManager: BlockBoundaryManager
    let copyQueueManager = CopyQueueManager()
    public var onProcessTermination: ((Int32?) -> Void)?

    public var blocks: [Block] {
        blockBoundaryManager.blocks
    }

    public var activeBlock: Block? {
        blockBoundaryManager.activeBlock
    }

    public var currentDirectoryDisplayName: String {
        if let pathToken = currentDirectoryPathToken(from: windowTitle) {
            return condensedPathTail(from: pathToken)
        }
        if let trackedWorkingDirectoryPath, !trackedWorkingDirectoryPath.isEmpty {
            return condensedPathTail(from: trackedWorkingDirectoryPath)
        }
        if let initialWorkingDirectory, !initialWorkingDirectory.isEmpty {
            return condensedPathTail(from: initialWorkingDirectory)
        }
        return "~"
    }

    public var currentDirectoryPath: String? {
        if let pathToken = currentDirectoryPathToken(from: windowTitle),
           let resolved = resolvedPath(from: pathToken) {
            return resolved
        }
        if let trackedWorkingDirectoryPath, !trackedWorkingDirectoryPath.isEmpty {
            return resolvedPath(from: trackedWorkingDirectoryPath) ?? trackedWorkingDirectoryPath
        }
        if let initialWorkingDirectory, !initialWorkingDirectory.isEmpty {
            return resolvedPath(from: initialWorkingDirectory) ?? initialWorkingDirectory
        }
        return nil
    }

    private let bridge: PTYEmulatorBridge
    private let scrollbackBuffer: ScrollbackBuffer
    private let initialWorkingDirectory: String?
    private var previousTrackedWorkingDirectoryPath: String?
    private var latestBuffer: ScreenBuffer
    private var latestCombinedLines: [ScreenLine]
    private var latestCombinedBaseAbsoluteLineIndex: Int = 0
    private var hasStarted = false
    private var lastRequestedSize: (rows: Int, cols: Int)?
    private var loggedFirstRenderableBuffer = false
    private var preciseScrollCarry: CGFloat = 0
    private var pendingCommandLine = ""
    private var inputEscapeState: InputEscapeState = .none
    private var isAlternateScreenActive = false
    private var hasTerminatedBridge = false
    public init(
        initialRows: Int = 24,
        initialCols: Int = 80,
        shellPath: String = "/bin/zsh",
        env: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let bridge = PTYEmulatorBridge(
            rows: initialRows,
            cols: initialCols,
            shellPath: shellPath,
            env: env
        )

        self.bridge = bridge
        self.process = bridge.process
        self.emulator = bridge.emulator
        self.blockBoundaryManager = BlockBoundaryManager()
        self.scrollbackBuffer = ScrollbackBuffer(capacity: 10_000)
        let launchWorkingDirectory = env["PWD"].flatMap { value in
            value.isEmpty ? nil : value
        } ?? FileManager.default.currentDirectoryPath
        self.initialWorkingDirectory = launchWorkingDirectory
        self.trackedWorkingDirectoryPath = launchWorkingDirectory
        let initialBuffer = bridge.snapshot()
        self.latestBuffer = initialBuffer
        self.latestCombinedLines = initialBuffer.visibleLines()
        self.latestCombinedBaseAbsoluteLineIndex = 0
        self.isAlternateScreenActive = initialBuffer.isAlternate
        self.displayMode = initialBuffer.isAlternate ? .rawMode : .blockMode
        self.blockBoundaryManager.displayModeChanged(self.displayMode)

        let scrollbackBuffer = self.scrollbackBuffer
        let blockBoundaryManager = self.blockBoundaryManager
        bridge.emulator.onScrollbackLine = { line in
            scrollbackBuffer.append(line)
#if DEBUG
            print("[BLOCK] committed line: \(screenLinePlainText(line))")
#endif
        }
        bridge.emulator.onScrollbackCleared = {
            scrollbackBuffer.clear()
        }
        bridge.onPTYOutput = { data in
            blockBoundaryManager.processPTYOutput(data)
        }

        bridge.screenUpdateHandlerQueue = .main
        bridge.processExitHandlerQueue = .main
        bridge.onAlternateScreenChanged = { [weak self] isAlternate in
            self?.handleAlternateScreenChanged(isAlternate: isAlternate)
        }
        bridge.onScreenBufferUpdated = { [weak self] updatedBuffer in
            self?.applyUpdatedBuffer(updatedBuffer)
        }
        bridge.onProcessExit = { [weak self] code in
            self?.handleProcessExit(code)
        }

        startIfNeeded()
    }

    public func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            try bridge.start()
            applyUpdatedBuffer(bridge.snapshot())
        } catch {
            report(error)
        }
    }

    public func snapshot() -> ScreenBuffer {
        latestBuffer
    }

    public func terminate() {
        guard !hasTerminatedBridge else { return }
        hasTerminatedBridge = true
        bridge.terminate()
    }

    public func combinedBuffer() -> [ScreenLine] {
        latestCombinedLines
    }

    public func maxViewportOffsetRows() -> Int {
        max(0, latestCombinedLines.count - latestBuffer.rows)
    }

    public func setViewportOffsetRows(_ offset: Int) {
        let clamped = clampViewportOffset(offset)
        guard viewportOffsetRows != clamped else { return }
        viewportOffsetRows = clamped
        renderVersion &+= 1
    }

    @discardableResult
    public func scrollViewport(deltaY: CGFloat, precise: Bool) -> Bool {
        let rows = scrollRowDelta(deltaY: deltaY, precise: precise)
        guard rows != 0 else { return false }
        let beforeOffset = viewportOffsetRows
        setViewportOffsetRows(viewportOffsetRows + rows)
        let moved = viewportOffsetRows != beforeOffset
        if !moved, precise {
            preciseScrollCarry = 0
        }
        return moved
    }

    public func handlePointerScroll(deltaY: CGFloat, precise: Bool) {
        guard deltaY != 0 else { return }
        let buffer = latestBuffer
        let rows = scrollRowDelta(deltaY: deltaY, precise: precise)
        guard rows != 0 else { return }

        if buffer.isAlternate {
            let steps = abs(rows)
            let sequence = rows > 0 ? "\u{1B}[5~" : "\u{1B}[6~"
            sendInput(String(repeating: sequence, count: steps))
            return
        }

        let beforeOffset = viewportOffsetRows
        setViewportOffsetRows(viewportOffsetRows + rows)
        if viewportOffsetRows == beforeOffset, precise {
            preciseScrollCarry = 0
        }
    }

    public func handlePointerCursorMove(targetDisplayRow: Int, targetCol: Int) {
        let buffer = latestBuffer
        guard buffer.rows > 0, buffer.cols > 0 else { return }

        let clampedCol = min(max(0, targetCol), buffer.cols - 1)
        let scrollbackRows = max(0, latestCombinedLines.count - buffer.rows)
        let targetDisplayMin = scrollbackRows
        let targetDisplayMax = scrollbackRows + buffer.rows - 1
        guard targetDisplayRow >= targetDisplayMin, targetDisplayRow <= targetDisplayMax else {
            return
        }

        let targetRow = targetDisplayRow - scrollbackRows
        let cursor = buffer.cursor

        var sequence = ""
        if buffer.isAlternate {
            let rowDelta = targetRow - cursor.row
            if rowDelta < 0 {
                sequence += String(repeating: "\u{1B}[A", count: -rowDelta)
            } else if rowDelta > 0 {
                sequence += String(repeating: "\u{1B}[B", count: rowDelta)
            }
        }

        let colDelta = clampedCol - cursor.col
        if colDelta < 0 {
            sequence += String(repeating: "\u{1B}[D", count: -colDelta)
        } else if colDelta > 0 {
            sequence += String(repeating: "\u{1B}[C", count: colDelta)
        }

        guard !sequence.isEmpty else { return }
        sendInput(sequence)
    }

    public func sendInput(_ text: String) {
        guard !text.isEmpty else { return }
        scrollViewportToBottom()

        do {
            try bridge.write(text)
            recordInputForBlockBoundary(text)
        } catch {
            report(error)
        }
    }

    public func sendPaste(_ text: String) {
        guard !text.isEmpty else { return }
        scrollViewportToBottom()

        if latestBuffer.isBracketedPasteEnabled {
            sendInput("\u{1B}[200~\(text)\u{1B}[201~")
        } else {
            sendInput(text)
        }
    }

    public func sendCtrlC() {
        scrollViewportToBottom()
        do {
            try bridge.sendCtrlC()
        } catch {
            report(error)
        }
    }

    public func resizeIfNeeded(viewSize: CGSize, cellSize: CGSize) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        guard cellSize.width > 0, cellSize.height > 0 else { return }

        let cols = max(1, Int(floor(viewSize.width / cellSize.width)))
        let rows = max(1, Int(floor(viewSize.height / cellSize.height)))

        if let lastRequestedSize,
           lastRequestedSize.rows == rows,
           lastRequestedSize.cols == cols {
            return
        }
        lastRequestedSize = (rows: rows, cols: cols)

        do {
            try bridge.resize(rows: rows, cols: cols)
        } catch {
            bridge.emulator.resize(rows: rows, cols: cols)
            applyUpdatedBuffer(bridge.snapshot())
            report(error)
        }
    }

    private func applyUpdatedBuffer(_ buffer: ScreenBuffer) {
        let previousScrollbackRows = max(0, latestCombinedLines.count - latestBuffer.rows)
        let previousOffset = viewportOffsetRows

        latestBuffer = buffer
        windowTitle = buffer.windowTitle.isEmpty ? "glass-term" : buffer.windowTitle
        bellSequence = buffer.bellSequence

        if buffer.isAlternate {
            latestCombinedBaseAbsoluteLineIndex = 0
            latestCombinedLines = buffer.visibleLines()
        } else {
            let scrollbackSnapshot = scrollbackBuffer.snapshotWithBaseAbsoluteIndex()
            let scrollbackLines = scrollbackSnapshot.lines
            var combined: [ScreenLine] = []
            combined.reserveCapacity(scrollbackLines.count + buffer.rows)
            combined.append(contentsOf: scrollbackLines)
            combined.append(contentsOf: buffer.visibleLines())
            latestCombinedBaseAbsoluteLineIndex = scrollbackSnapshot.baseAbsoluteIndex
            latestCombinedLines = combined
        }

        if buffer.isAlternate {
            viewportOffsetRows = 0
        } else if previousOffset > 0 {
            let currentScrollbackRows = max(0, latestCombinedLines.count - buffer.rows)
            let pushedRows = max(0, currentScrollbackRows - previousScrollbackRows)
            viewportOffsetRows = clampViewportOffset(previousOffset + pushedRows)
        } else {
            viewportOffsetRows = 0
        }

        finalizePendingBlockIfNeeded()
        renderVersion &+= 1

        guard !loggedFirstRenderableBuffer else { return }
        for row in 0..<buffer.rows {
            let text = buffer.rowText(row).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                loggedFirstRenderableBuffer = true
                if let data = "[TerminalSessionController] first renderable row=\(row) text=\(text)\n".data(using: .utf8) {
                    FileHandle.standardError.write(data)
                }
                break
            }
        }
    }

    private func report(_ error: Error) {
        let message = String(describing: error)
        startupError = message
        if let data = "[TerminalSessionController] \(message)\n".data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private func clampViewportOffset(_ offset: Int) -> Int {
        let maxOffset = maxViewportOffsetRows()
        return min(max(0, offset), maxOffset)
    }

    private func scrollViewportToBottom() {
        guard viewportOffsetRows != 0 else { return }
        viewportOffsetRows = 0
        renderVersion &+= 1
    }

    private func scrollRowDelta(deltaY: CGFloat, precise: Bool) -> Int {
        guard deltaY != 0 else {
            return 0
        }

        if !precise {
            preciseScrollCarry = 0
            let magnitude = max(1, Int(round(abs(deltaY))))
            return deltaY > 0 ? magnitude : -magnitude
        }

        preciseScrollCarry += deltaY / 10
        if preciseScrollCarry >= 1 {
            let rows = Int(floor(preciseScrollCarry))
            preciseScrollCarry -= CGFloat(rows)
            return rows
        }
        if preciseScrollCarry <= -1 {
            let rows = Int(ceil(preciseScrollCarry))
            preciseScrollCarry -= CGFloat(rows)
            return rows
        }
        return 0
    }

    private func handleAlternateScreenChanged(isAlternate: Bool) {
        isAlternateScreenActive = isAlternate

        let nextDisplayMode: DisplayMode = isAlternate ? .rawMode : .blockMode
        if displayMode != nextDisplayMode {
            displayMode = nextDisplayMode
        }
        blockBoundaryManager.displayModeChanged(nextDisplayMode)

        if isAlternate {
            pendingCommandLine.removeAll(keepingCapacity: true)
            inputEscapeState = .none
        }
    }

    private func handleProcessExit(_ code: Int32?) {
        isProcessTerminated = true
        processExitCode = code
        renderVersion &+= 1
        onProcessTermination?(code)
    }

    private func recordInputForBlockBoundary(_ text: String) {
        guard !isAlternateScreenActive else { return }

        for scalar in text.unicodeScalars {
            switch inputEscapeState {
            case .none:
                if scalar.value == 0x1B {
                    inputEscapeState = .escape
                    continue
                }

                if scalar.value == 0x0D || scalar.value == 0x0A {
                    updateTrackedWorkingDirectoryIfNeeded(forSubmittedCommand: pendingCommandLine)
                    blockBoundaryManager.registerUserInput(
                        pendingCommandLine,
                        outputStartAbsoluteLineIndex: currentBlockOutputStartAbsoluteLineIndex()
                    )
                    pendingCommandLine.removeAll(keepingCapacity: true)
                    continue
                }

                if scalar.value == 0x08 || scalar.value == 0x7F {
                    if !pendingCommandLine.isEmpty {
                        pendingCommandLine.removeLast()
                    }
                    continue
                }

                if scalar.value == 0x09 {
                    pendingCommandLine.append("\t")
                    continue
                }

                if scalar.value >= 0x20, scalar.value != 0x7F {
                    pendingCommandLine.unicodeScalars.append(scalar)
                }

            case .escape:
                if scalar.value == 0x5B {
                    inputEscapeState = .csi
                } else {
                    inputEscapeState = .none
                }

            case .csi:
                if scalar.value >= 0x40, scalar.value <= 0x7E {
                    inputEscapeState = .none
                }
            }
        }
    }

    private enum InputEscapeState {
        case none
        case escape
        case csi
    }

    private func currentBlockOutputStartAbsoluteLineIndex() -> Int {
        let scrollbackRows = max(0, latestCombinedLines.count - latestBuffer.rows)
        let cursorRow = min(max(0, latestBuffer.cursor.row), max(0, latestBuffer.rows - 1))
        let currentAbsoluteLineIndex = latestCombinedBaseAbsoluteLineIndex + scrollbackRows + cursorRow
        return currentAbsoluteLineIndex + 1
    }

    private func finalizePendingBlockIfNeeded() {
        guard displayMode == .blockMode else { return }

        while let request = blockBoundaryManager.consumePendingBlockFinalizationRequest() {
            let endAbsoluteLineIndex = currentPromptAbsoluteLineIndex()
            let extraction = extractBlockStdout(
                startAbsoluteLineIndex: request.outputStartAbsoluteLineIndex,
                endAbsoluteLineIndex: endAbsoluteLineIndex,
                command: request.command
            )
#if DEBUG
            print("[BLOCK] text-range start=\(request.outputStartAbsoluteLineIndex) end=\(endAbsoluteLineIndex) lines=\(extraction.lineCount)")
            print("[BLOCK] stdoutChars=\(extraction.stdout.count) utf8Bytes=\(extraction.stdout.utf8.count)")
#endif
            blockBoundaryManager.completePendingBlock(exitCode: request.exitCode, stdout: extraction.stdout)
        }
    }

    private func extractBlockStdout(
        startAbsoluteLineIndex: Int,
        endAbsoluteLineIndex: Int,
        command: String
    ) -> (stdout: String, lineCount: Int) {
        let clampedStart = max(startAbsoluteLineIndex, latestCombinedBaseAbsoluteLineIndex)
        let clampedEnd = max(clampedStart, endAbsoluteLineIndex)
        let startOffset = clampedStart - latestCombinedBaseAbsoluteLineIndex
        let endOffset = min(clampedEnd - latestCombinedBaseAbsoluteLineIndex, latestCombinedLines.count)

        guard startOffset < endOffset else { return ("", 0) }

        var outputLines: [String] = []
        outputLines.reserveCapacity(endOffset - startOffset)

        for index in startOffset..<endOffset {
            outputLines.append(normalizedBlockOutputLine(screenLinePlainText(latestCombinedLines[index])))
        }

        while let first = outputLines.first, isCommandEchoLine(first, command: command) {
            outputLines.removeFirst()
        }

        let stdout: String
        if outputLines.isEmpty {
            stdout = ""
        } else {
            // Completed command output ends before the next prompt row, so rows are line-terminated.
            stdout = outputLines.joined(separator: "\n") + "\n"
        }
        return (stdout, outputLines.count)
    }

    private func currentPromptAbsoluteLineIndex() -> Int {
        let scrollbackRows = max(0, latestCombinedLines.count - latestBuffer.rows)
        let cursorRow = min(max(0, latestBuffer.cursor.row), max(0, latestBuffer.rows - 1))
        return latestCombinedBaseAbsoluteLineIndex + scrollbackRows + cursorRow
    }

    private func isPromptMarkerLine(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).hasPrefix("<<<BLOCK_PROMPT>>>:")
    }

    private func isCommandEchoLine(_ text: String, command: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if command.isEmpty {
            return false
        }
        return trimmed == command || trimmed == "$ \(command)"
    }

    private func normalizedBlockOutputLine(_ text: String) -> String {
        var line = text
        while let last = line.last, last == " " || last == "\t" {
            line.removeLast()
        }
        return line
    }

    private func currentDirectoryPathToken(from windowTitle: String) -> String? {
        windowTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
            .reversed()
            .first(where: looksLikePathToken)
    }

    private func looksLikePathToken(_ token: String) -> Bool {
        token.contains("/") || token == "~" || token.hasPrefix("~/")
    }

    private func condensedPathTail(from token: String) -> String {
        let cleaned = cleanedPathToken(token)
        if cleaned == "~" { return "~" }
        if cleaned.hasPrefix("~/") {
            let tail = String(cleaned.dropFirst(2)).split(separator: "/").last.map(String.init) ?? ""
            return tail.isEmpty ? "~" : "~/" + tail
        }
        let tail = cleaned.split(separator: "/").last.map(String.init) ?? cleaned
        return tail.isEmpty ? cleaned : tail
    }

    private func resolvedPath(from token: String) -> String? {
        let cleaned = cleanedPathToken(token)
        guard !cleaned.isEmpty else { return nil }
        if cleaned == "~" {
            return NSHomeDirectory()
        }
        if cleaned.hasPrefix("~/") {
            return (NSHomeDirectory() as NSString).appendingPathComponent(String(cleaned.dropFirst(2)))
        }
        if cleaned.hasPrefix("/") {
            return cleaned
        }
        return nil
    }

    private func cleanedPathToken(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet(charactersIn: "[](){}<>:,;"))
    }

    private func updateTrackedWorkingDirectoryIfNeeded(forSubmittedCommand command: String) {
        guard let nextPath = resolvedWorkingDirectoryAfterCD(command) else { return }
        guard nextPath != trackedWorkingDirectoryPath else { return }
        previousTrackedWorkingDirectoryPath = trackedWorkingDirectoryPath
        trackedWorkingDirectoryPath = nextPath
    }

    private func resolvedWorkingDirectoryAfterCD(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let separators = ["&&", "||", ";", "|"]
        guard separators.allSatisfy({ !trimmed.contains($0) }) else { return nil }

        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !parts.isEmpty, parts[0] == "cd", parts.count <= 2 else { return nil }

        if parts.count == 1 {
            return NSHomeDirectory()
        }

        let argument = parts[1]
        if argument == "-" {
            return previousTrackedWorkingDirectoryPath ?? trackedWorkingDirectoryPath
        }

        if let resolved = resolvedPath(from: argument) {
            return (resolved as NSString).standardizingPath
        }

        let base = trackedWorkingDirectoryPath ?? initialWorkingDirectory ?? NSHomeDirectory()
        return ((base as NSString).appendingPathComponent(argument) as NSString).standardizingPath
    }

}
