import Foundation

public typealias ScreenLine = [ScreenCell]

public final class ScrollbackBuffer: @unchecked Sendable {
    public let capacity: Int

    private let lock = NSLock()
    private var storage: [ScreenLine?]
    private var startIndex: Int = 0
    private var countStorage: Int = 0

    public init(capacity: Int = 10_000) {
        precondition(capacity > 0, "Scrollback capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return countStorage
    }

    public func append(_ line: ScreenLine) {
        lock.lock()
        defer { lock.unlock() }

        if countStorage < capacity {
            let writeIndex = (startIndex + countStorage) % capacity
            storage[writeIndex] = line
            countStorage += 1
            return
        }

        storage[startIndex] = line
        startIndex = (startIndex + 1) % capacity
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        guard countStorage > 0 else { return }
        for offset in 0..<countStorage {
            let index = (startIndex + offset) % capacity
            storage[index] = nil
        }
        startIndex = 0
        countStorage = 0
    }

    public func snapshot() -> [ScreenLine] {
        lock.lock()
        defer { lock.unlock() }

        guard countStorage > 0 else { return [] }

        var lines: [ScreenLine] = []
        lines.reserveCapacity(countStorage)
        for offset in 0..<countStorage {
            let index = (startIndex + offset) % capacity
            if let line = storage[index] {
                lines.append(line)
            }
        }
        return lines
    }
}
