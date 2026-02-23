import Combine
import Foundation

@MainActor
public final class TerminalSession: ObservableObject, Identifiable {
    public let id: UUID
    @Published public private(set) var title: String
    @Published public private(set) var isTerminated: Bool
    @Published public private(set) var exitCode: Int32?

    public let controller: TerminalSessionController

    public var process: PTYProcess { controller.process }
    public var emulator: TerminalEmulator { controller.emulator }
    public var blockBoundaryManager: BlockBoundaryManager { controller.blockBoundaryManager }
    var copyQueueManager: CopyQueueManager { controller.copyQueueManager }

    public init(
        id: UUID = UUID(),
        title: String,
        controller: TerminalSessionController? = nil
    ) {
        let resolvedController = controller ?? TerminalSessionController()
        self.id = id
        self.title = title
        self.controller = resolvedController
        self.isTerminated = resolvedController.isProcessTerminated
        self.exitCode = resolvedController.processExitCode

        resolvedController.onProcessTermination = { [weak self] code in
            guard let self else { return }
            self.isTerminated = true
            self.exitCode = code
        }
    }

    public func terminate() {
        controller.terminate()
    }
}
