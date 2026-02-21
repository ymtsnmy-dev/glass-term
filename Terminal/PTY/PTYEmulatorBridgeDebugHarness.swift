#if DEBUG
import Foundation

final class PTYEmulatorBridgeDebugHarness {
    static let shared = PTYEmulatorBridgeDebugHarness()

    private let lock = NSLock()
    private var bridge: PTYEmulatorBridge?
    private var hasStarted = false
    private var lastPreview = ""

    private init() {}

    func startIfNeeded(rows: Int = 24, cols: Int = 80) {
        lock.lock()
        if hasStarted {
            lock.unlock()
            return
        }
        hasStarted = true
        lock.unlock()

        let bridge = PTYEmulatorBridge(rows: rows, cols: cols)
        bridge.screenUpdateHandlerQueue = .main
        bridge.processExitHandlerQueue = .main
        bridge.onScreenBufferUpdated = { [weak self] buffer in
            self?.printScreenPreview(buffer)
        }
        bridge.onProcessExit = { code in
            print("[BridgeHarness] process exited code=\(String(describing: code))")
        }

        do {
            try bridge.start()
            lock.lock()
            self.bridge = bridge
            lock.unlock()
            print("[BridgeHarness] started rows=\(rows) cols=\(cols)")
        } catch {
            lock.lock()
            hasStarted = false
            lock.unlock()
            print("[BridgeHarness] failed to start: \(error)")
        }
    }

    func runSampleCommands() {
        schedule(after: 0.2) { [weak self] in
            self?.send("ls\n")
        }
        schedule(after: 0.8) { [weak self] in
            self?.send("clear\n")
        }
        schedule(after: 1.4) { [weak self] in
            self?.send("printf '\\033[31mRED\\033[0m\\n'\n")
        }
    }

    func stop() {
        lock.lock()
        let bridge = self.bridge
        self.bridge = nil
        self.hasStarted = false
        self.lastPreview = ""
        lock.unlock()

        bridge?.terminate()
        print("[BridgeHarness] stopped")
    }

    private func send(_ command: String) {
        let bridge: PTYEmulatorBridge? = {
            lock.lock()
            defer { lock.unlock() }
            return self.bridge
        }()

        guard let bridge else {
            print("[BridgeHarness] bridge is not running")
            return
        }

        do {
            try bridge.write(command)
            print("[BridgeHarness] sent: \(command.trimmingCharacters(in: .whitespacesAndNewlines))")
        } catch {
            print("[BridgeHarness] send failed: \(error)")
        }
    }

    private func schedule(after seconds: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
    }

    private func printScreenPreview(_ buffer: ScreenBuffer, maxRows: Int = 6) {
        let metadata =
            "size=\(buffer.rows)x\(buffer.cols) " +
            "alt=\(buffer.isAlternate) " +
            "cursor=(\(buffer.cursor.row),\(buffer.cursor.col),vis:\(buffer.cursor.visible))"
        let lines = topLines(from: buffer, maxRows: maxRows)
        let rowCount = lines.count + 1

        let preview = ([metadata] + lines).joined(separator: "\n")
        if preview == lastPreview {
            return
        }
        lastPreview = preview

        print("[BridgeHarness] screen top \(rowCount) rows:")
        print("00|\(metadata)")
        for (index, line) in lines.enumerated() {
            print(String(format: "%02d|%@", index + 1, line))
        }
    }

    private func topLines(from buffer: ScreenBuffer, maxRows: Int) -> [String] {
        guard buffer.rows > 0, buffer.cols > 0 else {
            return ["<empty buffer>"]
        }

        let rowLimit = min(maxRows, buffer.rows)
        var lines: [String] = []
        lines.reserveCapacity(rowLimit)

        for row in 0..<rowLimit {
            lines.append(renderRow(buffer, row: row))
        }

        return lines
    }

    private func renderRow(_ buffer: ScreenBuffer, row: Int) -> String {
        var line = ""
        line.reserveCapacity(buffer.cols)

        for col in 0..<buffer.cols {
            let cell = buffer[row, col]
            guard cell.width > 0 else { continue }
            line += cell.text.isEmpty ? " " : cell.text
        }

        return line
    }
}
#endif
