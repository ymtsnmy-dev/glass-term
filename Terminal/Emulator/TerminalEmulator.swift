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

private func terminalScreenBellCallback(_ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleBell()
}

private func terminalScreenResizeCallback(_ rows: Int32, _ cols: Int32, _ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleResize(rows: rows, cols: cols)
}

private func terminalScreenPushLineCallback(_ cols: Int32, _ cells: UnsafePointer<VTermScreenCell>?, _ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handlePushScrollbackLine(cols: cols, cells: cells)
}

private func terminalScreenClearScrollbackCallback(_ user: UnsafeMutableRawPointer?) -> Int32 {
    guard let user else { return 0 }
    let emulator = Unmanaged<TerminalEmulator>.fromOpaque(user).takeUnretainedValue()
    return emulator.handleClearScrollback()
}

private var terminalScreenCallbacks = VTermScreenCallbacks(
    damage: terminalScreenDamageCallback,
    moverect: terminalScreenMoveRectCallback,
    movecursor: terminalScreenMoveCursorCallback,
    settermprop: terminalScreenSetTermPropCallback,
    bell: terminalScreenBellCallback,
    resize: terminalScreenResizeCallback,
    sb_pushline: terminalScreenPushLineCallback,
    sb_popline: nil,
    sb_clear: terminalScreenClearScrollbackCallback,
    sb_pushline4: nil
)

public final class TerminalEmulator {
    public enum ActiveBufferKind: Sendable {
        case primary
        case alternate
    }

    private let queue = DispatchQueue(label: "com.glass-term.terminal.emulator")
    private let queueKey = DispatchSpecificKey<UInt8>()
    private enum VTermColorBits {
        static let typeMask: UInt8 = 0x01
        static let indexed: UInt8 = 0x01
        static let defaultForeground: UInt8 = 0x02
        static let defaultBackground: UInt8 = 0x04
    }

    private var vterm: OpaquePointer?
    private var screen: OpaquePointer?
    private var state: OpaquePointer?

    private let bracketedPasteEnableSequence: [UInt8] = [0x1B, 0x5B, 0x3F, 0x32, 0x30, 0x30, 0x34, 0x68] // ESC[?2004h
    private let bracketedPasteDisableSequence: [UInt8] = [0x1B, 0x5B, 0x3F, 0x32, 0x30, 0x30, 0x34, 0x6C] // ESC[?2004l

    private var bracketedPasteScanTail: [UInt8] = []
    private var bracketedPasteEnabledStorage = false
    private var cursorShapeNumberStorage = 1
    private var cursorBlinkStorage = true
    private var windowTitleStorage = ""
    private var iconNameStorage = ""
    private var bellSequenceStorage: UInt64 = 0
    private var titleFragmentStorage = ""
    private var iconNameFragmentStorage = ""

    private var primaryBuffer: ScreenBuffer
    private var alternateBuffer: ScreenBuffer
    private var activeBufferKindStorage: ActiveBufferKind = .primary
    private var onScrollbackLineStorage: ((ScreenLine) -> Void)?
    private var onScrollbackClearedStorage: (() -> Void)?
    private var onAlternateScreenChangedStorage: ((Bool) -> Void)?

    public var activeBufferKind: ActiveBufferKind {
        withQueue { activeBufferKindStorage }
    }

    public var onScrollbackLine: ((ScreenLine) -> Void)? {
        get { withQueue { onScrollbackLineStorage } }
        set { withQueue { onScrollbackLineStorage = newValue } }
    }

    public var onScrollbackCleared: (() -> Void)? {
        get { withQueue { onScrollbackClearedStorage } }
        set { withQueue { onScrollbackClearedStorage = newValue } }
    }

    public var onAlternateScreenChanged: ((Bool) -> Void)? {
        get { withQueue { onAlternateScreenChangedStorage } }
        set { withQueue { onAlternateScreenChangedStorage = newValue } }
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
            updateBracketedPasteModeFromOutput(data)

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
            guard let vterm, let screen else { return }

            vterm_set_size(vterm, Int32(rows), Int32(cols))
            resizeBuffers(rows: rows, cols: cols)
            vterm_screen_flush_damage(screen)
            rebuildActiveBufferFromScreen()
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
        _ = rect
        rebuildActiveBufferFromScreen()
        syncCursorFromState()
        return 1
    }

    fileprivate func handleMoveRect(dest: VTermRect, src: VTermRect) -> Int32 {
        _ = dest
        _ = src
        rebuildActiveBufferFromScreen()
        syncCursorFromState()
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
            let previousIsAlternate = (activeBufferKindStorage == .alternate)
            activeBufferKindStorage = isAlternate ? .alternate : .primary
            rebuildActiveBufferFromScreen()
            syncCursorFromState()
            syncTerminalPropertiesToBuffers()
            if previousIsAlternate != isAlternate {
                onAlternateScreenChangedStorage?(isAlternate)
            }
            return 1
        }

