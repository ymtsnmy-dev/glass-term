import Foundation

public struct Block: Sendable, Equatable {
    public var id: UUID
    public var command: String
    public var stdout: String
    public var stderr: String
    public var startedAt: Date
    public var finishedAt: Date?
    public var exitCode: Int?
    public var status: BlockStatus

    public init(
        id: UUID = UUID(),
        command: String,
        stdout: String = "",
        stderr: String = "",
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        exitCode: Int? = nil,
        status: BlockStatus = .running
    ) {
        self.id = id
        self.command = command
        self.stdout = stdout
        self.stderr = stderr
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.status = status
    }
}
