import XCTest
@testable import glass_term

final class BlockBoundaryManagerTests: XCTestCase {
    func testSingleCommandFinalizesOnPromptMarker() {
        let manager = BlockBoundaryManager()

        manager.registerUserInput("echo hello\r")
        manager.processOutput("hello\n<<<BLOCK_PROMPT>>>:0 ")

        XCTAssertNil(manager.activeBlock)
        XCTAssertEqual(manager.blocks.count, 1)

        let block = manager.blocks[0]
        XCTAssertEqual(block.command, "echo hello")
        XCTAssertEqual(block.stdout, "hello\n")
        XCTAssertEqual(block.stderr, "")
        XCTAssertEqual(block.exitCode, 0)
        XCTAssertEqual(block.status, .success)
        XCTAssertNotNil(block.finishedAt)
    }

    func testMultipleCommandsInSequence() {
        let manager = BlockBoundaryManager()

        manager.registerUserInput("false\n")
        manager.processOutput("failed\n<<<BLOCK_PROMPT>>>:1 ")

        manager.registerUserInput("true\n")
        manager.processOutput("ok\n<<<BLOCK_PROMPT>>>:0 ")

        XCTAssertNil(manager.activeBlock)
        XCTAssertEqual(manager.blocks.count, 2)

        XCTAssertEqual(manager.blocks[0].command, "false")
        XCTAssertEqual(manager.blocks[0].stdout, "failed\n")
        XCTAssertEqual(manager.blocks[0].exitCode, 1)
        XCTAssertEqual(manager.blocks[0].status, .failure)

        XCTAssertEqual(manager.blocks[1].command, "true")
        XCTAssertEqual(manager.blocks[1].stdout, "ok\n")
        XCTAssertEqual(manager.blocks[1].exitCode, 0)
        XCTAssertEqual(manager.blocks[1].status, .success)
    }

    func testMultipleMarkersInSingleOutputChunk() {
        let manager = BlockBoundaryManager()

        manager.registerUserInput("cmd\n")
        manager.processOutput("line\n<<<BLOCK_PROMPT>>>:0 <<<BLOCK_PROMPT>>>:1 ")

        XCTAssertNil(manager.activeBlock)
        XCTAssertEqual(manager.blocks.count, 1)
        XCTAssertEqual(manager.blocks[0].stdout, "line\n")
        XCTAssertEqual(manager.blocks[0].exitCode, 0)
        XCTAssertEqual(manager.blocks[0].status, .success)
    }

    func testMarkerSplitAcrossOutputChunks() {
        let manager = BlockBoundaryManager()

        manager.registerUserInput("echo split\n")
        manager.processOutput("before marker\n<<<BLOCK_PROM")
        manager.processOutput("PT>>>:127 ")

        XCTAssertNil(manager.activeBlock)
        XCTAssertEqual(manager.blocks.count, 1)

        let block = manager.blocks[0]
        XCTAssertEqual(block.command, "echo split")
        XCTAssertEqual(block.stdout, "before marker\n")
        XCTAssertEqual(block.exitCode, 127)
        XCTAssertEqual(block.status, .failure)
    }

    func testAlternateScreenSuspendsDetection() {
        let manager = BlockBoundaryManager()

        manager.alternateScreenChanged(isActive: true)
        manager.registerUserInput("vim\n")
        manager.processOutput("vim buffer<<<BLOCK_PROMPT>>>:0 ")

        XCTAssertNil(manager.activeBlock)
        XCTAssertTrue(manager.blocks.isEmpty)

        manager.alternateScreenChanged(isActive: false)
        manager.registerUserInput("echo resumed\n")
        manager.processOutput("resumed\n<<<BLOCK_PROMPT>>>:0 ")

        XCTAssertNil(manager.activeBlock)
        XCTAssertEqual(manager.blocks.count, 1)
        XCTAssertEqual(manager.blocks[0].command, "echo resumed")
        XCTAssertEqual(manager.blocks[0].stdout, "resumed\n")
        XCTAssertEqual(manager.blocks[0].status, .success)
    }
}
