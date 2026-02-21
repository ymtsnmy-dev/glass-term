# glass-term - Implementation Roadmap (v2.0)

This document defines the mandatory execution order for the project.

This order MUST be followed strictly.
Do not skip phases.
Do not merge phases.
Do not implement future layers early.

Before starting any task:

- State the current phase.
- Confirm previous phase completion.
- Confirm validation passed.

---

## Architecture Overview

Layer order (fixed):

1. Project Foundation
2. PTY Layer
3. libvterm Integration
4. PTY <-> Emulator Wiring
5. Rendering Layer
6. Terminal Validation
7. Scrollback
8. Block Abstraction
9. Block UI
10. Copy Stack
11. Sessions & Tabs
12. Theme System
13. Stabilization & Stress Testing

---

## Phase 1 - Project Foundation

### Objective

Create a clean macOS SwiftUI project with enforced structure.

### Tasks

- Create macOS SwiftUI App.
- Deployment target: macOS 13+.
- Disable sandbox temporarily.
- Create directory structure:

```text
glass-term/
├─ Agent.md
├─ SPEC.md
├─ ROADMAP.md
├─ App/
├─ Terminal/
│  ├─ PTY/
│  ├─ Emulator/
│  └─ Screen/
├─ Block/
├─ UI/
├─ Theme/
├─ Vendor/
└─ Resources/
```

### Validation

- Project builds.
- App launches (empty window acceptable).

DO NOT continue until build is clean.

---

## Phase 2 - PTY Layer

### Objective

Launch `/bin/zsh` and communicate via PTY.

### Required Features

- `posix_openpt`
- `grantpt`
- `unlockpt`
- `fork`
- `execve("/bin/zsh")`
- Non-blocking read
- Write support
- `SIGWINCH` handling
- `SIGINT` forwarding
- Process termination detection

### Output

`PTYProcess` class located in `Terminal/PTY/`.

### Validation

Manual tests:

- Launch shell.
- Send `ls`.
- Receive output.
- Send `Ctrl+C`.
- Resize window.
- Exit shell.

If any fail, fix before proceeding.

---

## Phase 3 - libvterm Integration

### Objective

Integrate libvterm without UI.

### Tasks

- Add libvterm to `Vendor/`.
- Configure C static library.
- Configure bridging header.
- Implement `TerminalEmulator` in `Terminal/Emulator/`.

Responsibilities:

- Initialize `vterm(rows, cols)`.
- Feed input bytes.
- Expose screen buffer abstraction.
- Handle alternate screen.
- Resize support.

### Validation

Feed static test sequences:

- Plain text
- ANSI color
- Cursor movement
- Clear screen
- Alternate screen entry/exit

No UI yet.

---

## Phase 4 - PTY <-> Emulator Wiring

### Objective

Real shell output flows into libvterm.

### Tasks

- Connect PTY read loop to `TerminalEmulator`.
- Ensure non-blocking dispatch.
- Update screen buffer on data.

### Validation

- zsh prompt visible
- `ls` renders correctly
- `clear` works
- Colors render

---

## Phase 5 - Rendering Layer

### Objective

Render `ScreenBuffer` in SwiftUI.

### Tasks

- Implement `TerminalView`.
- Monospaced grid layout.
- Fixed rows/columns.
- Accurate cursor placement.

### Resize Handling

On window resize:

- Update PTY window size.
- Resize libvterm.
- Re-render.

### Validation

- Resize window repeatedly.
- Long output display.
- No alignment issues.

---

## Phase 6 - Terminal Validation (Critical Gate)

This phase must pass before any UX features.

### Required Tests

- `vim`
- `top`
- `htop`
- `less`
- `ssh localhost`
- `tmux`

Alternate screen must work.
Cursor must behave correctly.
No rendering corruption allowed.

If `vim` fails, STOP and fix.

---

## Phase 7 - Scrollback

### Objective

Add persistent scrollback buffer.

### Tasks

- Implement ring buffer (min 10,000 lines).
- Integrate with rendering.
- Preserve alternate screen behavior.

### Validation

- `yes` command stress test
- Large logs
- Scroll stability
- No memory spikes

---

## Phase 8 - Block Abstraction Layer

### Objective

Introduce command block detection.

### Tasks

- Apply PS1 marker strategy: `<<<BLOCK_PROMPT>>>`
- Implement `BlockBoundaryManager`
- Track command start/end
- Track exit code
- Ensure rawMode during alternate screen

### Validation

- Simple commands create blocks
- `vim` does NOT create blocks
- No terminal regression

---

## Phase 9 - Block UI

### Objective

Display blocks as cards.

### Tasks

- Implement `BlockListView`
- Status indicators
- Timestamp
- Copy button
- Running/Finished state

### Validation

- Multiple commands create distinct blocks
- Status accurate
- UI stable under rapid execution

---

## Phase 10 - Copy Stack

### Objective

Ordered multi-copy system.

### Tasks

- Implement `CopyQueueManager`
- Copy All
- Clear
- Drawer UI

### Validation

- Copy A -> B -> C
- Copy All returns A B C order

---

## Phase 11 - Sessions & Tabs

### Objective

Multiple independent terminal sessions.

### Tasks

- `SessionManager`
- Multiple PTY instances
- Independent emulator per tab
- Tab UI

### Validation

- 3+ tabs
- No state leakage
- Switching stable

---

## Phase 12 - Theme System

### Objective

Implement theming.

### Tasks

- Theme model
- Default theme
- Glass theme

Glass theme requirements:

- `NSVisualEffectView`
- Semi-transparent block cards
- Corner radius >= 16

### Validation

- Toggle theme at runtime
- No rendering breakage

---

## Phase 13 - Stabilization & Stress Testing

### Stress Scenarios

- `yes > /dev/null`
- 10MB output
- Rapid resize
- Rapid tab switching
- `vim -> exit -> block -> vim`

### Must Not

- Crash
- Freeze
- Leak memory

---

## Definition of Done

The project is complete only if:

- `vim` works correctly
- `top` works correctly
- `ssh` works correctly
- `tmux` works correctly
- 10,000+ scrollback lines stable
- Blocks detected correctly
- Copy Stack order preserved
- Glass theme functional
- 3+ tabs stable
- No crash under stress

---

## Critical Rules

- Never implement multiple phases at once.
- Never move forward without validation.
- Terminal correctness is higher priority than UX features.
- `vim` is the baseline correctness test.
