import Foundation

private func terminalScreenDamageCallback(_ rect: VTermRect, _ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleDamage(rect)
}

private func terminalScreenMoveRectCallback(_ dest: VTermRect, _ src: VTermRect, _ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleMoveRect(dest: dest, src: src)
}

private func terminalScreenMoveCursorCallback(_ pos: VTermPos, _ oldPos: VTermPos, _ visible: Int32, _ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleMoveCursor(pos: pos, oldPos: oldPos, visible: visible)
}

private func terminalScreenSetTermPropCallback(_ prop: VTermProp, _ val: UnsafeMutablePointer<VTermValue>?, _ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleSetTermProp(prop: prop, val: val)
}

private func terminalScreenResizeCallback(_ rows: Int32, _ cols: Int32, _ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleResize(rows: rows, cols: cols)
}

private var terminalScreenCallbacks = VTermScreenCallbacks(
    damage: terminalScreenDamageCallback,
    moverect: terminalScreenMoveRectCallback,
    movecursor: terminalScreenMoveCursorCallback,
    settermprop: terminalScreenSetTermPropCallback,
    bell: nil,
    resize: terminalScreenResizeCallback,
    sb_pushline: nil,
    sb_popline: nil,
    sb_clear: nil,
    sb_pushline4: nil
)

public final class TerminalEmulator {
    public enum ActiveBufferKind: Sendable {
        case primary
        case alternate
    }

    private let queue = DispatchQueue(label: "com.glass-term.terminal.emulator")
    private let queueKey = DispatchSpecificKey<UInt8>()

    private var vterm: OpaquePointer?
    private var screen: OpaquePointer?
    private var state: OpaquePointer?

    private var primaryBuffer: ScreenBuffer
    private var alternateBuffer: ScreenBuffer
    private var activeBufferKindStorage: ActiveBufferKind = .primary

    public var activeBufferKind: ActiveBufferKind {
        withQueue { activeBufferKindStorage }
    }

    public init(rows: Int, cols: Int) {
        precondition(rows > 0 && cols > 0, "Terminal size must be positive")

        primaryBuffer = ScreenBuffer(rows: rows, cols: cols, isAlternate: false)
        alternateBuffer = ScreenBuffer(rows: rows, cols: cols, isAlternate: true)

        queue.setSpecific(key: queueKey, value: 1)
        withQueue {
            initializeVTerm(rows: rows, cols: cols)
        }
    }

    deinit {
        withQueue {
            cleanupVTerm()
        }
    }

    public func feed(_ data: Data) {
        guard !data.isEmpty else { return }

        withQueue {
            guard let vterm else { return }

            data.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return }

                let bytes = baseAddress.assumingMemoryBound(to: CChar.self)
                var remaining = rawBuffer.count
                var offset = 0

                while remaining > 0 {
                    let consumed = Int(vterm_input_write(vterm, bytes.advanced(by: offset), remaining))
                    if consumed <= 0 {
                        break
                    }
                    remaining -= consumed
                    offset += consumed
                }
            }

