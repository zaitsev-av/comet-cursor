# Go Prototype (Archived)

This directory contains the original Go + CGo + OpenGL (GLFW) prototype of Comet Cursor.

**It is archived and no longer maintained.** The active application lives in [`CometCursorApp/`](../CometCursorApp/).

## Why it exists

The prototype was used to validate the core idea: a Metal-free, cross-platform cursor trail rendered via OpenGL. It was later replaced by a native Swift + Metal implementation with proper macOS integration (menu bar, multi-monitor, system settings, etc.).

## Running

```bash
cd prototype-go
go build -o comet-cursor main.go && ./comet-cursor

# Or via the control script:
./run.sh start
./run.sh stop
```

**Flags:** `-trail-length`, `-line-width`, `-debug`

**Requirements:** Go 1.24+, CGo, macOS with Accessibility permission.
