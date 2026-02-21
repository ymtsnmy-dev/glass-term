import AppKit
import Combine
import SwiftUI

public struct TerminalView: View {
    @ObservedObject private var session: TerminalSessionController
    @State private var selectionAnchor: GridPosition?
    @State private var selectionExtent: GridPosition?
    @State private var isSelecting = false
    @State private var selectionDidDrag = false
    @State private var cursorBlinkVisible = true

    private let cursorBlinkTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private let font: Font
    private let cellSize: CGSize
    private let textColor: Color
    private let backgroundColor: Color
    private let cursorColor: Color
#if DEBUG
    private let showGridDebug = false
#endif

    public init(
        session: TerminalSessionController,
        fontSize: CGFloat = 14,
        textColor: Color = .white,
        backgroundColor: Color = .black,
        cursorColor: Color = .white
    ) {
        let resolvedFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        self.session = session
        self.font = Font(resolvedFont)
        self.cellSize = Self.measureCellSize(for: resolvedFont)
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.cursorColor = cursorColor
    }

    public var body: some View {
        GeometryReader { proxy in
            let viewSize = proxy.size
            let renderVersion = session.renderVersion
            let buffer = session.snapshot()
            let totalRows = buffer.totalRows
            let maxViewportOffsetRows = session.maxViewportOffsetRows()
            let viewportOffsetRows = min(session.viewportOffsetRows, maxViewportOffsetRows)
            let viewportStartDisplayRow = max(0, totalRows - buffer.rows - viewportOffsetRows)
            let selectionRange = normalizedSelectionRange(for: buffer)

            ZStack(alignment: .topLeading) {
                Canvas(rendersAsynchronously: false) { context, canvasSize in
                    drawBackground(context: &context, size: canvasSize)
#if DEBUG
                    if showGridDebug {
                        drawGridDebug(context: &context, size: canvasSize, buffer: buffer)
                    }
#endif
                    drawScreenBuffer(
                        context: &context,
                        buffer: buffer,
                        startDisplayRow: viewportStartDisplayRow,
                        selectionRange: selectionRange
                    )
                    drawCursor(
                        context: &context,
                        buffer: buffer,
                        startDisplayRow: viewportStartDisplayRow
                    )
                }
                .id(renderVersion)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                TerminalKeyInputView(
                    onInput: { text in
                        clearSelection()
                        session.sendInput(text)
                    },
                    onPaste: { text in
                        clearSelection()
                        session.sendPaste(text)
                    },
                    onCopy: {
                        if let copied = selectedText(buffer: buffer, selectionRange: selectionRange) {
                            copyToPasteboard(copied)
                        }
                    },
                    onCtrlC: {
                        clearSelection()
                        session.sendCtrlC()
                    },
                    onScrollWheel: { event in
                        session.handlePointerScroll(
                            deltaY: event.scrollingDeltaY,
                            precise: event.hasPreciseScrollingDeltas
                        )
                    },
                    onMouseDown: { point in
                        handleMouseDown(
                            point,
                            buffer: buffer,
                            viewportStartDisplayRow: viewportStartDisplayRow
                        )
                    },
                    onMouseDragged: { point in
                        handleMouseDragged(
                            point,
                            buffer: buffer,
                            viewportStartDisplayRow: viewportStartDisplayRow
                        )
                    },
                    onMouseUp: { point in
                        handleMouseUp(
                            point,
                            buffer: buffer,
                            viewportStartDisplayRow: viewportStartDisplayRow
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)

                if maxViewportOffsetRows > 0 {
                    let trackHeight = max(1, viewSize.height - 8)
                    let thumbHeight = max(24, trackHeight * CGFloat(buffer.rows) / CGFloat(totalRows))
                    let maxThumbTravel = max(0, trackHeight - thumbHeight)
                    let fractionFromTop = 1 - (CGFloat(viewportOffsetRows) / CGFloat(maxViewportOffsetRows))
                    let thumbY = maxThumbTravel * fractionFromTop

                    ZStack(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(Color.white.opacity(0.7))
                            .frame(height: thumbHeight)
                            .offset(y: thumbY)
                    }
                    .frame(width: 8, height: trackHeight)
                    .padding(.trailing, 2)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard maxThumbTravel > 0 else {
                                    session.setViewportOffsetRows(0)
                                    return
                                }

                                let centeredY = value.location.y - (thumbHeight / 2)
                                let clampedY = min(max(0, centeredY), maxThumbTravel)
                                let ratioFromTop = clampedY / maxThumbTravel
                                let targetOffset = Int(round((1 - ratioFromTop) * CGFloat(maxViewportOffsetRows)))
                                session.setViewportOffsetRows(targetOffset)
                            }
                    )
                }
            }
            .clipped()
            .onAppear {
                session.startIfNeeded()
                session.resizeIfNeeded(viewSize: viewSize, cellSize: cellSize)
            }
            .onChange(of: viewSize) { _, newSize in
                session.resizeIfNeeded(viewSize: newSize, cellSize: cellSize)
            }
            .onReceive(cursorBlinkTimer) { _ in
                cursorBlinkVisible.toggle()
            }
        }
    }