        if prop == VTERM_PROP_CURSORVISIBLE {
            let isVisible = (val?.pointee.boolean ?? 0) != 0
            mutateActiveBuffer { buffer in
                buffer.setCursor(row: buffer.cursor.row, col: buffer.cursor.col, visible: isVisible)
            }
            return 1
        }

        if prop == VTERM_PROP_CURSORBLINK {
            cursorBlinkStorage = (val?.pointee.boolean ?? 0) != 0
            syncTerminalPropertiesToBuffers()
            return 1
        }

        if prop == VTERM_PROP_CURSORSHAPE {
            cursorShapeNumberStorage = Int(val?.pointee.number ?? 1)
            syncTerminalPropertiesToBuffers()
            return 1
        }

        if prop == VTERM_PROP_TITLE {
            applyStringPropertyFragment(
                prop: prop,
                fragment: val?.pointee.string
            )
            return 1
        }

        if prop == VTERM_PROP_ICONNAME {
            applyStringPropertyFragment(
                prop: prop,
                fragment: val?.pointee.string
            )
            return 1
        }

        return 1
    }

    fileprivate func handleBell() -> Int32 {
        bellSequenceStorage &+= 1
        syncTerminalPropertiesToBuffers()
        return 1
    }

    fileprivate func handleResize(rows: Int32, cols: Int32) -> Int32 {
        let newRows = max(1, Int(rows))
        let newCols = max(1, Int(cols))
        resizeBuffers(rows: newRows, cols: newCols)
        rebuildActiveBufferFromScreen()
        syncCursorFromState()
        return 1
    }

    fileprivate func handlePushScrollbackLine(cols: Int32, cells: UnsafePointer<VTermScreenCell>?) -> Int32 {
        guard activeBufferKindStorage == .primary else { return 1 }
        guard let callback = onScrollbackLineStorage else { return 1 }
        guard let cells else { return 1 }

        let count = max(0, Int(cols))
        guard count > 0 else { return 1 }

        var row: [ScreenCell] = []
        row.reserveCapacity(count)
        for index in 0..<count {
            let cell = convertVTermCell(cells[index])
            row.append(cell.width <= 0 ? .blank : cell)
        }

        callback(row)
        return 1
    }

    fileprivate func handleClearScrollback() -> Int32 {
        onScrollbackClearedStorage?()
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
        rebuildActiveBufferFromScreen()
        syncCursorFromState()
        syncTerminalPropertiesToBuffers()
    }

    private func syncCursorFromState() {
        guard let state else { return }

        var pos = VTermPos(row: 0, col: 0)
        vterm_state_get_cursorpos(state, &pos)

        mutateActiveBuffer { buffer in
            buffer.setCursor(row: Int(pos.row), col: Int(pos.col))
        }
    }

    private func activeBufferDimensions() -> (rows: Int, cols: Int) {
        switch activeBufferKindStorage {
        case .primary:
            return (primaryBuffer.rows, primaryBuffer.cols)
        case .alternate:
            return (alternateBuffer.rows, alternateBuffer.cols)
        }
    }

    private func rebuildActiveBufferFromScreen() {
        guard let screen else { return }

        let dimensions = activeBufferDimensions()
        guard dimensions.rows > 0, dimensions.cols > 0 else {
            return
        }

        var rebuiltStorage = Array(repeating: ScreenCell.blank, count: dimensions.rows * dimensions.cols)
        for row in 0..<dimensions.rows {
            for col in 0..<dimensions.cols {
                var vtermCell = VTermScreenCell()
                let pos = VTermPos(row: Int32(row), col: Int32(col))
                let hasCell = vterm_screen_get_cell(screen, pos, &vtermCell)
                let screenCell = hasCell != 0 ? convertVTermCell(vtermCell) : .blank

                rebuiltStorage[(row * dimensions.cols) + col] = screenCell
            }
        }

        mutateActiveBuffer { buffer in
            buffer.replaceVisibleStorage(rebuiltStorage)
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

    private func convertVTermCell(_ vtermCell: VTermScreenCell) -> ScreenCell {
        let width = max(0, Int(vtermCell.width))
        let text = Self.decodeChars(vtermCell)
        let styleSignature = Self.styleSignature(from: vtermCell)

        let usesDefaultForeground = Self.colorUsesDefaultForeground(vtermCell.fg)
        let usesDefaultBackground = Self.colorUsesDefaultBackground(vtermCell.bg)

        var foregroundColor = vtermCell.fg
        var backgroundColor = vtermCell.bg
        if let screen {
            vterm_screen_convert_color_to_rgb(screen, &foregroundColor)
            vterm_screen_convert_color_to_rgb(screen, &backgroundColor)
        }

        let style = ScreenCellStyle(
            foreground: resolveRGBColor(foregroundColor, fallback: .white),
            background: resolveRGBColor(backgroundColor, fallback: .black),
            usesDefaultForeground: usesDefaultForeground,
            usesDefaultBackground: usesDefaultBackground
        )

        if width == 0 {
            return ScreenCell(text: text, width: 0, styleSignature: styleSignature, style: style)
        }

        if text.isEmpty {
            return ScreenCell(text: " ", width: width, styleSignature: styleSignature, style: style)
        }

        return ScreenCell(text: text, width: width, styleSignature: styleSignature, style: style)
    }

    private func resolveRGBColor(_ color: VTermColor, fallback: ScreenColor) -> ScreenColor {
        let isIndexed = (color.type & VTermColorBits.typeMask) == VTermColorBits.indexed
        if isIndexed {
            return fallback
        }

        return ScreenColor(
            red: color.rgb.red,
            green: color.rgb.green,
            blue: color.rgb.blue
        )
    }

    private static func colorUsesDefaultForeground(_ color: VTermColor) -> Bool {
        (color.type & VTermColorBits.defaultForeground) != 0
    }

    private static func colorUsesDefaultBackground(_ color: VTermColor) -> Bool {
        (color.type & VTermColorBits.defaultBackground) != 0
    }

    private func applyStringPropertyFragment(
        prop: VTermProp,
        fragment: VTermStringFragment?
    ) {
        guard let fragment else { return }
        let text = Self.decodeStringFragment(fragment)

        switch prop {
        case VTERM_PROP_TITLE:
            if fragment.initial {
                titleFragmentStorage = ""
            }
            titleFragmentStorage += text
            if fragment.final {
                windowTitleStorage = titleFragmentStorage
                syncTerminalPropertiesToBuffers()
            }
        case VTERM_PROP_ICONNAME:
            if fragment.initial {
                iconNameFragmentStorage = ""
            }
            iconNameFragmentStorage += text
            if fragment.final {
                iconNameStorage = iconNameFragmentStorage
                if windowTitleStorage.isEmpty {
                    windowTitleStorage = iconNameStorage
                }
                syncTerminalPropertiesToBuffers()
            }
        default:
            break
        }
    }

    private static func decodeStringFragment(_ fragment: VTermStringFragment) -> String {
        guard let pointer = fragment.str, fragment.len > 0 else {
            return ""
        }

        let bytes = UnsafeRawPointer(pointer)
            .assumingMemoryBound(to: UInt8.self)
        let buffer = UnsafeBufferPointer(start: bytes, count: Int(fragment.len))
        return String(decoding: buffer, as: UTF8.self)
    }

    private func syncTerminalPropertiesToBuffers() {
        let resolvedWindowTitle = !windowTitleStorage.isEmpty ? windowTitleStorage : iconNameStorage

        primaryBuffer.setCursorShape(number: cursorShapeNumberStorage)
        primaryBuffer.setCursorBlink(cursorBlinkStorage)
        primaryBuffer.setWindowTitle(resolvedWindowTitle)
        primaryBuffer.setBellSequence(bellSequenceStorage)
        primaryBuffer.setBracketedPasteEnabled(bracketedPasteEnabledStorage)

        alternateBuffer.setCursorShape(number: cursorShapeNumberStorage)
        alternateBuffer.setCursorBlink(cursorBlinkStorage)
        alternateBuffer.setWindowTitle(resolvedWindowTitle)
        alternateBuffer.setBellSequence(bellSequenceStorage)
        alternateBuffer.setBracketedPasteEnabled(bracketedPasteEnabledStorage)
    }

    private func updateBracketedPasteModeFromOutput(_ data: Data) {
        var combined = bracketedPasteScanTail
        combined.reserveCapacity(bracketedPasteScanTail.count + data.count)
        combined.append(contentsOf: data)

        let enableIndex = Self.lastOccurrence(of: bracketedPasteEnableSequence, in: combined)
        let disableIndex = Self.lastOccurrence(of: bracketedPasteDisableSequence, in: combined)

        var updatedMode: Bool?
        switch (enableIndex, disableIndex) {
        case let (.some(enabled), .some(disabled)):
            updatedMode = enabled > disabled
        case (.some, .none):
            updatedMode = true
        case (.none, .some):
            updatedMode = false
        case (.none, .none):
            break
        }

        if let updatedMode, updatedMode != bracketedPasteEnabledStorage {
            bracketedPasteEnabledStorage = updatedMode
            syncTerminalPropertiesToBuffers()
        }

        let tailLength = max(bracketedPasteEnableSequence.count, bracketedPasteDisableSequence.count) - 1
        if combined.count > tailLength {
            bracketedPasteScanTail = Array(combined.suffix(tailLength))
        } else {
            bracketedPasteScanTail = combined
        }
    }

    private static func lastOccurrence(of pattern: [UInt8], in bytes: [UInt8]) -> Int? {
        guard !pattern.isEmpty else { return nil }
        guard bytes.count >= pattern.count else { return nil }

        var lastMatch: Int?
        let lastStart = bytes.count - pattern.count
        for start in 0...lastStart {
            if bytes[start..<(start + pattern.count)].elementsEqual(pattern) {
                lastMatch = start
            }
        }
        return lastMatch
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
