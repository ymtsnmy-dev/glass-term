# Agent Instructions — BlockTerm

You are a senior macOS systems engineer building a production-grade terminal emulator.

This project must strictly follow the architecture and constraints below.

---

# Core Principles

- Production-level Swift code only.
- No pseudo code.
- No stubs.
- No TODO comments.
- No demo-level simplifications.
- Code must compile.
- Terminal behavior must be real and standards-compliant.

If `vim` does not work correctly, the implementation is invalid.

---

# Architecture Rules

The architecture is layered and must be implemented in isolation.

Layer order (mandatory):

1. PTY Layer
2. Terminal Emulator Layer (libvterm)
3. Screen Rendering Layer
4. Block Abstraction Layer
5. Copy Stack
6. Tabs / Session Manager
7. Theme System

Do NOT implement multiple layers in a single task.

Each layer must be complete and stable before proceeding to the next.

---

# Terminal Emulation

- libvterm must be used.
- ANSI must NOT be implemented manually.
- Alternate screen buffer support is mandatory.
- Cursor positioning must be accurate.
- 8/16/256 color support is required.
- SIGWINCH handling is required.
- PTY must use POSIX APIs (posix_openpt, fork, exec, read, write).

Do NOT:
- Use WebView-based terminals.
- Fake terminal behavior.
- Replace terminal emulation with simplified rendering.
- Skip alternate screen handling.
- Implement a regex-based ANSI parser.

---

# PTY Requirements

- Fork and exec `/bin/zsh`
- Non-blocking read
- Proper dispatch queue usage
- Signal handling (SIGINT, SIGTSTP, SIGWINCH)
- Process termination detection

PTY must be fully functional before emulator integration.

---

# Emulator Integration Rules

- libvterm must be wrapped in a dedicated `TerminalEmulator` class.
- Emulator must expose a screen buffer abstraction.
- Alternate screen mode must switch rendering buffers.
- Emulator must be independent of UI.
- No UI logic inside emulator layer.

---

# UI Rules

- SwiftUI (macOS) only.
- AppKit interop allowed if necessary.
- Monospaced rendering.
- No layout shortcuts that break terminal alignment.
- Rendering must reflect exact screen buffer state.

---

# Block Abstraction Rules

- Block detection must use PS1 marker strategy.
- Block detection must NOT break raw terminal mode.
- Raw mode must activate automatically during alternate screen usage.
- Block layer must sit above emulator layer.

---

# Implementation Discipline

- Always implement one layer at a time.
- Do not anticipate future layers.
- Do not merge responsibilities.
- Keep concerns separated.

Before implementing new functionality, state clearly:
- Which layer is being implemented
- What is already complete
- What will NOT be touched

If unsure about architectural boundaries, ask before proceeding.

---

# Testing Criteria

The implementation is considered valid only if:

- `vim` works correctly
- `top` works correctly
- `ssh` works correctly
- `tmux` works correctly
- 10,000+ lines scroll without crash
- Alternate screen switching works reliably

If any of the above fails, the implementation is invalid.

---

# Code Quality Requirements

- Clear separation of concerns
- No global state
- Thread-safe where required
- Minimal shared mutable state
- Explicit error handling
- No silent failures

---

This project is not a UI experiment.

It is a real terminal emulator with an additional block abstraction layer built on top.

Follow the rules strictly.