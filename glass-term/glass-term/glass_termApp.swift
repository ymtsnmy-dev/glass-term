//
//  glass_termApp.swift
//  glass-term
//
//  Created by Yamato Shinomiya on 2026/02/21.
//

import Foundation
import SwiftUI

@main
struct glass_termApp: App {
    init() {
#if DEBUG
        PTYDebugLauncher.shared.startIfNeeded()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if DEBUG
enum PTYDebugControl {
    static func send(_ command: String) {
        PTYDebugLauncher.shared.send(command)
    }

    static func ctrlC() {
        PTYDebugLauncher.shared.ctrlC()
    }

    static func resize(rows: Int, cols: Int) {
        PTYDebugLauncher.shared.resize(rows: rows, cols: cols)
    }

    static func terminate() {
        PTYDebugLauncher.shared.terminate()
    }
}

final class PTYDebugLauncher {
    static let shared = PTYDebugLauncher()

    private var didStart = false
    private var process: PTYProcess?
    private let lock = NSLock()

    private init() {}

    func startIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard !didStart else { return }
        didStart = true

        let pty = PTYProcess()
        pty.onOutput = { data in
            if let text = String(data: data, encoding: .utf8) {
                print("[PTY OUT] \(text)", terminator: "")
            } else {
                print("[PTY OUT] <non-utf8 bytes: \(data.count)>")
            }
        }
        pty.onExit = { [weak pty] code in
            let running = pty?.isRunning ?? false
            print("[PTY EXIT] code=\(String(describing: code)) isRunning=\(running)")
        }

        do {
            try pty.start(rows: 24, cols: 80)
            process = pty
            print("[PTY DEBUG] started")
            scheduleValidationSequence()
        } catch {
            print("[PTY DEBUG] failed to start: \(error)")
        }
    }

    func send(_ command: String) {
        lock.lock()
        let process = self.process
        lock.unlock()

        guard let process else {
            print("[PTY DEBUG] process is not running")
            return
        }

        do {
            try process.write(command)
        } catch {
            print("[PTY DEBUG] send failed: \(error)")
        }
    }

    func ctrlC() {
        lock.lock()
        let process = self.process
        lock.unlock()

        guard let process else {
            print("[PTY DEBUG] process is not running")
            return
        }

        do {
            try process.sendCtrlC()
        } catch {
            print("[PTY DEBUG] Ctrl+C failed: \(error)")
        }
    }

    func resize(rows: Int, cols: Int) {
        lock.lock()
        let process = self.process
        lock.unlock()

        guard let process else {
            print("[PTY DEBUG] process is not running")
            return
        }

        do {
            try process.resize(rows: rows, cols: cols)
        } catch {
            print("[PTY DEBUG] resize failed: \(error)")
        }
    }

    func terminate() {
        lock.lock()
        let process = self.process
        self.process = nil
        lock.unlock()

        process?.terminate()
    }

    private func scheduleValidationSequence() {
        schedule(after: 0.2) { [weak self] in
            self?.send("echo READY\n")
        }
        schedule(after: 0.6) { [weak self] in
            self?.send("ls\n")
        }
        schedule(after: 1.2) { [weak self] in
            self?.send("yes\n")
        }
        schedule(after: 2.0) { [weak self] in
            self?.ctrlC()
        }
        schedule(after: 2.4) { [weak self] in
            self?.resize(rows: 40, cols: 120)
        }
        schedule(after: 3.0) { [weak self] in
            self?.send("exit\n")
        }
    }

    private func schedule(after seconds: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
    }
}
#endif
