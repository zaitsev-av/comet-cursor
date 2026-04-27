# Contributing to Comet Cursor

## Architecture

Built with **SwiftUI + Metal + AppKit**, targeting macOS 13+.

```
CometCursorApp/Sources/CometCursorApp/
├── main.swift          — NSApplication entry point
├── AppDelegate.swift   — Menu bar header with inline toggle, settings window, overlay lifecycle
├── CursorTracker.swift — CGEventTap with polling fallback
├── TrailManager.swift  — Trail point history, timestamp-based fade
├── CometRenderer.swift — Metal rendering, ribbon geometry, presets
├── SettingsModel.swift — ObservableObject wrapping UserDefaults
├── SettingsView.swift  — SwiftUI settings panel (ScrollView + VStack layout)
├── GlassSection.swift  — Frosted-glass card container for settings groups
└── GlassSlider.swift   — Custom slider with gradient track and glass knob
```

| File | What it does |
|---|---|
| `AppDelegate.swift` | Menu bar header (icon + title + inline toggle), settings window (460×620, `fullSizeContentView`), overlay lifecycle |
| `CursorTracker.swift` | CGEventTap with polling fallback |
| `TrailManager.swift` | Trail point history, timestamp-based fade |
| `CometRenderer.swift` | Metal rendering, ribbon geometry, presets |
| `SettingsModel.swift` | ObservableObject wrapping UserDefaults |
| `SettingsView.swift` | SwiftUI settings panel, `GlassSection` cards, `GlassSlider` controls |
| `GlassSection.swift` | Card with `.regularMaterial` background, rounded corners, subtle border |
| `GlassSlider.swift` | Drag-gesture slider with gradient fill and `DragGesture`-based interaction |

## Data flow

```
CGEventTap -> DispatchQueue.main -> TrailManager.update()
                                          |
MTKView render thread -> TrailManager.tick() + snapshot() -> CometRenderer.draw()
```

## Rendering

The trail is a Metal triangle strip ribbon. Each trail point generates a left/right vertex pair; adjacent segments share vertices so there are no gaps at joints. Soft-edge falloff is done in the fragment shader. Shaders compile at runtime via `device.makeLibrary(source:)` — no `xcrun metal` needed at build time.

## Multi-monitor

One `NSWindow + MTKView` per `NSScreen`, positioned via `setFrame(screen.frame)`.

## Coordinate conversion

CGEvent uses top-left origin (Y down), AppKit uses bottom-left (Y up). Conversion happens before passing points to the renderer:

```swift
appKitY = NSScreen.main.frame.height - cgEventY
ndcX = (appKitX - screen.frame.minX) / screen.frame.width  * 2 - 1
ndcY = (appKitY - screen.frame.minY) / screen.frame.height * 2 - 1
```

## Fade logic

`TrailManager.tick()` checks `systemUptime - lastMoveTime > 0.4s` before decrementing `fadeAlpha`. Timestamp-based approach avoids race conditions between the render thread and main thread that a boolean flag would introduce.

## Build

```bash
cd CometCursorApp
./scripts/build.sh
open "Comet Cursor.app"
```

Requires Xcode Command Line Tools: `xcode-select --install`