            flushAndSync()
        }
    }

    public func resize(rows: Int, cols: Int) {
        precondition(rows > 0 && cols > 0, "Terminal size must be positive")

        withQueue {
            guard let vterm else { return }

            vterm_set_size(vterm, Int32(rows), Int32(cols))
            resizeBuffers(rows: rows, cols: cols)
            refreshEntireActiveBuffer()
            syncCursorFromState()
        }
    }

    public func snapshot() -> ScreenBuffer {
        withQueue {
            switch activeBufferKindStorage {
            case .primary:
                return primaryBuffer
            case .alternate:
                return alternateBuffer
            }
        }
    }

    fileprivate func handleDamage(_ rect: VTermRect) -> Int32 {
        refreshRect(
            startRow: Int(rect.start_row),
            endRow: Int(rect.end_row),
            startCol: Int(rect.start_col),
            endCol: Int(rect.end_col)
        )
        return 1
    }

    fileprivate func handleMoveRect(dest: VTermRect, src: VTermRect) -> Int32 {
        mutateActiveBuffer { buffer in
            buffer.moveRect(
                destStartRow: Int(dest.start_row),
                destEndRow: Int(dest.end_row),
                destStartCol: Int(dest.start_col),
                destEndCol: Int(dest.end_col),
                srcStartRow: Int(src.start_row),
                srcStartCol: Int(src.start_col)
            )
        }
        return 1
    }

    fileprivate func handleMoveCursor(pos: VTermPos, oldPos: VTermPos, visible: Int32) -> Int32 {
        _ = oldPos
        mutateActiveBuffer { buffer in
            buffer.setCursor(row: Int(pos.row), col: Int(pos.col), visible: visible != 0)
        }
        return 1
    }

    fileprivate func handleSetTermProp(prop: VTermProp, val: UnsafeMutablePointer<VTermValue>?) -> Int32 {
        if prop == VTERM_PROP_ALTSCREEN {
            let isAlternate = (val?.pointee.boolean ?? 0) != 0
            activeBufferKindStorage = isAlternate ? .alternate : .primary
            refreshEntireActiveBuffer()
            syncCursorFromState()
            return 1
        }

        if prop == VTERM_PROP_CURSORVISIBLE {
            let isVisible = (val?.pointee.boolean ?? 0) != 0
            mutateActiveBuffer { buffer in
                buffer.setCursor(row: buffer.cursor.row, col: buffer.cursor.col, visible: isVisible)
            }
            return 1
        }

        return 1
    }

    fileprivate func handleResize(rows: Int32, cols: Int32) -> Int32 {
        let newRows = max(1, Int(rows))
        let newCols = max(1, Int(cols))
        resizeBuffers(rows: newRows, cols: newCols)
        refreshEntireActiveBuffer()
        syncCursorFromState()
        return 1
    }

    private func initializeVTerm(rows: Int, cols: Int) {
        guard let vterm = vterm_new(Int32(rows), Int32(cols)) else {
            fatalError("Failed to create VTerm")
        }

        self.vterm = vterm
        vterm_set_utf8(vterm, 1)

        guard let screen = vterm_obtain_screen(vterm) else {
            fatalError("Failed to obtain VTermScreen")
        }

        self.screen = screen
        self.state = vterm_obtain_state(vterm)

        let userData = Unmanaged.passUnretained(self).toOpaque()
        withUnsafePointer(to: &terminalScreenCallbacks) { callbacksPointer in
            vterm_screen_set_callbacks(screen, callbacksPointer, userData)
        }

        vterm_screen_enable_altscreen(screen, 1)
        vterm_screen_set_damage_merge(screen, VTERM_DAMAGE_CELL)
        vterm_screen_reset(screen, 1)

        flushAndSync()
    }

    private func cleanupVTerm() {
        if let screen {
            vterm_screen_set_callbacks(screen, nil, nil)
        }

        if let vterm {
            vterm_free(vterm)
        }

        vterm = nil
        screen = nil
        state = nil
    }

    private func flushAndSync() {
        if let screen {
            vterm_screen_flush_damage(screen)
        }
        syncCursorFromState()
    }

    private func syncCursorFromState() {
        guard let state else { return }

        var pos = VTermPos(row: 0, col: 0)
        vterm_state_get_cursorpos(state, &pos)

        mutateActiveBuffer { buffer in
            buffer.setCursor(row: Int(pos.row), col: Int(pos.col))
        }
    }

    private func refreshEntireActiveBuffer() {
        let dimensions = activeBufferDimensions()
        refreshRect(startRow: 0, endRow: dimensions.rows, startCol: 0, endCol: dimensions.cols)
    }

    private func activeBufferDimensions() -> (rows: Int, cols: Int) {
        switch activeBufferKindStorage {
        case .primary:
            return (primaryBuffer.rows, primaryBuffer.cols)
        case .alternate:
            return (alternateBuffer.rows, alternateBuffer.cols)
        }
    }

    private func refreshRect(startRow: Int, endRow: Int, startCol: Int, endCol: Int) {
        guard let screen else { return }

        let dimensions = activeBufferDimensions()

        let clampedStartRow = max(0, min(startRow, dimensions.rows))
        let clampedEndRow = max(0, min(endRow, dimensions.rows))
        let clampedStartCol = max(0, min(startCol, dimensions.cols))
        let clampedEndCol = max(0, min(endCol, dimensions.cols))

        guard clampedStartRow < clampedEndRow, clampedStartCol < clampedEndCol else {
            return
        }

        for row in clampedStartRow..<clampedEndRow {
            for col in clampedStartCol..<clampedEndCol {
                var vtermCell = VTermScreenCell()
                let pos = VTermPos(row: Int32(row), col: Int32(col))
                let hasCell = vterm_screen_get_cell(screen, pos, &vtermCell)
                let screenCell = hasCell != 0 ? Self.convert(vtermCell: vtermCell) : .blank

                mutateActiveBuffer { buffer in
                    buffer.setCell(row: row, col: col, cell: screenCell)
                }
            }
        }
    }

    private func resizeBuffers(rows: Int, cols: Int) {
        primaryBuffer.resize(rows: rows, cols: cols)
        alternateBuffer.resize(rows: rows, cols: cols)
    }

    private func mutateActiveBuffer(_ body: (inout ScreenBuffer) -> Void) {
        switch activeBufferKindStorage {
        case .primary:
            body(&primaryBuffer)
        case .alternate:
            body(&alternateBuffer)
        }
    }

    private func withQueue<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return body()
        }
        return queue.sync(execute: body)
    }

    private static func convert(vtermCell: VTermScreenCell) -> ScreenCell {
        let width = max(0, Int(vtermCell.width))
        let text = decodeChars(vtermCell)
        let styleSignature = styleSignature(from: vtermCell)

        if width == 0 {
            return ScreenCell(text: text, width: 0, styleSignature: styleSignature)
        }

        if text.isEmpty {
            return ScreenCell(text: " ", width: width, styleSignature: styleSignature)
        }

        return ScreenCell(text: text, width: width, styleSignature: styleSignature)
    }

    private static func decodeChars(_ cell: VTermScreenCell) -> String {
        var scalars = String.UnicodeScalarView()
        let replacement = UnicodeScalar(0xFFFD)!

        withUnsafePointer(to: cell.chars) { charsPointer in
            charsPointer.withMemoryRebound(to: UInt32.self, capacity: Int(VTERM_MAX_CHARS_PER_CELL)) { codePoints in
                for index in 0..<Int(VTERM_MAX_CHARS_PER_CELL) {
                    let codePoint = codePoints[index]
                    if codePoint == 0 {
                        break
                    }
                    scalars.append(UnicodeScalar(codePoint) ?? replacement)
                }
            }
        }

        return String(scalars)
    }

    private static func styleSignature(from cell: VTermScreenCell) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        withUnsafeBytes(of: cell.attrs) { bytes in
            fnv1a(hash: &hash, bytes: bytes)
        }
        withUnsafeBytes(of: cell.fg) { bytes in
            fnv1a(hash: &hash, bytes: bytes)
        }
        withUnsafeBytes(of: cell.bg) { bytes in
            fnv1a(hash: &hash, bytes: bytes)
        }
        return hash
    }

    private static func fnv1a(hash: inout UInt64, bytes: UnsafeRawBufferPointer) {
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
    }
}

public func phase3ValidationSnapshot(rows: Int = 8, cols: Int = 24) -> ScreenBuffer {
    let emulator = TerminalEmulator(rows: rows, cols: cols)

    let sequences = [
        "plain text",
        "\u{001B}[31m red \u{001B}[0m",
        "\u{001B}[3;1Hcursor",
        "\u{001B}[2J\u{001B}[H",
        "primary",
        "\u{001B}[?1049h",
        "alternate",
        "\u{001B}[?1049l"
    ]

    for sequence in sequences {
        emulator.feed(Data(sequence.utf8))
    }

    return emulator.snapshot()
}
