import Foundation

public struct ScreenColor: Sendable, Equatable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = ScreenColor(red: 255, green: 255, blue: 255)
    public static let black = ScreenColor(red: 0, green: 0, blue: 0)
}

public struct ScreenCellStyle: Sendable, Equatable {
    public var foreground: ScreenColor
    public var background: ScreenColor
    public var usesDefaultForeground: Bool
    public var usesDefaultBackground: Bool

    public init(
        foreground: ScreenColor,
        background: ScreenColor,
        usesDefaultForeground: Bool,
        usesDefaultBackground: Bool
    ) {
        self.foreground = foreground
        self.background = background
        self.usesDefaultForeground = usesDefaultForeground
        self.usesDefaultBackground = usesDefaultBackground
    }

    public static let `default` = ScreenCellStyle(
        foreground: .white,
        background: .black,
        usesDefaultForeground: true,
        usesDefaultBackground: true
    )
}

public struct ScreenCell: Sendable, Equatable {
    public static let blank = ScreenCell(
        text: " ",
        width: 1,
        styleSignature: 0,
        style: .default
    )

    public var text: String
    public var width: Int
    public var styleSignature: UInt64
    public var style: ScreenCellStyle

    public init(
        text: String,
        width: Int,
        styleSignature: UInt64 = 0,
        style: ScreenCellStyle = .default
    ) {
        self.text = text
        self.width = width
        self.styleSignature = styleSignature
        self.style = style
    }
}

public struct ScreenBuffer: Sendable, Equatable {
    public enum CursorShape: Sendable, Equatable {
        case block
        case underline
        case bar
    }

    public struct Cursor: Sendable, Equatable {
        public var row: Int
        public var col: Int
        public var visible: Bool

        public init(row: Int, col: Int, visible: Bool = true) {
            self.row = row
            self.col = col
            self.visible = visible
        }
    }

    public private(set) var rows: Int
    public private(set) var cols: Int
    public private(set) var isAlternate: Bool
    public private(set) var cursor: Cursor
    public private(set) var cursorShape: CursorShape
    public private(set) var cursorBlink: Bool
    public private(set) var windowTitle: String
    public private(set) var bellSequence: UInt64
    public private(set) var isBracketedPasteEnabled: Bool
    private var storage: [ScreenCell]
    private var scrollbackStorage: [[ScreenCell]]
    private var scrollbackStartIndex: Int

    public init(rows: Int, cols: Int, isAlternate: Bool) {
        precondition(rows > 0 && cols > 0, "ScreenBuffer size must be positive")
        self.rows = rows
        self.cols = cols
        self.isAlternate = isAlternate
        self.cursor = Cursor(row: 0, col: 0, visible: true)
        self.cursorShape = .block
        self.cursorBlink = true
        self.windowTitle = ""
        self.bellSequence = 0
        self.isBracketedPasteEnabled = false
        self.storage = Array(repeating: .blank, count: rows * cols)
        self.scrollbackStorage = []
        self.scrollbackStartIndex = 0
    }

    public subscript(row: Int, col: Int) -> ScreenCell {
        storage[index(row: row, col: col)]
    }

    public func rowText(_ row: Int) -> String {
        guard row >= 0 && row < rows else { return "" }

        var result = ""
        result.reserveCapacity(cols)

        for col in 0..<cols {
            let cell = self[row, col]
            if cell.width > 0 {
                result += cell.text
            }
        }

        return result
    }

    public var scrollbackRows: Int {
        scrollbackStorage.count
    }

    public var totalRows: Int {
        scrollbackRows + rows
    }

    public func cellAtDisplayRow(_ displayRow: Int, col: Int) -> ScreenCell {
        guard col >= 0 && col < cols else { return .blank }
        guard displayRow >= 0 && displayRow < totalRows else { return .blank }

        if displayRow < scrollbackRows {
            let row = scrollbackRow(atDisplayIndex: displayRow)
            guard col < row.count else { return .blank }
            return row[col]
        }

        return self[displayRow - scrollbackRows, col]
    }

    mutating func setCell(row: Int, col: Int, cell: ScreenCell) {
        guard row >= 0, row < rows, col >= 0, col < cols else { return }
        storage[index(row: row, col: col)] = cell
    }

    mutating func setCursor(row: Int, col: Int, visible: Bool? = nil) {
        cursor.row = clamp(row, lower: 0, upper: rows - 1)
        cursor.col = clamp(col, lower: 0, upper: cols - 1)
        if let visible {
            cursor.visible = visible
        }
    }

    mutating func setCursorShape(number: Int) {
        switch number {
        case 2:
            cursorShape = .underline
        case 3:
            cursorShape = .bar
        default:
            cursorShape = .block
        }
    }

    mutating func setCursorBlink(_ value: Bool) {
        cursorBlink = value
    }

    mutating func setWindowTitle(_ title: String) {
        windowTitle = title
    }

    mutating func setBellSequence(_ value: UInt64) {
        bellSequence = value
    }

