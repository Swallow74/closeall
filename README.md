# CloseAll - macOS Menu Bar App

CloseAll is a lightweight macOS menu bar app that lets you quit all running applications with a single click, with real-time memory pressure monitoring.

## Project Structure

```
closeall/
├── Sources/
│   ├── main.swift              # Entry point (manual NSApplication.run)
│   ├── AppDelegate.swift       # App delegate, setup StatusBarController
│   ├── AppSettings.swift       # UserDefaults-backed settings
│   ├── AppConstants.swift      # All constants: strings, keys, dimensions
│   ├── MemoryPressureManager.swift # System memory monitoring (host_statistics64)
│   ├── ProcessManager.swift    # Logic: app list, quit, force quit, ignore
│   ├── KeyboardShortcutManager.swift # Global hotkeys via NSEvent
│   ├── Models/
│   │   └── AppInfo.swift       # Model for listed apps
│   └── Views/
│       ├── StatusBarController.swift   # NSStatusItem + NSPopover
│       ├── PopoverContentView.swift    # Main SwiftUI view
│       └── AppRowView.swift            # Single app row
├── Resources/
│   └── Info.plist              # LSUIElement=YES (hides from Dock)
├── project.yml                 # XcodeGen config
└── SPEC.md                     # Technical specification
```

## Build & Run

```bash
xcodegen generate --spec project.yml
xcodebuild -project CloseAll.xcodeproj -scheme CloseAll -destination 'platform=macOS,arch=arm64' build
```

The built app will be automatically copied to `/Applications/CloseAll.app`.

## Features

| Feature | Description |
|---------|-------------|
| **Quit All** | Closes all running apps at once |
| **Minimize All** | Hides all apps without closing them |
| **Keyboard Shortcuts** | `⌃⌥⌘Q` quit all, `⌃⌥⌘M` minimize all — work even with icon hidden |
| **Quit Selected** | Check apps, quit only those |
| **Force Quit** | Force close stubborn apps |
| **Ignore Apps** | Keep apps out of the list (Finder always ignored) |
| **Search** | Find running apps by name |
| **Hide Menu Icon** | Background-only mode, shortcuts still work |
| **Launch at Login** | Auto-start with your Mac |
| **Memory Pressure Indicator** | Persistent real-time display of free memory % in the popover header, colored dot + percentage |
| **Memory Warning Banner** | Red banner with full details when memory is critically low |
| **Critical Memory Alert** | Menu bar icon turns red and **blinks** when free memory drops below 10% |
| **Memory Threshold Notification** | macOS notification when memory first crosses the warning threshold |
| **No Dock Icon** | Runs silently in the menu bar |
| **Zero Dependencies** | Pure Swift, no external libraries |

## Interactions

- **Left-click icon**: opens the app popover
- **Right-click icon**: quick actions (Minimize All, Quit All, Settings)
- **Click checkbox** next to an app: select for batch actions
- **Hover on an app row**: shows quit and ignore buttons
- **× button**: close the app gently
- **⚡ button**: force close unresponsive apps
- **⌃⌥⌘Q**: quit all apps instantly
- **⌃⌥⌘M**: minimize all apps instantly

## Settings

- **Keyboard shortcuts**: enable/disable global shortcuts
- **Require confirmation**: confirmation dialog before Quit All
- **Hide menu icon**: hide from menu bar (shortcuts still work)
- **Memory pressure monitoring**: enable/disable memory monitoring (on by default)
- **Launch at login**: auto-start with your Mac

## Memory Pressure Levels

| Level | Free Memory | Indicator |
|-------|-------------|-----------|
| Normal | > 20% | Green dot in header, standard menu bar icon (power.circle.fill) |
| Warning | 10–20% | Orange dot in header, yellow triangle (exclamationmark.triangle.fill) in menu bar |
| Critical | < 10% | Red dot in header, red octagon (exclamationmark.octagon.fill) **blinking** in menu bar |
