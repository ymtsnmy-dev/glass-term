import Foundation
import Darwin

@_silgen_name("fork")
private func posixFork() -> pid_t

public final class PTYProcess {
    public enum PTYProcessError: Error, LocalizedError {
        case alreadyRunning
        case notRunning
        case invalidSize(rows: Int, cols: Int)
        case utf8EncodingFailed
        case systemCallFailed(function: String, code: Int32)

        public var errorDescription: String? {
            switch self {
            case .alreadyRunning:
                return "PTY process is already running"
            case .notRunning:
                return "PTY process is not running"
            case let .invalidSize(rows, cols):
                return "Invalid terminal size rows=\(rows), cols=\(cols)"
            case .utf8EncodingFailed:
                return "Failed to encode string as UTF-8"
            case let .systemCallFailed(function, code):
                if let cString = strerror(code) {
                    return "\(function) failed: \(String(cString: cString)) (errno=\(code))"
                }
                return "\(function) failed (errno=\(code))"
            }
        }
    }

    public var onOutput: ((Data) -> Void)?
    public var onExit: ((Int32?) -> Void)?

    public var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return running
    }

    private let shellPath: String
    private let environment: [String: String]

    private let ioQueue = DispatchQueue(label: "com.glass-term.pty.io")
    private let stateLock = NSLock()

    private var masterFD: Int32 = -1
    private var childPID: pid_t = -1
    private var running = false
    private var exitNotified = false

    private var readSource: DispatchSourceRead?
    private var waitTimer: DispatchSourceTimer?

    public init(
        shellPath: String = "/bin/zsh",
        env: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.shellPath = shellPath
        self.environment = env
    }

    deinit {
        terminate()
    }

    public func start(rows: Int, cols: Int) throws {
        guard rows > 0, cols > 0 else {
            throw PTYProcessError.invalidSize(rows: rows, cols: cols)
        }

        stateLock.lock()
        if running {
            stateLock.unlock()
            throw PTYProcessError.alreadyRunning
        }
        stateLock.unlock()

        let openFlags = O_RDWR | O_NOCTTY | O_NONBLOCK
        let master = posix_openpt(openFlags)
        guard master >= 0 else {
            throw makeSystemError("posix_openpt")
        }

        var shouldCloseMaster = true
        defer {
            if shouldCloseMaster {
                _ = Darwin.close(master)
            }
        }

        guard grantpt(master) == 0 else {
            throw makeSystemError("grantpt")
        }

        guard unlockpt(master) == 0 else {
            throw makeSystemError("unlockpt")
        }

        guard let slaveName = ptsname(master) else {
            throw makeSystemError("ptsname")
        }
        let slavePath = String(cString: slaveName)

        let pid = posixFork()
        guard pid >= 0 else {
            throw makeSystemError("fork")
        }

        if pid == 0 {
            launchChildProcess(masterFD: master, slavePath: slavePath, rows: rows, cols: cols)
            _exit(127)
        }
        emitDebug("[PTYProcess] forked child pid=\(pid)\n")

        let currentFlags = fcntl(master, F_GETFL)
        guard currentFlags >= 0 else {
            throw makeSystemError("fcntl(F_GETFL)")
        }
        guard fcntl(master, F_SETFL, currentFlags | O_NONBLOCK) == 0 else {
            throw makeSystemError("fcntl(F_SETFL)")
        }

        stateLock.lock()
        masterFD = master
        childPID = pid
        running = true
        exitNotified = false
        stateLock.unlock()

        shouldCloseMaster = false

        startReadLoop(fd: master)
        startWaitLoop()
    }

    public func write(_ data: Data) throws {
        let fd = try runningMasterFD()
        guard !data.isEmpty else { return }

        try data.withUnsafeBytes { rawBuffer in
            guard var cursor = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            var remaining = rawBuffer.count

            while remaining > 0 {
                let written = Darwin.write(fd, cursor, remaining)
                if written > 0 {
                    remaining -= written
                    cursor = cursor.advanced(by: written)
                    continue
                }

                guard written == -1 else {
                    continue
                }

                if errno == EINTR {
                    continue
                }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    usleep(1_000)
                    continue
                }
                throw makeSystemError("write")
            }
        }
    }

    public func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw PTYProcessError.utf8EncodingFailed
        }
        try write(data)
    }

    public func sendCtrlC() throws {
        let pid = try runningChildPID()
        guard Darwin.kill(pid, SIGINT) == 0 else {
            throw makeSystemError("kill(SIGINT)")
        }
    }

    public func resize(rows: Int, cols: Int) throws {
        guard rows > 0, cols > 0 else {
            throw PTYProcessError.invalidSize(rows: rows, cols: cols)
        }

        let fd = try runningMasterFD()
        let pid = try runningChildPID()

        var size = winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )

        guard ioctl(fd, TIOCSWINSZ, &size) == 0 else {
            throw makeSystemError("ioctl(TIOCSWINSZ)")
        }

        guard Darwin.kill(pid, SIGWINCH) == 0 else {
            throw makeSystemError("kill(SIGWINCH)")
        }
    }

    public func terminate() {
        let snapshot = stopStateForTermination()

        if let readSource = snapshot.readSource {
            readSource.cancel()
        }
        if let waitTimer = snapshot.waitTimer {
            waitTimer.cancel()
        }

        if snapshot.masterFD >= 0 {
            _ = Darwin.close(snapshot.masterFD)
        }

        var exitCode: Int32? = nil

        if snapshot.childPID > 0 {
            if Darwin.kill(snapshot.childPID, SIGTERM) != 0 && errno != ESRCH {
                emitAsyncError("kill(SIGTERM)", errno: errno)
            }

            var status: Int32 = 0
            var reaped = false

            for _ in 0..<100 {
                let result = waitpid(snapshot.childPID, &status, WNOHANG)
                if result == snapshot.childPID {
                    logWaitStatus(context: "terminate(waitpid WNOHANG)", status: status)
                    reaped = true
                    exitCode = decodeExitCode(status)
                    break
                }
                if result == -1 {
                    if errno != ECHILD {
                        emitAsyncError("waitpid(WNOHANG)", errno: errno)
                    }
                    reaped = true
                    break
                }
                usleep(10_000)
            }

            if !reaped {
                if Darwin.kill(snapshot.childPID, SIGKILL) != 0 && errno != ESRCH {
                    emitAsyncError("kill(SIGKILL)", errno: errno)
                }

                let result = waitpid(snapshot.childPID, &status, 0)
                if result == snapshot.childPID {
                    logWaitStatus(context: "terminate(waitpid blocking)", status: status)
                    exitCode = decodeExitCode(status)
                } else if result == -1 && errno != ECHILD {
                    emitAsyncError("waitpid", errno: errno)
                }
            }
        }

        if snapshot.wasRunning || snapshot.childPID > 0 || snapshot.masterFD >= 0 {
            notifyExitIfNeeded(code: exitCode)
        }
    }

    private func launchChildProcess(masterFD: Int32, slavePath: String, rows: Int, cols: Int) {
        _ = Darwin.close(masterFD)

        guard setsid() >= 0 else {
            emitChildDebug("[PTYProcess child] setsid failed\n")
            childExitWithErrno("setsid")
        }
        emitChildDebug("[PTYProcess child] setsid succeeded\n")

        let slaveFD = Darwin.open(slavePath, O_RDWR)
        guard slaveFD >= 0 else {
            childExitWithErrno("open(slave)")
        }
        emitChildDebug("[PTYProcess child] open(slave) succeeded fd=\(slaveFD)\n")

        var size = winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(slaveFD, TIOCSWINSZ, &size)

        if ioctl(slaveFD, TIOCSCTTY, 0) == 0 {
            emitChildDebug("[PTYProcess child] ioctl(TIOCSCTTY) succeeded\n")
        } else if errno == EPERM {
            emitChildDebug("[PTYProcess child] ioctl(TIOCSCTTY) returned EPERM; continuing\n")
        } else {
            childExitWithErrno("ioctl(TIOCSCTTY)")
        }

        guard dup2(slaveFD, STDIN_FILENO) >= 0 else { childExitWithErrno("dup2(STDIN)") }
        guard dup2(slaveFD, STDOUT_FILENO) >= 0 else { childExitWithErrno("dup2(STDOUT)") }
        guard dup2(slaveFD, STDERR_FILENO) >= 0 else { childExitWithErrno("dup2(STDERR)") }

        if slaveFD > STDERR_FILENO {
            _ = Darwin.close(slaveFD)
        }

        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(shellPath), nil]

        var envStrings = environment.map { "\($0.key)=\($0.value)" }
        if envStrings.first(where: { $0.hasPrefix("TERM=") }) == nil {
            envStrings.append("TERM=xterm-256color")
        }

        var envp: [UnsafeMutablePointer<CChar>?] = envStrings.map { strdup($0) }
        envp.append(nil)

        argv.withUnsafeMutableBufferPointer { argvBuffer in
            envp.withUnsafeMutableBufferPointer { envBuffer in
                shellPath.withCString { shellCString in
                    _ = execve(shellCString, argvBuffer.baseAddress, envBuffer.baseAddress)
                }
            }
        }

        Darwin.perror("execve")
        childExitWithErrno("execve")
    }

    private func startReadLoop(fd: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: ioQueue)
        source.setEventHandler { [weak self] in
            self?.drainReadableData(fd: fd)
        }
        source.setCancelHandler {
            // no-op
        }

        stateLock.lock()
        readSource = source
        stateLock.unlock()

        source.resume()
    }

    private func startWaitLoop() {
        let timer = DispatchSource.makeTimerSource(queue: ioQueue)
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.pollChildExit()
        }
        timer.setCancelHandler {
            // no-op
        }

        stateLock.lock()
        waitTimer = timer
        stateLock.unlock()

        timer.resume()
    }

    private func drainReadableData(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let bytesRead = Darwin.read(fd, &buffer, buffer.count)

            if bytesRead > 0 {
                let data = Data(buffer.prefix(Int(bytesRead)))
                DispatchQueue.main.async { [weak self] in
                    self?.onOutput?(data)
                }
                continue
            }

            if bytesRead == 0 {
                emitDebug("[PTYProcess] read EOF (0 bytes)\n")
                pollChildExit()
                return
            }

            if errno == EINTR {
                continue
            }
            // EAGAIN/EWOULDBLOCK are normal for non-blocking PTY reads.
            if errno == EAGAIN || errno == EWOULDBLOCK {
                return
            }

            emitAsyncError("read", errno: errno)
            terminate()
            return
        }
    }

    private func pollChildExit() {
        let pid: pid_t = {
            stateLock.lock()
            defer { stateLock.unlock() }
            return childPID
        }()

        guard pid > 0 else {
            return
        }

        var status: Int32 = 0
        let result = waitpid(pid, &status, WNOHANG)

        if result == 0 {
            return
        }

        if result == -1 {
            if errno != ECHILD {
                emitAsyncError("waitpid(WNOHANG)", errno: errno)
            }
            notifyExitIfNeeded(code: nil)
            return
        }

        logWaitStatus(context: "pollChildExit(waitpid WNOHANG)", status: status)
        notifyExitIfNeeded(code: decodeExitCode(status))
    }

    private func notifyExitIfNeeded(code: Int32?) {
        let shouldNotify: Bool
        let callback: ((Int32?) -> Void)?
        let readSourceToCancel: DispatchSourceRead?
        let waitTimerToCancel: DispatchSourceTimer?
        let fdToClose: Int32

        stateLock.lock()
        if exitNotified {
            shouldNotify = false
            callback = nil
            readSourceToCancel = nil
            waitTimerToCancel = nil
            fdToClose = -1
        } else {
            exitNotified = true
            running = false

            callback = onExit
            readSourceToCancel = readSource
            waitTimerToCancel = waitTimer
            fdToClose = masterFD

            readSource = nil
            waitTimer = nil
            masterFD = -1
            childPID = -1
            shouldNotify = true
        }
        stateLock.unlock()

        guard shouldNotify else {
            return
        }

        readSourceToCancel?.cancel()
        waitTimerToCancel?.cancel()

        if fdToClose >= 0 {
            _ = Darwin.close(fdToClose)
        }

        DispatchQueue.main.async {
            callback?(code)
        }
    }

    private func stopStateForTermination() -> (
        wasRunning: Bool,
        childPID: pid_t,
        masterFD: Int32,
        readSource: DispatchSourceRead?,
        waitTimer: DispatchSourceTimer?
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }

        let snapshot = (
            wasRunning: running,
            childPID: childPID,
            masterFD: masterFD,
            readSource: readSource,
            waitTimer: waitTimer
        )

        running = false
        childPID = -1
        masterFD = -1
        readSource = nil
        waitTimer = nil

        return snapshot
    }

    private func runningMasterFD() throws -> Int32 {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard running, masterFD >= 0 else {
            throw PTYProcessError.notRunning
        }
        return masterFD
    }

    private func runningChildPID() throws -> pid_t {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard running, childPID > 0 else {
            throw PTYProcessError.notRunning
        }
        return childPID
    }

    private func makeSystemError(_ function: String) -> PTYProcessError {
        PTYProcessError.systemCallFailed(function: function, code: errno)
    }

    private func decodeExitCode(_ status: Int32) -> Int32? {
        if waitStatusExited(status) {
            return waitStatusExitCode(status)
        }
        if waitStatusSignaled(status) {
            return 128 + waitStatusTermSignal(status)
        }
        return nil
    }

    private func waitStatusExitCode(_ status: Int32) -> Int32 {
        (status >> 8) & 0xFF
    }

    private func waitStatusTermSignal(_ status: Int32) -> Int32 {
        status & 0x7F
    }

    private func waitStatusExited(_ status: Int32) -> Bool {
        waitStatusTermSignal(status) == 0
    }

    private func waitStatusSignaled(_ status: Int32) -> Bool {
        let signal = waitStatusTermSignal(status)
        return signal != 0 && signal != 0x7F
    }

    private func emitAsyncError(_ function: String, errno code: Int32) {
        let message: String
        if let cString = strerror(code) {
            message = "[PTYProcess] \(function) failed: \(String(cString: cString)) (errno=\(code))\n"
        } else {
            message = "[PTYProcess] \(function) failed (errno=\(code))\n"
        }

        if let data = message.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private func logWaitStatus(context: String, status: Int32) {
        let exited = waitStatusExited(status)
        let exitStatus = waitStatusExitCode(status)
        let signaled = waitStatusSignaled(status)
        let termSig = waitStatusTermSignal(status)
        emitDebug(
            "[PTYProcess] \(context) WIFEXITED=\(exited) WEXITSTATUS=\(exitStatus) " +
            "WIFSIGNALED=\(signaled) WTERMSIG=\(termSig)\n"
        )
    }

    private func emitDebug(_ message: String) {
        if let data = message.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private func childExitWithErrno(_ function: String) -> Never {
        let code = errno
        let text: String
        if let cString = strerror(code) {
            text = String(cString: cString)
        } else {
            text = "unknown error"
        }
        let message = "[PTYProcess child] \(function) failed: \(text) (errno=\(code))\n"
        message.withCString { ptr in
            _ = Darwin.write(STDERR_FILENO, ptr, strlen(ptr))
        }
        _exit(127)
    }

    private func emitChildDebug(_ message: String) {
        message.withCString { ptr in
            _ = Darwin.write(STDERR_FILENO, ptr, strlen(ptr))
        }
    }
}
