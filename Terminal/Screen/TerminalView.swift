import AppKit
import Combine
import SwiftUI

@MainActor
public final class TerminalViewModel: ObservableObject {
    @Published public private(set) var buffer: ScreenBuffer

    private let bridge: PTYEmulatorBridge
    private var lastRequestedSize: (rows: Int, cols: Int)?

    public init(bridge: PTYEmulatorBridge) {
        self.bridge = bridge
        self.buffer = bridge.snapshot()

        bridge.screenUpdateHandlerQueue = .main
        bridge.onScreenBufferUpdated = { [weak self] updatedBuffer in
            self?.buffer = updatedBuffer
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
            buffer = bridge.snapshot()
        }
    }
}

public struct TerminalView: View {
    @ObservedObject private var model: TerminalViewModel

    private let font: Font
    private let cellSize: CGSize
    private let textColor: Color
    private let backgroundColor: Color
    private let cursorColor: Color

    public init(
        model: TerminalViewModel,
        fontSize: CGFloat = 14,
        textColor: Color = .white,
        backgroundColor: Color = .black,
        cursorColor: Color = .white
    ) {
        let resolvedFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        self.model = model
        self.font = .custom(resolvedFont.fontName, size: resolvedFont.pointSize)
        self.cellSize = Self.measureCellSize(for: resolvedFont)
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.cursorColor = cursorColor
    }

    public var body: some View {
        GeometryReader { proxy in
            let viewSize = proxy.size

            Canvas(rendersAsynchronously: true) { context, canvasSize in
                drawBackground(context: &context, size: canvasSize)
                drawScreenBuffer(context: &context, size: canvasSize, buffer: model.buffer)
                drawCursor(context: &context, buffer: model.buffer)
            }
            .clipped()
            .onAppear {
                model.resizeIfNeeded(viewSize: viewSize, cellSize: cellSize)
            }
            .onChange(of: viewSize) { newSize in
                model.resizeIfNeeded(viewSize: newSize, cellSize: cellSize)
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
            .foregroundStyle(color)

        context.draw(rendered, at: origin, anchor: .topLeading)
    }
}
