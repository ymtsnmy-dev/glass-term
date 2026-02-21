import XCTest
@testable import glass_term

final class TerminalEmulatorTests: XCTestCase {
    func testPlainTextRendering() {
        let emulator = TerminalEmulator(rows: 6, cols: 20)

        emulator.feed(Data("Hello\nWorld".utf8))

        let snapshot = emulator.snapshot()
        let lines = snapshot.normalizedLines()
        let helloRow = lines.firstIndex(where: { $0.contains("Hello") })
        let worldRow = lines.firstIndex(where: { $0.contains("World") })

        XCTAssertNotNil(helloRow)
        XCTAssertNotNil(worldRow)
        XCTAssertNotEqual(helloRow, worldRow)
    }

    func testSGRChangesCellStyleSignature() {
        let emulator = TerminalEmulator(rows: 4, cols: 10)

        emulator.feed(Data("\u{001B}[31mR\u{001B}[0m".utf8))

        let snapshot = emulator.snapshot()
        let styledCell = snapshot[0, 0]
        let defaultCell = snapshot[0, 1]

        XCTAssertEqual(styledCell.text, "R")
        XCTAssertNotEqual(styledCell.styleSignature, defaultCell.styleSignature)
    }

    func testCursorMovementPlacesCharacterAtExpectedCell() {
        let emulator = TerminalEmulator(rows: 6, cols: 20)

        emulator.feed(Data("A\u{001B}[2;5H".utf8))
        emulator.feed(Data("B".utf8))

        let snapshot = emulator.snapshot()
        XCTAssertEqual(snapshot[0, 0].text, "A")

        // CSI row/col is 1-based; ScreenBuffer indexing is 0-based.
        XCTAssertEqual(snapshot[1, 4].text, "B")
    }

    func testClearScreenRemovesPreviousContent() {
        let emulator = TerminalEmulator(rows: 4, cols: 20)

        emulator.feed(Data("Hello\u{001B}[2J".utf8))

        let snapshot = emulator.snapshot()
        XCTAssertFalse(snapshot.asString().contains("Hello"))
    }

    func testAlternateScreenRestoresMainBufferOnExit() {
        let emulator = TerminalEmulator(rows: 6, cols: 20)

        emulator.feed(Data("MAIN".utf8))
        XCTAssertTrue(emulator.snapshot().asString().contains("MAIN"))

        emulator.feed(Data("\u{001B}[?1049h".utf8))
        emulator.feed(Data("ALT".utf8))

        switch emulator.activeBufferKind {
        case .alternate:
            break
        case .primary:
            XCTFail("Expected alternate screen after ?1049h")
        }

        XCTAssertTrue(emulator.snapshot().asString().contains("ALT"))

        emulator.feed(Data("\u{001B}[?1049l".utf8))

        switch emulator.activeBufferKind {
        case .primary:
            break
        case .alternate:
            XCTFail("Expected primary screen after ?1049l")
        }

        let snapshot = emulator.snapshot().asString()
        XCTAssertTrue(snapshot.contains("MAIN"))
        XCTAssertFalse(snapshot.contains("ALT"))
    }
}

private extension ScreenBuffer {
    func normalizedLines() -> [String] {
        (0..<rows).map { rowText($0).trimmingTrailingSpaces() }
    }

    func asString() -> String {
        normalizedLines().joined(separator: "\n")
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