    private static func measureCellSize(for font: NSFont) -> CGSize {
        let width = ("W" as NSString).size(withAttributes: [.font: font]).width
        let height = font.ascender - font.descender + font.leading
        return CGSize(width: max(1, width), height: max(1, height))
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(backgroundColor)
        )
    }

#if DEBUG
    private func drawGridDebug(context: inout GraphicsContext, size: CGSize, buffer: ScreenBuffer) {
        let lineHeight = min(size.height, cellSize.height)

        guard buffer.cols > 0, lineHeight > 0 else {
            return
        }

        var path = Path()
        for col in 0...buffer.cols {
            let x = CGFloat(col) * cellSize.width
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: lineHeight))
        }

        context.stroke(path, with: .color(.red.opacity(0.35)), lineWidth: 1)
    }
#endif

    private func drawScreenBuffer(
        context: inout GraphicsContext,
        buffer: ScreenBuffer,
        startDisplayRow: Int,
        selectionRange: SelectionRange?
    ) {
        guard buffer.rows > 0, buffer.cols > 0 else {
            return
        }

        for row in 0..<buffer.rows {
            for col in 0..<buffer.cols {
                drawCell(
                    context: &context,
                    buffer: buffer,
                    row: row,
                    col: col,
                    displayRow: startDisplayRow + row,
                    selectionRange: selectionRange
                )
            }
        }
    }

    private func drawCell(
        context: inout GraphicsContext,
        buffer: ScreenBuffer,
        row: Int,
        col: Int,
        displayRow: Int,
        selectionRange: SelectionRange?
    ) {
        let frame = CGRect(
            x: CGFloat(col) * cellSize.width,
            y: CGFloat(row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
        let cell = buffer.cellAtDisplayRow(displayRow, col: col)
        context.fill(Path(frame), with: .color(resolvedBackgroundColor(for: cell)))
        if isCellSelected(displayRow: displayRow, col: col, selectionRange: selectionRange) {
            context.fill(Path(frame), with: .color(Color.white.opacity(0.25)))
        }
        guard cell.width > 0 else {
            return
        }

        drawText(
            text: cell.text.isEmpty ? " " : cell.text,
            atColumn: col,
            row: row,
            color: resolvedForegroundColor(for: cell),
            context: &context
        )
    }

    private func drawCursor(
        context: inout GraphicsContext,
        buffer: ScreenBuffer,
        startDisplayRow: Int
    ) {
        let cursor = buffer.cursor
        guard cursor.visible else { return }
        if buffer.cursorBlink && !cursorBlinkVisible {
            return
        }
        guard cursor.row >= 0, cursor.row < buffer.rows else { return }
        guard cursor.col >= 0, cursor.col < buffer.cols else { return }

        let cursorDisplayRow = buffer.scrollbackRows + cursor.row
        let localRow = cursorDisplayRow - startDisplayRow
        guard localRow >= 0, localRow < buffer.rows else {
            return
        }

        let baseFrame = CGRect(
            x: CGFloat(cursor.col) * cellSize.width,
            y: CGFloat(localRow) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )

        let cursorFrame: CGRect
        switch buffer.cursorShape {
        case .block:
            cursorFrame = baseFrame
        case .underline:
            let height = max(2, ceil(cellSize.height * 0.12))
            cursorFrame = CGRect(
                x: baseFrame.minX,
                y: baseFrame.maxY - height,
                width: baseFrame.width,
                height: height
            )
        case .bar:
            let width = max(1, ceil(cellSize.width * 0.15))
            cursorFrame = CGRect(
                x: baseFrame.minX,
                y: baseFrame.minY,
                width: width,
                height: baseFrame.height
            )
        }

        context.fill(Path(cursorFrame), with: .color(cursorColor))
    }

    private func drawText(
        text: String,
        atColumn column: Int,
        row: Int,
        color: Color,
        context: inout GraphicsContext
    ) {
        let origin = CGPoint(
            x: CGFloat(column) * cellSize.width,
            y: CGFloat(row) * cellSize.height
        )

        let rendered = Text(verbatim: text)
            .font(font)
            .kerning(0)
        var resolved = context.resolve(rendered)
        resolved.shading = .color(color)
        context.draw(resolved, at: origin, anchor: .topLeading)
    }

    private func resolvedForegroundColor(for cell: ScreenCell) -> Color {
        if cell.style.usesDefaultForeground {
            return textColor
        }
        return color(from: cell.style.foreground)
    }

    private func resolvedBackgroundColor(for cell: ScreenCell) -> Color {
        if cell.style.usesDefaultBackground {
            return backgroundColor
        }
        return color(from: cell.style.background)
    }

    private func color(from color: ScreenColor) -> Color {
        Color(
            red: Double(color.red) / 255.0,
            green: Double(color.green) / 255.0,
            blue: Double(color.blue) / 255.0
        )
    }

    private func handleMouseDown(
        _ point: CGPoint,
        buffer: ScreenBuffer,
        viewportStartDisplayRow: Int
    ) {
        guard let position = gridPosition(
            for: point,
            buffer: buffer,
            viewportStartDisplayRow: viewportStartDisplayRow
        ) else {
            clearSelection()
            return
        }

        selectionAnchor = position
        selectionExtent = position
        isSelecting = true
        selectionDidDrag = false
    }

    private func handleMouseDragged(
        _ point: CGPoint,
        buffer: ScreenBuffer,
        viewportStartDisplayRow: Int
    ) {
        guard isSelecting else { return }
        guard let position = gridPosition(
            for: point,
            buffer: buffer,
            viewportStartDisplayRow: viewportStartDisplayRow
        ) else {
            return
        }

        selectionExtent = position
        selectionDidDrag = true
    }

    private func handleMouseUp(
        _ point: CGPoint,
        buffer: ScreenBuffer,
        viewportStartDisplayRow: Int
    ) {
        guard let position = gridPosition(
            for: point,
            buffer: buffer,
            viewportStartDisplayRow: viewportStartDisplayRow
        ) else {
            clearSelection()
            isSelecting = false
            selectionDidDrag = false
            return
        }

        if isSelecting {
            selectionExtent = position
            let dragged = selectionDidDrag
            isSelecting = false
            selectionDidDrag = false

            if !dragged {
                clearSelection()
                session.handlePointerCursorMove(
                    targetDisplayRow: position.displayRow,
                    targetCol: position.col
                )
            }
            return
        }

        clearSelection()
        session.handlePointerCursorMove(
            targetDisplayRow: position.displayRow,
            targetCol: position.col
        )
    }

    private func clearSelection() {
        selectionAnchor = nil
        selectionExtent = nil
        isSelecting = false
        selectionDidDrag = false
    }

    private func gridPosition(
        for point: CGPoint,
        buffer: ScreenBuffer,
        viewportStartDisplayRow: Int
    ) -> GridPosition? {
        guard buffer.rows > 0, buffer.cols > 0 else {
            return nil
        }

        let rawCol = Int(floor(point.x / cellSize.width))
        let rawRow = Int(floor(point.y / cellSize.height))
        let col = min(max(0, rawCol), buffer.cols - 1)
        let row = min(max(0, rawRow), buffer.rows - 1)
        return GridPosition(displayRow: viewportStartDisplayRow + row, col: col)
    }

    private func normalizedSelectionRange(for buffer: ScreenBuffer) -> SelectionRange? {
        guard let anchor = selectionAnchor, let extent = selectionExtent else {
            return nil
        }
        guard buffer.cols > 0, buffer.totalRows > 0 else {
            return nil
        }

        let normalizedAnchor = clamp(anchor, buffer: buffer)
        let normalizedExtent = clamp(extent, buffer: buffer)
        if sortOrder(lhs: normalizedAnchor, rhs: normalizedExtent) {
            return SelectionRange(lower: normalizedAnchor, upper: normalizedExtent)
        }
        return SelectionRange(lower: normalizedExtent, upper: normalizedAnchor)
    }

    private func clamp(_ position: GridPosition, buffer: ScreenBuffer) -> GridPosition {
        let clampedRow = min(max(0, position.displayRow), max(0, buffer.totalRows - 1))
        let clampedCol = min(max(0, position.col), max(0, buffer.cols - 1))
        return GridPosition(displayRow: clampedRow, col: clampedCol)
    }

    private func sortOrder(lhs: GridPosition, rhs: GridPosition) -> Bool {
        if lhs.displayRow != rhs.displayRow {
            return lhs.displayRow < rhs.displayRow
        }
        return lhs.col <= rhs.col
    }

    private func isCellSelected(displayRow: Int, col: Int, selectionRange: SelectionRange?) -> Bool {
        guard let selectionRange else { return false }
        if displayRow < selectionRange.lower.displayRow || displayRow > selectionRange.upper.displayRow {
            return false
        }
        if selectionRange.lower.displayRow == selectionRange.upper.displayRow {
            return col >= selectionRange.lower.col && col <= selectionRange.upper.col
        }
        if displayRow == selectionRange.lower.displayRow {
            return col >= selectionRange.lower.col
        }
        if displayRow == selectionRange.upper.displayRow {
            return col <= selectionRange.upper.col
        }
        return true
    }

    private func selectedText(buffer: ScreenBuffer, selectionRange: SelectionRange?) -> String? {
        guard let selectionRange else { return nil }

        var lines: [String] = []
        lines.reserveCapacity((selectionRange.upper.displayRow - selectionRange.lower.displayRow) + 1)

        for displayRow in selectionRange.lower.displayRow...selectionRange.upper.displayRow {
            let startCol = displayRow == selectionRange.lower.displayRow ? selectionRange.lower.col : 0
            let endCol = displayRow == selectionRange.upper.displayRow ? selectionRange.upper.col : (buffer.cols - 1)
            guard startCol <= endCol else {
                lines.append("")
                continue
            }

            var rowText = ""
            rowText.reserveCapacity(endCol - startCol + 1)
            for col in startCol...endCol {
                let cell = buffer.cellAtDisplayRow(displayRow, col: col)
                if cell.width > 0 {
                    rowText += cell.text
                }
            }
            lines.append(rowText.trimmingTrailingSpaces())
        }

        let joined = lines.joined(separator: "\n")
        return joined.isEmpty ? nil : joined
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private struct GridPosition: Equatable {
        var displayRow: Int
        var col: Int
    }

    private struct SelectionRange {
        var lower: GridPosition
        var upper: GridPosition
    }
}

private struct TerminalKeyInputView: NSViewRepresentable {
    let onInput: (String) -> Void
    let onPaste: (String) -> Void
    let onCopy: () -> Void
    let onCtrlC: () -> Void
    let onScrollWheel: (NSEvent) -> Void
    let onMouseDown: (CGPoint) -> Void
    let onMouseDragged: (CGPoint) -> Void
    let onMouseUp: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onInput: onInput,
            onPaste: onPaste,
            onCopy: onCopy,
            onCtrlC: onCtrlC,
            onScrollWheel: onScrollWheel,
            onMouseDown: onMouseDown,
            onMouseDragged: onMouseDragged,
            onMouseUp: onMouseUp
        )
    }

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = context.coordinator.handleKeyDown
        view.onInsertText = context.coordinator.handleInsertText
        view.onCommandSelector = context.coordinator.handleCommandSelector
        view.onScrollWheel = context.coordinator.handleScrollWheel
        view.onMouseDown = context.coordinator.handleMouseDown
        view.onMouseDragged = context.coordinator.handleMouseDragged
        view.onMouseUp = context.coordinator.handleMouseUp
        view.focusIfPossible()
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = context.coordinator.handleKeyDown
        nsView.onInsertText = context.coordinator.handleInsertText
        nsView.onCommandSelector = context.coordinator.handleCommandSelector
        nsView.onScrollWheel = context.coordinator.handleScrollWheel
        nsView.onMouseDown = context.coordinator.handleMouseDown
        nsView.onMouseDragged = context.coordinator.handleMouseDragged
        nsView.onMouseUp = context.coordinator.handleMouseUp
        nsView.focusIfPossible()
    }

    final class Coordinator {
        private let onInput: (String) -> Void
        private let onPaste: (String) -> Void
        private let onCopy: () -> Void
        private let onCtrlC: () -> Void
        private let onScrollWheel: (NSEvent) -> Void
        private let onMouseDown: (CGPoint) -> Void
        private let onMouseDragged: (CGPoint) -> Void
        private let onMouseUp: (CGPoint) -> Void

        init(
            onInput: @escaping (String) -> Void,
            onPaste: @escaping (String) -> Void,
            onCopy: @escaping () -> Void,
            onCtrlC: @escaping () -> Void,
            onScrollWheel: @escaping (NSEvent) -> Void,
            onMouseDown: @escaping (CGPoint) -> Void,
            onMouseDragged: @escaping (CGPoint) -> Void,
            onMouseUp: @escaping (CGPoint) -> Void
        ) {
            self.onInput = onInput
            self.onPaste = onPaste
            self.onCopy = onCopy
            self.onCtrlC = onCtrlC
            self.onScrollWheel = onScrollWheel
            self.onMouseDown = onMouseDown
            self.onMouseDragged = onMouseDragged
            self.onMouseUp = onMouseUp
        }

        func handleKeyDown(_ event: NSEvent) -> Bool {
            if event.modifierFlags.contains(.command),
               let commandCharacter = event.charactersIgnoringModifiers?.lowercased() {
                if commandCharacter == "v",
                   let pasted = NSPasteboard.general.string(forType: .string),
                   !pasted.isEmpty {
                    onPaste(pasted)
                    return true
                }

                if commandCharacter == "c" {
                    onCopy()
                    return true
                }
            }

            if event.modifierFlags.contains(.control),
               let controlCharacter = event.charactersIgnoringModifiers?.lowercased(),
               controlCharacter == "c" {
                onCtrlC()
                return true
            }

            if let sequence = specialKeySequence(for: event.keyCode) {
                onInput(sequence)
                return true
            }

            return false
        }

        func handleInsertText(_ text: String) {
            guard !text.isEmpty else { return }
            onInput(text)
        }

        func handleCommandSelector(_ selector: Selector) -> Bool {
            let name = NSStringFromSelector(selector)

            switch name {
            case "insertNewline:", "insertLineBreak:", "insertNewlineIgnoringFieldEditor:":
                onInput("\r")
                return true
            case "insertTab:":
                onInput("\t")
                return true
            case "deleteBackward:":
                onInput("\u{7F}")
                return true
            case "deleteForward:":
                onInput("\u{1B}[3~")
                return true
            case "cancelOperation:":
                onInput("\u{1B}")
                return true
            case "moveLeft:":
                onInput("\u{1B}[D")
                return true
            case "moveRight:":
                onInput("\u{1B}[C")
                return true
            case "moveUp:":
                onInput("\u{1B}[A")
                return true
            case "moveDown:":
                onInput("\u{1B}[B")
                return true
            case "moveToBeginningOfLine:":
                onInput("\u{1B}[H")
                return true
            case "moveToEndOfLine:":
                onInput("\u{1B}[F")
                return true
            case "pageUp:":
                onInput("\u{1B}[5~")
                return true
            case "pageDown:":
                onInput("\u{1B}[6~")
                return true
            default:
                return false
            }
        }

        func handleScrollWheel(_ event: NSEvent) {
            onScrollWheel(event)
        }

        func handleMouseDown(_ location: CGPoint) {
            onMouseDown(location)
        }

        func handleMouseDragged(_ location: CGPoint) {
            onMouseDragged(location)
        }

        func handleMouseUp(_ location: CGPoint) {
            onMouseUp(location)
        }

        private func specialKeySequence(for keyCode: UInt16) -> String? {
            switch keyCode {
            case 36, 76:
                return "\r"
            case 48:
                return "\t"
            case 51:
                return "\u{7F}"
            case 53:
                return "\u{1B}"
            case 114:
                return "\u{1B}[2~"
            case 115:
                return "\u{1B}[H"
            case 116:
                return "\u{1B}[5~"
            case 117:
                return "\u{1B}[3~"
            case 119:
                return "\u{1B}[F"
            case 121:
                return "\u{1B}[6~"
            case 122:
                return "\u{1B}OP"
            case 120:
                return "\u{1B}OQ"
            case 99:
                return "\u{1B}OR"
            case 118:
                return "\u{1B}OS"
            case 96:
                return "\u{1B}[15~"
            case 97:
                return "\u{1B}[17~"
            case 98:
                return "\u{1B}[18~"
            case 100:
                return "\u{1B}[19~"
            case 101:
                return "\u{1B}[20~"
            case 109:
                return "\u{1B}[21~"
            case 103:
                return "\u{1B}[23~"
            case 111:
                return "\u{1B}[24~"
            case 123:
                return "\u{1B}[D"
            case 124:
                return "\u{1B}[C"
            case 125:
                return "\u{1B}[B"
            case 126:
                return "\u{1B}[A"
            default:
                return nil
            }
        }
    }
}

