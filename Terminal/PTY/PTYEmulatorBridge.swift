import Foundation

public final class PTYEmulatorBridge {
    public var onScreenBufferUpdated: ((ScreenBuffer) -> Void)? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return onScreenBufferUpdatedStorage
        }
        set {
            stateLock.lock()
            onScreenBufferUpdatedStorage = newValue
            stateLock.unlock()
        }
    }

    public var onProcessExit: ((Int32?) -> Void)? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return onProcessExitStorage
        }
        set {
            stateLock.lock()
            onProcessExitStorage = newValue
            stateLock.unlock()
        }
    }

    public var screenUpdateHandlerQueue: DispatchQueue {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return screenUpdateHandlerQueueStorage
        }
        set {
            stateLock.lock()
            screenUpdateHandlerQueueStorage = newValue
            stateLock.unlock()
        }
    }

    public var processExitHandlerQueue: DispatchQueue {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return processExitHandlerQueueStorage
        }
        set {
            stateLock.lock()
            processExitHandlerQueueStorage = newValue
            stateLock.unlock()
        }
    }

    public var isRunning: Bool {
        process.isRunning
    }

    public let process: PTYProcess
    public let emulator: TerminalEmulator

    private let initialRows: Int
    private let initialCols: Int

    private let emulatorQueue = DispatchQueue(label: "com.glass-term.terminal.wiring.emulator")
    private let emulatorQueueKey = DispatchSpecificKey<UInt8>()
    private let ptyOutputQueue = DispatchQueue(label: "com.glass-term.terminal.wiring.pty-output")
    private let stateLock = NSLock()

    private var onScreenBufferUpdatedStorage: ((ScreenBuffer) -> Void)?
    private var onProcessExitStorage: ((Int32?) -> Void)?
    private var screenUpdateHandlerQueueStorage: DispatchQueue = .main
    private var processExitHandlerQueueStorage: DispatchQueue = .main

    public init(
        rows: Int,
        cols: Int,
        shellPath: String = "/bin/zsh",
        env: [String: String] = ProcessInfo.processInfo.environment
    ) {
        precondition(rows > 0 && cols > 0, "Terminal size must be positive")

        initialRows = rows
        initialCols = cols
        process = PTYProcess(shellPath: shellPath, env: env)
        emulator = TerminalEmulator(rows: rows, cols: cols)
        emulatorQueue.setSpecific(key: emulatorQueueKey, value: 1)

        process.outputHandlerQueue = ptyOutputQueue
        process.onOutput = { [weak self] data in
            self?.enqueueFeed(data)
        }
        process.onExit = { [weak self] code in
            self?.emitProcessExit(code: code)
        }
    }

    deinit {
        terminate()
    }

    public func start() throws {
        try process.start(rows: initialRows, cols: initialCols)
    }

    public func write(_ data: Data) throws {
        try process.write(data)
    }

    public func write(_ string: String) throws {
        try process.write(string)
    }

    public func sendCtrlC() throws {
        try process.sendCtrlC()
    }

    public func resize(rows: Int, cols: Int) throws {
        try process.resize(rows: rows, cols: cols)

        emulatorQueue.async { [weak self] in
            guard let self else { return }
            self.emulator.resize(rows: rows, cols: cols)
            self.emitScreenBufferUpdated(buffer: self.snapshot())
        }
    }

    public func snapshot() -> ScreenBuffer {
        if DispatchQueue.getSpecific(key: emulatorQueueKey) != nil {
            return emulator.snapshot()
        }

        emulatorQueue.sync {
            emulator.snapshot()
        }
    }

    public func terminate() {
        process.terminate()
    }

    private func enqueueFeed(_ data: Data) {
        guard !data.isEmpty else { return }

        emulatorQueue.async { [weak self] in
            guard let self else { return }
            self.emulator.feed(data)
            self.emitScreenBufferUpdated(buffer: self.snapshot())
        }
    }

    private func emitScreenBufferUpdated(buffer: ScreenBuffer) {
        let callbackState: (((ScreenBuffer) -> Void)?, DispatchQueue) = {
            stateLock.lock()
            defer { stateLock.unlock() }
            return (onScreenBufferUpdatedStorage, screenUpdateHandlerQueueStorage)
        }()

        guard let callback = callbackState.0 else {
            return
        }

        callbackState.1.async {
            callback(buffer)
        }
    }

    private func emitProcessExit(code: Int32?) {
        let callbackState: (((Int32?) -> Void)?, DispatchQueue) = {
            stateLock.lock()
            defer { stateLock.unlock() }
            return (onProcessExitStorage, processExitHandlerQueueStorage)
        }()

        guard let callback = callbackState.0 else {
            return
        }

        callbackState.1.async {
            callback(code)
        }
    }
}
