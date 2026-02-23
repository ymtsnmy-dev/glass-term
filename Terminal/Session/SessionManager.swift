import Combine
import Foundation

@MainActor
public final class SessionManager: ObservableObject {
    @Published public private(set) var sessions: [TerminalSession]
    @Published public private(set) var activeSessionID: TerminalSession.ID
    @Published public private(set) var activeDisplayMode: DisplayMode = .blockMode

    public var activeSession: TerminalSession? {
        sessions.first(where: { $0.id == activeSessionID })
    }

    private var nextSessionNumber = 1
    private var sessionChangeCancellables: [UUID: AnyCancellable] = [:]
    private var activeSessionDisplayModeCancellable: AnyCancellable?

    public init() {
        let initialSession = TerminalSession(title: "Tab 1")
        sessions = [initialSession]
        activeSessionID = initialSession.id
        nextSessionNumber = 2
        attachSessionObservation(initialSession)
        bindActiveSessionDisplayMode()
    }

    @discardableResult
    public func createSession(makeActive: Bool = true) -> TerminalSession {
        let session = TerminalSession(title: "Tab \(nextSessionNumber)")
        nextSessionNumber += 1
        sessions.append(session)
        attachSessionObservation(session)

        if makeActive {
            activeSessionID = session.id
            bindActiveSessionDisplayMode()
        }

        return session
    }

    public func activateSession(id: TerminalSession.ID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        guard activeSessionID != id else { return }
        activeSessionID = id
        bindActiveSessionDisplayMode()
    }

    public func closeSession(id: TerminalSession.ID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }

        let closingWasActive = (activeSessionID == id)
        let session = sessions.remove(at: index)
        sessionChangeCancellables[id] = nil
        session.terminate()

        if sessions.isEmpty {
            let replacement = TerminalSession(title: "Tab \(nextSessionNumber)")
            nextSessionNumber += 1
            sessions = [replacement]
            attachSessionObservation(replacement)
            activeSessionID = replacement.id
            bindActiveSessionDisplayMode()
            return
        }

        if closingWasActive {
            let nextIndex = min(index, sessions.count - 1)
            activeSessionID = sessions[nextIndex].id
            bindActiveSessionDisplayMode()
        } else {
            bindActiveSessionDisplayMode()
        }
    }

    public func closeActiveSession() {
        closeSession(id: activeSessionID)
    }

    private func attachSessionObservation(_ session: TerminalSession) {
        sessionChangeCancellables[session.id] = session.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    private func bindActiveSessionDisplayMode() {
        activeSessionDisplayModeCancellable = nil

        guard let activeSession else {
            activeDisplayMode = .blockMode
            return
        }

        activeDisplayMode = activeSession.controller.displayMode
        activeSessionDisplayModeCancellable = activeSession.controller.$displayMode
            .sink { [weak self] mode in
                self?.activeDisplayMode = mode
            }
    }
}