private final class KeyCaptureView: NSView, NSTextInputClient {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onInsertText: ((String) -> Void)?
    var onCommandSelector: ((Selector) -> Bool)?
    var onScrollWheel: ((NSEvent) -> Void)?
    var onMouseDown: ((CGPoint) -> Void)?
    var onMouseDragged: ((CGPoint) -> Void)?
    var onMouseUp: ((CGPoint) -> Void)?

    private var markedTextStorage = NSMutableAttributedString()
    private var selectedRangeStorage = NSRange(location: NSNotFound, length: 0)

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }
        interpretKeyEvents([event])
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onMouseDown?(flippedPoint(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onMouseDragged?(flippedPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onMouseUp?(flippedPoint(for: event))
    }

    override func scrollWheel(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onScrollWheel?(event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusIfPossible()
    }

    func focusIfPossible() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
        }
    }

    private func flippedPoint(for event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        return CGPoint(x: local.x, y: bounds.height - local.y)
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        _ = replacementRange
        if let attributed = string as? NSAttributedString {
            onInsertText?(attributed.string)
        } else if let plain = string as? String {
            onInsertText?(plain)
        }
        markedTextStorage = NSMutableAttributedString()
    }

    override func doCommand(by selector: Selector) {
        if onCommandSelector?(selector) == true {
            return
        }
        super.doCommand(by: selector)
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        _ = replacementRange
        if let attributed = string as? NSAttributedString {
            markedTextStorage = NSMutableAttributedString(attributedString: attributed)
        } else if let plain = string as? String {
            markedTextStorage = NSMutableAttributedString(string: plain)
        } else {
            markedTextStorage = NSMutableAttributedString()
        }
        selectedRangeStorage = selectedRange
    }

    func unmarkText() {
        markedTextStorage = NSMutableAttributedString()
        selectedRangeStorage = NSRange(location: NSNotFound, length: 0)
    }

    func selectedRange() -> NSRange {
        selectedRangeStorage
    }

    func markedRange() -> NSRange {
        if markedTextStorage.length == 0 {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: 0, length: markedTextStorage.length)
    }

    func hasMarkedText() -> Bool {
        markedTextStorage.length > 0
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = range
        return nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = range
        guard let window else { return .zero }
        return window.convertToScreen(convert(bounds, to: nil))
    }

    func characterIndex(for point: NSPoint) -> Int {
        _ = point
        return 0
    }

    func conversationIdentifier() -> Int {
        Int(bitPattern: Unmanaged.passUnretained(self).toOpaque())
    }
}

private extension String {
    func trimmingTrailingSpaces() -> String {
        var value = self
        while value.last == " " {
            value.removeLast()
        }
        return value
    }
}
