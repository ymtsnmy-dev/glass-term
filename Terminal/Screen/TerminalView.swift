import AppKit
import SwiftUI

public struct TerminalView: View {
    @ObservedObject private var session: TerminalSessionController

    private let font: Font
    private let cellSize: CGSize
    private let textColor: Color
    private let backgroundColor: Color
    private let cursorColor: Color

    public init(
        session: TerminalSessionController,
        fontSize: CGFloat = 14,
        textColor: Color = .white,
        backgroundColor: Color = .black,
        cursorColor: Color = .white
    ) {
        let resolvedFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        self.session = session
        self.font = .system(size: resolvedFont.pointSize, weight: .regular, design: .monospaced)
        self.cellSize = Self.measureCellSize(for: resolvedFont)
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.cursorColor = cursorColor
    }

    public var body: some View {
        GeometryReader { proxy in
            let viewSize = proxy.size
            let _ = session.renderVersion
            let buffer = session.snapshot()

            ZStack {
                Canvas(rendersAsynchronously: true) { context, canvasSize in
                    drawBackground(context: &context, size: canvasSize)
                    drawScreenBuffer(context: &context, size: canvasSize, buffer: buffer)
                    drawCursor(context: &context, buffer: buffer)
                }

                TerminalKeyInputView(
                    onInput: { text in
                        session.sendInput(text)
                    },
                    onCtrlC: {
                        session.sendCtrlC()
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
            .onChange(of: viewSize) { newSize in
                session.resizeIfNeeded(viewSize: newSize, cellSize: cellSize)
            }
        }
    }

    private static func measureCellSize(for font: NSFont) -> CGSize {
        let sample = "W" as NSString
        let width = ceil(sample.size(withAttributes: [.font: font]).width)
        let height = ceil(font.ascender - font.descender + font.leading)
        return CGSize(width: max(1, width), height: max(1, height))
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(backgroundColor)
        )
    }

    private func drawScreenBuffer(context: inout GraphicsContext, size: CGSize, buffer: ScreenBuffer) {
        let visibleRows = min(buffer.rows, max(0, Int(ceil(size.height / cellSize.height))))
        let visibleCols = min(buffer.cols, max(0, Int(ceil(size.width / cellSize.width))))

        guard visibleRows > 0, visibleCols > 0 else {
            return
        }

        for row in 0..<visibleRows {
            drawRow(
                context: &context,
                buffer: buffer,
                row: row,
                visibleCols: visibleCols
            )
        }
    }

    private func drawRow(
        context: inout GraphicsContext,
        buffer: ScreenBuffer,
        row: Int,
        visibleCols: Int
    ) {
        var col = 0

        while col < visibleCols {
            let cell = buffer[row, col]

            if cell.width <= 0 {
                col += 1
                continue
            }

            if cell.width > 1 {
                drawText(
                    text: cell.text.isEmpty ? " " : cell.text,
                    atColumn: col,
                    row: row,
                    color: textColor,
                    context: &context
                )
                col += cell.width
                continue
            }

            let runStartCol = col
            var run = ""
            run.reserveCapacity(visibleCols - runStartCol)

            while col < visibleCols {
                let runCell = buffer[row, col]
                guard runCell.width == 1 else {
                    break
                }
                run += runCell.text.isEmpty ? " " : runCell.text
                col += 1
            }

            if !run.isEmpty {
                drawText(
                    text: run,
                    atColumn: runStartCol,
                    row: row,
                    color: textColor,
                    context: &context
                )
            }
        }
    }

    private func drawCursor(context: inout GraphicsContext, buffer: ScreenBuffer) {
        let cursor = buffer.cursor
        guard cursor.visible else { return }
        guard cursor.row >= 0, cursor.row < buffer.rows else { return }
        guard cursor.col >= 0, cursor.col < buffer.cols else { return }

        let frame = CGRect(
            x: floor(CGFloat(cursor.col) * cellSize.width),
            y: floor(CGFloat(cursor.row) * cellSize.height),
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
        var resolved = context.resolve(rendered)
        resolved.shading = .color(color)
        context.draw(resolved, at: origin, anchor: .topLeading)
    }
}

private struct TerminalKeyInputView: NSViewRepresentable {
    let onInput: (String) -> Void
    let onCtrlC: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onInput: onInput, onCtrlC: onCtrlC)
    }

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = context.coordinator.handleKeyDown
        view.focusIfPossible()
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = context.coordinator.handleKeyDown
        nsView.focusIfPossible()
    }

    final class Coordinator {
        private let onInput: (String) -> Void
        private let onCtrlC: () -> Void

        init(onInput: @escaping (String) -> Void, onCtrlC: @escaping () -> Void) {
            self.onInput = onInput
            self.onCtrlC = onCtrlC
        }

        func handleKeyDown(_ event: NSEvent) {
            if event.modifierFlags.contains(.control),
               let controlCharacter = event.charactersIgnoringModifiers?.lowercased(),
               controlCharacter == "c" {
                onCtrlC()
                return
            }

            switch event.keyCode {
            case 36, 76:
                onInput("\r")
                return
            case 48:
                onInput("\t")
                return
            case 51:
                onInput("\u{7F}")
                return
            case 53:
                onInput("\u{1B}")
                return
            case 123:
                onInput("\u{1B}[D")
                return
            case 124:
                onInput("\u{1B}[C")
                return
            case 125:
                onInput("\u{1B}[B")
                return
            case 126:
                onInput("\u{1B}[A")
                return
            default:
                break
            }

            guard let characters = event.characters, !characters.isEmpty else {
                return
            }
            onInput(characters)
        }
    }
}

private final class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
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
