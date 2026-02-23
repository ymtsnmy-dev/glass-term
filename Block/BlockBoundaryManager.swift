import Foundation

nonisolated public final class BlockBoundaryManager {
    private enum MarkerParseResult {
        case complete(exitCode: Int, consumedCount: Int)
        case needMoreData
        case invalid
    }

    private static let promptMarkerPrefix = "<<<BLOCK_PROMPT>>>:"

    private let stateLock = NSLock()

    private var blocksStorage: [Block] = []
    private var activeBlockStorage: Block?
    private var rawModeActive = false
    private var pendingOutputBuffer = ""

    public init() {}

    public var blocks: [Block] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return blocksStorage
    }

    public var activeBlock: Block? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeBlockStorage
    }

    public func registerUserInput(_ text: String) {
        let command = text.trimmingCharacters(in: .newlines)
#if DEBUG
        print("[BLOCK] input: \(command)")
#endif

        stateLock.lock()
        defer { stateLock.unlock() }

        guard !rawModeActive else { return }
        guard activeBlockStorage == nil else { return }

        activeBlockStorage = Block(
            command: command,
            startedAt: Date(),
            status: .running
        )
    }

    public func processOutput(_ text: String) {
        guard !text.isEmpty else { return }
#if DEBUG
        if text.contains(Self.promptMarkerPrefix) {
            print("[BLOCK] output contains prompt marker: \(text)")
        }
#endif

        stateLock.lock()
        defer { stateLock.unlock() }

        guard !rawModeActive else { return }

        pendingOutputBuffer.append(text)
        processPendingOutputBufferLocked()
    }

    public func alternateScreenChanged(isActive: Bool) {
        stateLock.lock()
        rawModeActive = isActive
        if isActive {
            activeBlockStorage = nil
        }
        pendingOutputBuffer.removeAll(keepingCapacity: true)
        stateLock.unlock()
    }

    private func processPendingOutputBufferLocked() {
        while true {
            guard let markerRange = pendingOutputBuffer.range(of: Self.promptMarkerPrefix) else {
                flushNonMarkerTailLocked()
                return
            }

            let head = String(pendingOutputBuffer[..<markerRange.lowerBound])
            appendToActiveBlockStdoutLocked(head)
            pendingOutputBuffer.removeSubrange(..<markerRange.lowerBound)

            switch parseMarkerAtBufferStartLocked() {
            case let .complete(exitCode, consumedCount):
                removeLeadingCharactersLocked(consumedCount)
                finalizeActiveBlockLocked(exitCode: exitCode)
            case .needMoreData:
                return
            case .invalid:
                let firstCharacter = String(pendingOutputBuffer.removeFirst())
                appendToActiveBlockStdoutLocked(firstCharacter)
            }
        }
    }

    private func flushNonMarkerTailLocked() {
        let retainCount = trailingMarkerPrefixCandidateLength(in: pendingOutputBuffer)
        let flushCount = pendingOutputBuffer.count - retainCount
        guard flushCount > 0 else { return }

        let splitIndex = pendingOutputBuffer.index(pendingOutputBuffer.startIndex, offsetBy: flushCount)
        let flushText = String(pendingOutputBuffer[..<splitIndex])
        appendToActiveBlockStdoutLocked(flushText)
        pendingOutputBuffer.removeSubrange(..<splitIndex)
    }

    private func trailingMarkerPrefixCandidateLength(in text: String) -> Int {
        let maximum = min(Self.promptMarkerPrefix.count - 1, text.count)
        guard maximum > 0 else { return 0 }

        for length in stride(from: maximum, through: 1, by: -1) {
            let suffixStart = text.index(text.endIndex, offsetBy: -length)
            if text[suffixStart...] == Self.promptMarkerPrefix.prefix(length) {
                return length
            }
        }
        return 0
    }

    private func parseMarkerAtBufferStartLocked() -> MarkerParseResult {
        guard pendingOutputBuffer.hasPrefix(Self.promptMarkerPrefix) else {
            return .invalid
        }

        let prefixCount = Self.promptMarkerPrefix.count
        var cursor = pendingOutputBuffer.index(pendingOutputBuffer.startIndex, offsetBy: prefixCount)

        if cursor == pendingOutputBuffer.endIndex {
            return .needMoreData
        }

        var exitCodeText = ""

        if pendingOutputBuffer[cursor] == "-" {
            exitCodeText.append("-")
            cursor = pendingOutputBuffer.index(after: cursor)
            if cursor == pendingOutputBuffer.endIndex {
                return .needMoreData
            }
        }

        let digitStart = cursor
        while cursor < pendingOutputBuffer.endIndex,
              pendingOutputBuffer[cursor].wholeNumberValue != nil {
            exitCodeText.append(pendingOutputBuffer[cursor])
            cursor = pendingOutputBuffer.index(after: cursor)
        }

        if digitStart == cursor {
            return .invalid
        }

        if cursor == pendingOutputBuffer.endIndex {
            return .needMoreData
        }

        guard pendingOutputBuffer[cursor] == " " else {
            return .invalid
        }

        guard let exitCode = Int(exitCodeText) else {
            return .invalid
        }

        let consumedCount = pendingOutputBuffer.distance(
            from: pendingOutputBuffer.startIndex,
            to: pendingOutputBuffer.index(after: cursor)
        )

        return .complete(exitCode: exitCode, consumedCount: consumedCount)
    }

    private func removeLeadingCharactersLocked(_ count: Int) {
        guard count > 0 else { return }
        let index = pendingOutputBuffer.index(pendingOutputBuffer.startIndex, offsetBy: count)
        pendingOutputBuffer.removeSubrange(..<index)
    }

    private func appendToActiveBlockStdoutLocked(_ text: String) {
        guard !text.isEmpty else { return }
        guard var active = activeBlockStorage else { return }
        active.stdout.append(text)
        activeBlockStorage = active
    }

    private func finalizeActiveBlockLocked(exitCode: Int) {
        guard !rawModeActive else {
            activeBlockStorage = nil
            return
        }
        guard var active = activeBlockStorage else { return }

        active.finishedAt = Date()
        active.exitCode = exitCode
        active.status = exitCode == 0 ? .success : .failure

        blocksStorage.append(active)
        activeBlockStorage = nil
#if DEBUG
        print("[BLOCK COMPLETED] command=\(active.command) exitCode=\(exitCode) status=\(active.status)")
#endif
    }
}
