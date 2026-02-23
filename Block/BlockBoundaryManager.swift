import Foundation

nonisolated public final class BlockBoundaryManager {
    public struct PendingBlockFinalizationRequest: Sendable {
        public let exitCode: Int
        public let outputStartAbsoluteLineIndex: Int
        public let command: String
    }

    private enum MarkerParseResult {
        case complete(exitCode: Int, consumedCount: Int)
        case needMoreData
        case invalid
    }

    private static let promptMarkerPrefix = "<<<BLOCK_PROMPT>>>:"
    private static let promptMarkerPrefixBytes = Array(promptMarkerPrefix.utf8)

    private let stateLock = NSLock()

    private var blocksStorage: [Block] = []
    private var activeBlockStorage: Block?
    private var rawModeActive = false

    // Legacy text-path buffer kept for tests that call processOutput directly.
    private var pendingOutputBuffer = ""

    // Raw PTY stream is used only for marker detection (not stdout accumulation).
    private var pendingPTYBytes = Data()
    private var activeOutputStartAbsoluteLineIndex: Int?
    private var pendingFinalizationRequestStorage: PendingBlockFinalizationRequest?

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

    public func registerUserInput(_ text: String, outputStartAbsoluteLineIndex: Int? = nil) {
        let command = text.trimmingCharacters(in: .newlines)
#if DEBUG
        print("[BLOCK] input: \(command)")
#endif

        stateLock.lock()
        defer { stateLock.unlock() }

        guard !rawModeActive else { return }
        guard activeBlockStorage == nil else { return }

        pendingOutputBuffer.removeAll(keepingCapacity: true)
        pendingPTYBytes.removeAll(keepingCapacity: true)
        pendingFinalizationRequestStorage = nil
        activeOutputStartAbsoluteLineIndex = outputStartAbsoluteLineIndex

        activeBlockStorage = Block(
            command: command,
            startedAt: Date(),
            status: .running
        )
    }

    // Legacy path used by tests; app runtime no longer relies on this for stdout.
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

    // UI/runtime no-op now: stdout is extracted from libvterm text domain at finalize time.
    public func appendRenderedOutput(_ text: String) {
        _ = text
    }

    public func processPTYOutput(_ data: Data) {
        guard !data.isEmpty else { return }

        stateLock.lock()
        defer { stateLock.unlock() }

        guard !rawModeActive else { return }
        guard activeBlockStorage != nil else { return }

        pendingPTYBytes.append(data)
        processPendingPTYBytesLocked()
    }

    public func consumePendingBlockFinalizationRequest() -> PendingBlockFinalizationRequest? {
        stateLock.lock()
        defer { stateLock.unlock() }
        let request = pendingFinalizationRequestStorage
        pendingFinalizationRequestStorage = nil
        return request
    }

    public func completePendingBlock(exitCode: Int, stdout: String) {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !rawModeActive else {
            activeBlockStorage = nil
            activeOutputStartAbsoluteLineIndex = nil
            pendingPTYBytes.removeAll(keepingCapacity: true)
            pendingFinalizationRequestStorage = nil
            return
        }

        finalizeActiveBlockLocked(exitCode: exitCode, stdoutOverride: stdout)
    }

    public func displayModeChanged(_ displayMode: DisplayMode) {
        stateLock.lock()
        switch displayMode {
        case .blockMode:
            rawModeActive = false
        case .rawMode:
            rawModeActive = true
        }
        if rawModeActive {
            activeBlockStorage = nil
        }
        activeOutputStartAbsoluteLineIndex = nil
        pendingFinalizationRequestStorage = nil
        pendingOutputBuffer.removeAll(keepingCapacity: true)
        pendingPTYBytes.removeAll(keepingCapacity: true)
        stateLock.unlock()
    }

    public func alternateScreenChanged(isActive: Bool) {
        displayModeChanged(isActive ? .rawMode : .blockMode)
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

            switch parseMarkerAtBufferStartLocked(buffer: pendingOutputBuffer) {
            case let .complete(exitCode, consumedCount):
                removeLeadingCharactersLocked(consumedCount, from: &pendingOutputBuffer)
                finalizeActiveBlockLocked(exitCode: exitCode, stdoutOverride: nil)
            case .needMoreData:
                return
            case .invalid:
                let firstCharacter = String(pendingOutputBuffer.removeFirst())
                appendToActiveBlockStdoutLocked(firstCharacter)
            }
        }
    }

    private func processPendingPTYBytesLocked() {
        while true {
            guard let markerIndex = markerPrefixIndex(in: pendingPTYBytes) else {
                retainPTYMarkerTailCandidateLocked()
                return
            }

            // Drop bytes before the marker; stdout will be derived from libvterm text domain.
            if markerIndex > 0 {
                pendingPTYBytes.removeSubrange(0..<markerIndex)
            }

            switch parseMarkerAtBufferStartLocked(bytes: pendingPTYBytes) {
            case let .complete(exitCode, consumedCount):
                removeLeadingBytesLocked(consumedCount, from: &pendingPTYBytes)
                requestFinalizationLocked(exitCode: exitCode)
            case .needMoreData:
                return
            case .invalid:
                if !pendingPTYBytes.isEmpty {
                    pendingPTYBytes.removeFirst()
                } else {
                    return
                }
            }
        }
    }

    private func requestFinalizationLocked(exitCode: Int) {
        guard !rawModeActive else {
            activeBlockStorage = nil
            activeOutputStartAbsoluteLineIndex = nil
            pendingFinalizationRequestStorage = nil
            return
        }
        guard activeBlockStorage != nil else { return }
        guard pendingFinalizationRequestStorage == nil else { return }
        let outputStartAbsoluteLineIndex = activeOutputStartAbsoluteLineIndex ?? 0
        let command = activeBlockStorage?.command ?? ""
        pendingFinalizationRequestStorage = PendingBlockFinalizationRequest(
            exitCode: exitCode,
            outputStartAbsoluteLineIndex: outputStartAbsoluteLineIndex,
            command: command
        )
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

    private func trailingMarkerPrefixCandidateLength(in data: Data) -> Int {
        let prefix = Self.promptMarkerPrefixBytes
        let maximum = min(prefix.count - 1, data.count)
        guard maximum > 0 else { return 0 }

        for length in stride(from: maximum, through: 1, by: -1) {
            let start = data.count - length
            if data[start..<data.count].elementsEqual(prefix.prefix(length)) {
                return length
            }
        }
        return 0
    }

    private func retainPTYMarkerTailCandidateLocked() {
        let retainCount = trailingMarkerPrefixCandidateLength(in: pendingPTYBytes)
        if retainCount == pendingPTYBytes.count {
            return
        }
        if retainCount == 0 {
            pendingPTYBytes.removeAll(keepingCapacity: true)
            return
        }
        pendingPTYBytes = Data(pendingPTYBytes.suffix(retainCount))
    }

    private func parseMarkerAtBufferStartLocked(buffer: String) -> MarkerParseResult {
        guard buffer.hasPrefix(Self.promptMarkerPrefix) else {
            return .invalid
        }

        let prefixCount = Self.promptMarkerPrefix.count
        var cursor = buffer.index(buffer.startIndex, offsetBy: prefixCount)

        if cursor == buffer.endIndex {
            return .needMoreData
        }

        var exitCodeText = ""

        if buffer[cursor] == "-" {
            exitCodeText.append("-")
            cursor = buffer.index(after: cursor)
            if cursor == buffer.endIndex {
                return .needMoreData
            }
        }

        let digitStart = cursor
        while cursor < buffer.endIndex,
              buffer[cursor].wholeNumberValue != nil {
            exitCodeText.append(buffer[cursor])
            cursor = buffer.index(after: cursor)
        }

        if digitStart == cursor {
            return .invalid
        }

        if cursor == buffer.endIndex {
            return .needMoreData
        }

        guard buffer[cursor] == " " else {
            return .invalid
        }

        guard let exitCode = Int(exitCodeText) else {
            return .invalid
        }

        let consumedCount = buffer.distance(
            from: buffer.startIndex,
            to: buffer.index(after: cursor)
        )

        return .complete(exitCode: exitCode, consumedCount: consumedCount)
    }

    private func parseMarkerAtBufferStartLocked(bytes: Data) -> MarkerParseResult {
        let prefix = Self.promptMarkerPrefixBytes
        guard bytes.count >= prefix.count else {
            return bytes.elementsEqual(prefix.prefix(bytes.count)) ? .needMoreData : .invalid
        }
        guard bytes.prefix(prefix.count).elementsEqual(prefix) else {
            return .invalid
        }

        var index = prefix.count
        if index >= bytes.count {
            return .needMoreData
        }

        var isNegative = false
        if bytes[index] == UInt8(ascii: "-") {
            isNegative = true
            index += 1
            if index >= bytes.count {
                return .needMoreData
            }
        }

        var value = 0
        var sawDigit = false
        while index < bytes.count {
            let byte = bytes[index]
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
                break
            }
            sawDigit = true
            value = (value * 10) + Int(byte - UInt8(ascii: "0"))
            index += 1
        }

        guard sawDigit else { return .invalid }
        guard index < bytes.count else { return .needMoreData }
        guard bytes[index] == UInt8(ascii: " ") else { return .invalid }

        let exitCode = isNegative ? -value : value
        return .complete(exitCode: exitCode, consumedCount: index + 1)
    }

    private func removeLeadingCharactersLocked(_ count: Int, from buffer: inout String) {
        guard count > 0 else { return }
        let index = buffer.index(buffer.startIndex, offsetBy: count)
        buffer.removeSubrange(..<index)
    }

    private func removeLeadingBytesLocked(_ count: Int, from buffer: inout Data) {
        guard count > 0 else { return }
        if count >= buffer.count {
            buffer.removeAll(keepingCapacity: true)
            return
        }
        buffer.removeSubrange(0..<count)
    }

    private func appendToActiveBlockStdoutLocked(_ text: String) {
        guard !text.isEmpty else { return }
        guard var active = activeBlockStorage else { return }
        active.stdout.append(text)
        activeBlockStorage = active
    }

    private func markerPrefixIndex(in data: Data) -> Int? {
        let prefix = Data(Self.promptMarkerPrefixBytes)
        return data.range(of: prefix)?.lowerBound
    }

    private func finalizeActiveBlockLocked(exitCode: Int, stdoutOverride: String?) {
        guard !rawModeActive else {
            activeBlockStorage = nil
            activeOutputStartAbsoluteLineIndex = nil
            return
        }
        guard var active = activeBlockStorage else { return }

        if let stdoutOverride {
            active.stdout = stdoutOverride
#if DEBUG
            print("[BLOCK] finalize stdout bytes=\(stdoutOverride.utf8.count)")
#endif
        }

        active.finishedAt = Date()
        active.exitCode = exitCode
        active.status = exitCode == 0 ? .success : .failure

        blocksStorage.append(active)
        activeBlockStorage = nil
        activeOutputStartAbsoluteLineIndex = nil
#if DEBUG
        print("[BLOCK COMPLETED] command=\(active.command) exitCode=\(exitCode) status=\(active.status)")
#endif
    }
}
