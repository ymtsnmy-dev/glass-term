import AppKit
import SwiftUI

public struct TerminalView: View {
    @ObservedObject private var session: TerminalSessionController

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
                        startDisplayRow: viewportStartDisplayRow
                    )
                    drawCursor(
                        context: &context,
                        buffer: buffer,
                        startDisplayRow: viewportStartDisplayRow
                    )
                }
                .id(renderVersion)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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

                TerminalKeyInputView(
                    onInput: { text in
                        session.sendInput(text)
                    },
                    onCtrlC: {
                        session.sendCtrlC()
                    },
                    onScrollWheel: { event in
                        session.handlePointerScroll(
                            deltaY: event.scrollingDeltaY,
                            precise: event.hasPreciseScrollingDeltas
                        )
                    },
                    onMouseDown: { point in
                        guard point.x >= 0, point.y >= 0 else { return }

                        let col = Int(floor(point.x / cellSize.width))
                        let row = Int(floor(point.y / cellSize.height))
                        let displayRow = viewportStartDisplayRow + row
                        session.handlePointerCursorMove(
                            targetDisplayRow: displayRow,
                            targetCol: col
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
            .clipped()
            .onAppear {
                session.startIfNeeded()
                session.resizeIfNeeded(viewSize: viewSize, cellSize: cellSize)
            }
            .onChange(of: viewSize) { _, newSize in
                session.resizeIfNeeded(viewSize: newSize, cellSize: cellSize)
            }
        }
    }

    private static func measureCellSize(for font: NSFont) -> CGSize {
        let width = font.maximumAdvancement.width
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
        startDisplayRow: Int
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
                    displayRow: startDisplayRow + row
                )
            }
        }
    }

    private func drawCell(
        context: inout GraphicsContext,
        buffer: ScreenBuffer,
        row: Int,
        col: Int,
        displayRow: Int
    ) {
        let frame = CGRect(
            x: CGFloat(col) * cellSize.width,
            y: CGFloat(row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
        let cell = buffer.cellAtDisplayRow(displayRow, col: col)
        context.fill(Path(frame), with: .color(resolvedBackgroundColor(for: cell)))
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
        guard cursor.row >= 0, cursor.row < buffer.rows else { return }
        guard cursor.col >= 0, cursor.col < buffer.cols else { return }

        let cursorDisplayRow = buffer.scrollbackRows + cursor.row
        let localRow = cursorDisplayRow - startDisplayRow
        guard localRow >= 0, localRow < buffer.rows else {
            return
        }

        let frame = CGRect(
            x: CGFloat(cursor.col) * cellSize.width,
            y: CGFloat(localRow) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )

        context.fill(Path(frame), with: .color(cursorColor))
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
}

private struct TerminalKeyInputView: NSViewRepresentable {
    let onInput: (String) -> Void
    let onCtrlC: () -> Void
    let onScrollWheel: (NSEvent) -> Void
    let onMouseDown: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onInput: onInput,
            onCtrlC: onCtrlC,
            onScrollWheel: onScrollWheel,
            onMouseDown: onMouseDown
        )
    }

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = context.coordinator.handleKeyDown
        view.onScrollWheel = context.coordinator.handleScrollWheel
        view.onMouseDown = context.coordinator.handleMouseDown
        view.focusIfPossible()
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = context.coordinator.handleKeyDown
        nsView.onScrollWheel = context.coordinator.handleScrollWheel
        nsView.onMouseDown = context.coordinator.handleMouseDown
        nsView.focusIfPossible()
    }

    final class Coordinator {
        private let onInput: (String) -> Void
        private let onCtrlC: () -> Void
        private let onScrollWheel: (NSEvent) -> Void
        private let onMouseDown: (CGPoint) -> Void

        init(
            onInput: @escaping (String) -> Void,
            onCtrlC: @escaping () -> Void,
            onScrollWheel: @escaping (NSEvent) -> Void,
            onMouseDown: @escaping (CGPoint) -> Void
        ) {
            self.onInput = onInput
            self.onCtrlC = onCtrlC
            self.onScrollWheel = onScrollWheel
            self.onMouseDown = onMouseDown
        }

        func handleKeyDown(_ event: NSEvent) {
            if event.modifierFlags.contains(.command),
               let commandCharacter = event.charactersIgnoringModifiers?.lowercased() {
                if commandCharacter == "v",
                   let pasted = NSPasteboard.general.string(forType: .string),
                   !pasted.isEmpty {
                    onInput(pasted)
                }
                return
            }

            if event.modifierFlags.contains(.control),
               let controlCharacter = event.charactersIgnoringModifiers?.lowercased(),
               controlCharacter == "c" {
                onCtrlC()
                return
            }

            if let sequence = specialKeySequence(for: event.keyCode) {
                onInput(sequence)
                return
            }

            guard let characters = event.characters, !characters.isEmpty else {
                return
            }
            onInput(characters)
        }

        func handleScrollWheel(_ event: NSEvent) {
            onScrollWheel(event)
        }

        func handleMouseDown(_ location: CGPoint) {
            onMouseDown(location)
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

private final class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    var onScrollWheel: ((NSEvent) -> Void)?
    var onMouseDown: ((CGPoint) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let flippedPoint = CGPoint(x: point.x, y: bounds.height - point.y)
        onMouseDown?(flippedPoint)
        super.mouseDown(with: event)
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
}
