import AppKit
import XCTest
@testable import glass_term

@MainActor
final class CopyQueueManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NSPasteboard.general.clearContents()
    }

    func testFIFOOrderAndCopyAllOutput() {
        let manager = CopyQueueManager()
        let blockA = makeBlock(command: "echo A", stdout: "A\n")
        let blockB = makeBlock(command: "echo B", stdout: "B\n")
        let blockC = makeBlock(command: "echo C", stdout: "C\n")

        manager.append(block: blockA)
        manager.append(block: blockB)
        manager.append(block: blockC)

        XCTAssertEqual(manager.items.count, 3)
        XCTAssertEqual(manager.items.map(\.formattedText), [
            formatted(command: "echo A", stdout: "A\n", stderr: ""),
            formatted(command: "echo B", stdout: "B\n", stderr: ""),
            formatted(command: "echo C", stdout: "C\n", stderr: "")
        ])

        manager.copyAllToPasteboard()

        let pasteboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(
            pasteboardText,
            [
                formatted(command: "echo A", stdout: "A\n", stderr: ""),
                formatted(command: "echo B", stdout: "B\n", stderr: ""),
                formatted(command: "echo C", stdout: "C\n", stderr: "")
            ].joined(separator: "\n\n")
        )
    }

    func testRemoveMiddleItemPreservesOrder() {
        let manager = CopyQueueManager()
        manager.append(block: makeBlock(command: "A", stdout: "1", stderr: ""))
        manager.append(block: makeBlock(command: "B", stdout: "2", stderr: ""))
        manager.append(block: makeBlock(command: "C", stdout: "3", stderr: ""))

        let middleID = manager.items[1].id
        manager.remove(id: middleID)

        XCTAssertEqual(manager.items.count, 2)
        XCTAssertEqual(manager.items[0].formattedText, formatted(command: "A", stdout: "1", stderr: ""))
        XCTAssertEqual(manager.items[1].formattedText, formatted(command: "C", stdout: "3", stderr: ""))
    }

    func testClearRemovesAllItems() {
        let manager = CopyQueueManager()
        manager.append(block: makeBlock(command: "cmd", stdout: "out", stderr: ""))
        manager.append(block: makeBlock(command: "cmd2", stdout: "out2", stderr: ""))

        manager.clear()

        XCTAssertTrue(manager.items.isEmpty)

        manager.clear()
        XCTAssertTrue(manager.items.isEmpty)
    }

    func testRepeatedAppendAddsExactlyOncePerCall() {
        let manager = CopyQueueManager()
        let block = makeBlock(command: "echo same", stdout: "same", stderr: "")

        for _ in 0..<10 {
            manager.append(block: block)
        }

        XCTAssertEqual(manager.items.count, 10)
        XCTAssertEqual(Set(manager.items.map(\.id)).count, 10)
        XCTAssertEqual(
            manager.items.map(\.formattedText),
            Array(repeating: formatted(command: "echo same", stdout: "same", stderr: ""), count: 10)
        )
    }

    func testStdErrOnlyFormattingHasNoExtraBlankLineAfterSeparator() {
        let manager = CopyQueueManager()
        manager.append(block: makeBlock(command: "false", stdout: "", stderr: "error\n"))

        XCTAssertEqual(
            manager.items.first?.formattedText,
            "$ false\n----------------------------------------\nerror\n"
        )
    }

    private func makeBlock(command: String, stdout: String, stderr: String = "") -> Block {
        Block(
            command: command,
            stdout: stdout,
            stderr: stderr,
            startedAt: Date(timeIntervalSince1970: 0),
            finishedAt: Date(timeIntervalSince1970: 1),
            exitCode: stderr.isEmpty ? 0 : 1,
            status: stderr.isEmpty ? .success : .failure
        )
    }

    private func formatted(command: String, stdout: String, stderr: String) -> String {
        var result = "$ \(command)\n----------------------------------------\n"
        result += stdout
        if !stderr.isEmpty {
            if !stdout.isEmpty && !result.hasSuffix("\n") {
                result += "\n"
            }
            result += stderr
        }
        return result
    }
}
