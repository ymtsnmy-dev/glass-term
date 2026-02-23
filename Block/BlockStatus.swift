import Foundation

public enum BlockStatus: Sendable, Equatable {
    case running
    case success
    case failure
    case interrupted
}
