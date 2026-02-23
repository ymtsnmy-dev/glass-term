import CoreGraphics
import Combine
import Foundation

@MainActor
public final class TerminalSessionController: ObservableObject {
    @Published public private(set) var renderVersion: UInt64 = 0
    @Published public private(set) var startupError: String?
    @Published public private(set) var viewportOffsetRows: Int = 0
    @Published public private(set) var windowTitle: String = "glass-term"
    @Published public private(set) var bellSequence: UInt64 = 0

    public let process: PTYProcess
    public let emulator: TerminalEmulator
    public let blockBoundaryManager: BlockBoundaryManager

    public var blocks: [Block] {
        blockBoundaryManager.blocks
    }

    public var activeBlock: Block? {
        blockBoundaryManager.activeBlock
    }

    private let bridge: PTYEmulatorBridge
    private let scrollbackBuffer: ScrollbackBuffer
    private var latestBuffer: ScreenBuffer
    private var latestCombinedLines: [ScreenLine]
    private var hasStarted = false
    private var lastRequestedSize: (rows: Int, cols: Int)?
    private var loggedFirstRenderableBuffer = false
    private var preciseScrollCarry: CGFloat = 0
    private var pendingCommandLine = ""
    private var inputEscapeState: InputEscapeState = .none
    private var isAlternateScreenActive = false
    private var lastSentPromptRowTextForBlockFeed: String?
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
        let initialBuffer = bridge.snapshot()
        self.latestBuffer = initialBuffer
        self.latestCombinedLines = initialBuffer.visibleLines()
        self.isAlternateScreenActive = initialBuffer.isAlternate
        self.blockBoundaryManager.alternateScreenChanged(isActive: initialBuffer.isAlternate)

        let scrollbackBuffer = self.scrollbackBuffer
        let blockBoundaryManager = self.blockBoundaryManager
        let plainTextLine: (ScreenLine) -> String = { line in
            var text = ""
            text.reserveCapacity(line.count)
            for cell in line where cell.width > 0 {
                text += cell.text
            }
            return text
        }
        bridge.emulator.onScrollbackLine = { line in
            scrollbackBuffer.append(line)
            let committedLine = plainTextLine(line)
#if DEBUG
            print("[BLOCK] committed line: \(committedLine)")
#endif
            blockBoundaryManager.processOutput(committedLine + "\n")
        }
        bridge.emulator.onScrollbackCleared = {
            scrollbackBuffer.clear()
        }

        bridge.screenUpdateHandlerQueue = .main
        bridge.processExitHandlerQueue = .main
        bridge.onScreenBufferUpdated = { [weak self] updatedBuffer in
            self?.applyUpdatedBuffer(updatedBuffer)
        }
        bridge.onProcessExit = { [weak self] _ in
            self?.renderVersion &+= 1
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
        if isAlternateScreenActive != buffer.isAlternate {
            isAlternateScreenActive = buffer.isAlternate
            blockBoundaryManager.alternateScreenChanged(isActive: buffer.isAlternate)
            lastSentPromptRowTextForBlockFeed = nil
            if buffer.isAlternate {
                pendingCommandLine.removeAll(keepingCapacity: true)
                inputEscapeState = .none
            }
        }
        windowTitle = buffer.windowTitle.isEmpty ? "glass-term" : buffer.windowTitle
        bellSequence = buffer.bellSequence

        if buffer.isAlternate {
            latestCombinedLines = buffer.visibleLines()
        } else {
            let scrollbackLines = scrollbackBuffer.snapshot()
            var combined: [ScreenLine] = []
            combined.reserveCapacity(scrollbackLines.count + buffer.rows)
            combined.append(contentsOf: scrollbackLines)
            combined.append(contentsOf: buffer.visibleLines())
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

        renderVersion &+= 1
        feedPromptCursorRowToBlockBoundary(buffer)

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
                    blockBoundaryManager.registerUserInput(pendingCommandLine)
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

    private func feedPromptCursorRowToBlockBoundary(_ buffer: ScreenBuffer) {
        guard !buffer.isAlternate else {
            lastSentPromptRowTextForBlockFeed = nil
            return
        }

        guard buffer.rows > 0 else {
            lastSentPromptRowTextForBlockFeed = nil
            return
        }

        let promptRowText = buffer.rowText(buffer.cursor.row)
        guard isStandalonePromptMarkerRow(promptRowText) else {
            lastSentPromptRowTextForBlockFeed = nil
            return
        }

        guard lastSentPromptRowTextForBlockFeed != promptRowText else { return }
        lastSentPromptRowTextForBlockFeed = promptRowText

#if DEBUG
        print("[BLOCK] prompt row sent: \(promptRowText)")
#endif
        blockBoundaryManager.processOutput(promptRowText + "\n")
    }

    private func isStandalonePromptMarkerRow(_ text: String) -> Bool {
        let prefix = "<<<BLOCK_PROMPT>>>:"
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(prefix) else { return false }

        var suffix = String(trimmed.dropFirst(prefix.count))
        if suffix.first == "-" {
            suffix.removeFirst()
        }

        guard !suffix.isEmpty else { return false }
        return suffix.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

}
