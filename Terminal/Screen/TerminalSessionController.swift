import CoreGraphics
import Combine
import Foundation

@MainActor
public final class TerminalSessionController: ObservableObject {
    @Published public private(set) var renderVersion: UInt64 = 0
    @Published public private(set) var startupError: String?

    public let process: PTYProcess
    public let emulator: TerminalEmulator

    private let bridge: PTYEmulatorBridge
    private var latestBuffer: ScreenBuffer
    private var hasStarted = false
    private var lastRequestedSize: (rows: Int, cols: Int)?

    public init(
        initialRows: Int = 24,
        initialCols: Int = 80,
        shellPath: String = "/bin/zsh",
        env: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let bridge = PTYEmulatorBridge(
            rows: initialRows,
            cols: initialCols,
            shellPath: shellPath,
            env: env
        )

        self.bridge = bridge
        self.process = bridge.process
        self.emulator = bridge.emulator
        self.latestBuffer = bridge.snapshot()

        bridge.screenUpdateHandlerQueue = .main
        bridge.processExitHandlerQueue = .main
        bridge.onScreenBufferUpdated = { [weak self] updatedBuffer in
            self?.applyUpdatedBuffer(updatedBuffer)
        }
        bridge.onProcessExit = { [weak self] _ in
            self?.renderVersion &+= 1
        }

        startIfNeeded()
    }

    public func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            try bridge.start()
            applyUpdatedBuffer(bridge.snapshot())
        } catch {
            startupError = String(describing: error)
        }
    }

    public func snapshot() -> ScreenBuffer {
        latestBuffer
    }

    public func sendInput(_ text: String) {
        guard !text.isEmpty else { return }

        do {
            try bridge.write(text)
        } catch {
            startupError = String(describing: error)
        }
    }

    public func sendCtrlC() {
        do {
            try bridge.sendCtrlC()
        } catch {
            startupError = String(describing: error)
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
            applyUpdatedBuffer(bridge.snapshot())
        }
    }

    private func applyUpdatedBuffer(_ buffer: ScreenBuffer) {
        latestBuffer = buffer
        renderVersion &+= 1
    }
}