    mutating func incrementBellSequence() {
        bellSequence &+= 1
    }

    mutating func setBracketedPasteEnabled(_ value: Bool) {
        isBracketedPasteEnabled = value
    }

    mutating func resize(rows newRows: Int, cols newCols: Int) {
        precondition(newRows > 0 && newCols > 0, "ScreenBuffer size must be positive")

        var newStorage = Array(repeating: ScreenCell.blank, count: newRows * newCols)

        let copyRows = min(rows, newRows)
        let copyCols = min(cols, newCols)

        for row in 0..<copyRows {
            for col in 0..<copyCols {
                let oldIndex = index(row: row, col: col)
                let newIndex = row * newCols + col
                newStorage[newIndex] = storage[oldIndex]
            }
        }

        rows = newRows
        cols = newCols
        storage = newStorage
        normalizeScrollbackWidths(targetCols: newCols)
        setCursor(row: cursor.row, col: cursor.col)
    }

    mutating func replaceVisibleStorage(_ newStorage: [ScreenCell]) {
        guard newStorage.count == storage.count else { return }
        storage = newStorage
    }

    mutating func pushScrollbackRow(_ row: [ScreenCell], limit: Int) {
        guard limit > 0 else { return }
        let normalized = normalizeRow(row, toCols: cols)
        truncateScrollbackIfNeeded(limit: limit)

        if scrollbackStorage.count < limit {
            scrollbackStorage.append(normalized)
            return
        }

        if scrollbackStorage.isEmpty {
            scrollbackStorage.append(normalized)
            scrollbackStartIndex = 0
            return
        }

        scrollbackStorage[scrollbackStartIndex] = normalized
        scrollbackStartIndex = (scrollbackStartIndex + 1) % scrollbackStorage.count
    }

    mutating func clearScrollback() {
        scrollbackStorage.removeAll(keepingCapacity: true)
        scrollbackStartIndex = 0
    }

    mutating func moveRect(
        destStartRow: Int,
        destEndRow: Int,
        destStartCol: Int,
        destEndCol: Int,
        srcStartRow: Int,
        srcStartCol: Int
    ) {
        let height = max(0, destEndRow - destStartRow)
        let width = max(0, destEndCol - destStartCol)
        guard height > 0 && width > 0 else { return }

        var movedCells: [ScreenCell] = []
        movedCells.reserveCapacity(height * width)

        for rowOffset in 0..<height {
            for colOffset in 0..<width {
                let sourceRow = srcStartRow + rowOffset
                let sourceCol = srcStartCol + colOffset
                movedCells.append(cellOrBlank(row: sourceRow, col: sourceCol))
            }
        }

        var offset = 0
        for rowOffset in 0..<height {
            for colOffset in 0..<width {
                setCell(
                    row: destStartRow + rowOffset,
                    col: destStartCol + colOffset,
                    cell: movedCells[offset]
                )
                offset += 1
            }
        }
    }

    private func cellOrBlank(row: Int, col: Int) -> ScreenCell {
        guard row >= 0, row < rows, col >= 0, col < cols else {
            return .blank
        }
        return storage[index(row: row, col: col)]
    }

    private func index(row: Int, col: Int) -> Int {
        precondition(row >= 0 && row < rows && col >= 0 && col < cols, "Index out of range")
        return row * cols + col
    }

    private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }

    private mutating func normalizeScrollbackWidths(targetCols: Int) {
        for index in scrollbackStorage.indices {
            scrollbackStorage[index] = normalizeRow(scrollbackStorage[index], toCols: targetCols)
        }
    }

    private mutating func truncateScrollbackIfNeeded(limit: Int) {
        guard scrollbackStorage.count > limit else { return }

        let keepCount = min(limit, scrollbackRows)
        if keepCount == 0 {
            scrollbackStorage.removeAll(keepingCapacity: true)
            scrollbackStartIndex = 0
            return
        }

        let startDisplayIndex = scrollbackRows - keepCount
        var normalized: [[ScreenCell]] = []
        normalized.reserveCapacity(keepCount)
        for displayIndex in startDisplayIndex..<scrollbackRows {
            normalized.append(scrollbackRow(atDisplayIndex: displayIndex))
        }
        scrollbackStorage = normalized
        scrollbackStartIndex = 0
    }

    private func scrollbackRow(atDisplayIndex displayIndex: Int) -> [ScreenCell] {
        guard !scrollbackStorage.isEmpty else { return [] }
        let mapped = (scrollbackStartIndex + displayIndex) % scrollbackStorage.count
        return scrollbackStorage[mapped]
    }

    private func normalizeRow(_ row: [ScreenCell], toCols targetCols: Int) -> [ScreenCell] {
        var normalized = Array(repeating: ScreenCell.blank, count: targetCols)
        let copyCount = min(targetCols, row.count)
        for col in 0..<copyCount {
            normalized[col] = row[col]
        }
        return normalized
    }
}
