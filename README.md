# CloseAll - macOS Menu Bar App

CloseAll is a lightweight macOS menu bar app that lets you quit all running applications with a single click.

## Project Structure

```
closeall/
├── Sources/
│   ├── main.swift              # Entry point (manual NSApplication.run)
│   ├── AppDelegate.swift       # App delegate, setup StatusBarController
│   ├── MemoryPressureManager.swift # System memory monitoring (host_statistics64)
│   ├── ProcessManager.swift    # Logic: app list, quit, force quit, ignore
│   ├── Models/
│   │   └── AppInfo.swift       # Model for listed apps
│   └── Views/
│       ├── StatusBarController.swift   # NSStatusItem + NSPopover
│       ├── PopoverContentView.swift    # Main menu view
│       └── AppRowView.swift            # Single app row
├── Resources/
│   └── Info.plist              # LSUIElement=YES (hides from Dock)
├── project.yml                 # XcodeGen config
└── SPEC.md                     # Technical specification
```

## Build & Run

```bash
cd /path/to/closeall
xcodegen generate
open CloseAll.xcodeproj
# In Xcode: Product > Build (⌘B), then Run (⌘R)
```

Or via command line:

```bash
xcodebuild -project CloseAll.xcodeproj -scheme CloseAll -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/CloseAll-*/Build/Products/Debug/CloseAll.app
```

## Features

| Feature | Description |
|---------|-------------|
| **Quit All** | Closes all running apps at once |
| **Minimize All** | Hides all apps with one click, without closing them |
| **Keyboard Shortcuts** | `⌃⌥⌘Q` to quit all, `⌃⌥⌘M` to minimize all — works even if the menu icon is hidden |
| **Quit Selected** | Check the apps you want, then quit only those |
| **Force Quit** | Force close stubborn apps that won't quit normally |
| **Ignore Apps** | Keep apps you don't want to close out of the list (Finder is always ignored) |
| **Search** | Quickly find any running app by name |
| **Hide Menu Icon** | Keep CloseAll running in the background with no visible icon |
| **Launch at Login** | Open CloseAll automatically when you start your Mac |
| **Menu Bar Icon** | Lightweight red X icon that sits in your menu bar |
| **No Dock Icon** | Stays out of your way — runs silently in the menu bar |
| **Memory Pressure Monitoring** | Monitors system memory via `host_statistics64`; shows a warning banner + changes the menu bar icon + sends a notification when free memory drops below 20% |
| **Zero Dependencies** | Pure Swift, no external libraries or frameworks |

## Interactions

- **Left-click icon**: opens the app menu
- **Right-click icon**: quick actions (Minimize All, Quit All, Settings)
- **Click the checkbox** next to an app: select it for batch actions
- **Hover on an app row**: shows close and ignore buttons
- **× button**: close the app gently
- **⚡ button**: force close the app (for unresponsive apps)
- **⌃⌥⌘Q**: quit all apps instantly
- **⌃⌥⌘M**: minimize all apps instantly

## Settings (gear icon)

- **Keyboard shortcuts**: enable or disable global keyboard shortcuts
- **Require confirmation**: show a confirmation dialog before quitting all apps
- **Hide menu icon**: hide the CloseAll icon from the menu bar (shortcuts still work)
- **Launch at login**: open CloseAll automatically when your Mac starts
- **Memory pressure monitoring**: enable or disable system memory monitoring (on by default); warns when free memory falls below 20%
