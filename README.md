# CloseAll - macOS Menu Bar App

CloseAll is a lightweight macOS menu bar app that lets you quit all running applications with a single click, with real-time system monitoring (memory, CPU, GPU, disk, thermal).

## Project Structure

```
closeall/
├── Sources/
│   ├── main.swift                  # Entry point (manual NSApplication.run)
│   ├── AppDelegate.swift           # App delegate, setup StatusBarController
│   ├── AppSettings.swift           # UserDefaults-backed settings
│   ├── AppConstants.swift          # All constants: strings, keys, dimensions
│   ├── MemoryPressureManager.swift # System memory monitoring (host_statistics64)
│   ├── ThermalStateManager.swift   # Thermal state monitoring (ProcessInfo)
│   ├── DiskSpaceManager.swift      # Free disk space monitoring
│   ├── CPUManager.swift            # Global + per-app CPU usage monitoring
│   ├── GPUManager.swift            # GPU utilization monitoring (IOKit)
│   ├── GPUIconHelper.swift         # Custom drawn GPU status bar icon
│   ├── ProcessManager.swift        # Logic: app list, quit, force quit, ignore
│   ├── KeyboardShortcutManager.swift # Global hotkeys via NSEvent
│   ├── Models/
│   │   └── AppInfo.swift           # Model for listed apps
│   └── Views/
│       ├── StatusBarController.swift   # NSStatusItem + NSPopover
│       ├── PopoverContentView.swift    # Main SwiftUI view
│       └── AppRowView.swift            # Single app row
├── Resources/
│   └── Info.plist                  # LSUIElement=YES (hides from Dock)
├── project.yml                     # XcodeGen config
└── SPEC.md                         # Technical specification
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
| **Memory Pressure Monitor** | Real-time free RAM %, colored indicator + banner + critical alert |
| **CPU Monitor** | Global CPU % + per-app CPU usage shown in app list |
| **GPU Monitor** | GPU utilization % via IOKit AGXAccelerator, custom status bar icon |
| **Disk Space Monitor** | Free disk space GB/%, warning when below threshold |
| **Thermal State Monitor** | Tracks system thermal state (fair/serious/critical) |
| **Auto-Free Memory** | When memory critically low, auto-quits background apps to free RAM |
| **System Tray Icon** | Changes icon/color based on most critical system condition, tooltip shows all states |
| **No Dock Icon** | Runs silently in the menu bar |
| **Zero Dependencies** | Pure Swift, no external libraries |

## Interactions

- **Left-click icon**: opens the app popover
- **Right-click icon**: quick actions (Minimize All, Quit All, Settings)
- **Click checkbox** next to an app: select for batch actions
- **Hover on an app row**: shows quit and ignore buttons, plus CPU usage if > 5%
- **× button**: close the app gently
- **⚡ button**: force close unresponsive apps
- **⌃⌥⌘Q**: quit all apps instantly
- **⌃⌥⌘M**: minimize all apps instantly

## Settings

- **Keyboard shortcuts**: enable/disable global shortcuts
- **Require confirmation**: confirmation dialog before Quit All
- **Hide menu icon**: hide from menu bar (shortcuts still work)
- **Memory pressure monitoring**: enable/disable memory monitor (on by default)
- **GPU monitoring**: enable/disable GPU monitor (off by default)
- **Thermal state monitoring**: enable/disable thermal monitor (off by default)
- **Disk space monitoring**: enable/disable disk space monitor (off by default)
- **CPU monitoring**: enable/disable CPU monitor (off by default)
- **Auto-free memory**: auto-quit background apps when memory is low (off by default)
- **Launch at login**: auto-start with your Mac

## Monitoring Levels

### Memory Pressure
| Level | Free Memory | Indicator |
|-------|-------------|-----------|
| Normal | > 20% | Green dot in header, standard menu bar icon |
| Warning | 10–20% | Orange dot, yellow triangle in menu bar |
| Critical | < 10% | Red dot, red octagon in menu bar |

### GPU Usage
| Level | Usage | Indicator |
|-------|-------|-----------|
| Normal | < 70% | White label, default icon |
| Warning | 70–90% | Orange label, orange icon in menu bar |
| Critical | > 90% | Red label, red icon in menu bar |

### CPU Usage
| Level | Usage | Indicator |
|-------|-------|-----------|
| Normal | < 80% | Green label |
| Warning | 80–95% | Orange label, orange CPU icon in menu bar |
| Critical | > 95% | Red label, red CPU icon in menu bar |

### Disk Space
| Level | Free Space | Indicator |
|-------|------------|-----------|
| Normal | > 10 GB | Green indicator |
| Warning | 5–10 GB | Orange indicator, disk icon in menu bar |
| Critical | < 5 GB | Red indicator |

### Thermal State
| Level | State | Indicator |
|-------|-------|-----------|
| Normal | Nominal/Fair | Green indicator |
| Warning | Serious | Orange indicator, thermometer icon in menu bar |
| Critical | Critical | Red indicator |

### Tooltip
The status bar icon tooltip shows a multi-line summary of all active monitors:

```
Memory: 45% free
Disk: 73% free
Thermal: Normal
CPU: 23%
```

Warning states are prefixed with ⚠ and shown in priority order.
