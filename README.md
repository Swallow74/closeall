# CloseAll - macOS Menu Bar App

CloseAll is a lightweight macOS menu bar app that lets you quit all running applications with a single click.

## Project Structure

```
closeall/
├── Sources/
│   ├── main.swift              # Entry point (manual NSApplication.run)
│   ├── AppDelegate.swift       # App delegate, setup StatusBarController
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

| Feature | Status |
|---------|--------|
| Active apps list (system filtered) | ✅ |
| Quit single app | ✅ |
| Force quit (Option+click) | ✅ |
| Quit All | ✅ |
| Force Quit All | ✅ |
| Ignore list (Finder always ignored) | ✅ |
| Persist ignore in UserDefaults | ✅ |
| Auto refresh (notification center) | ✅ |
| LSUIElement = YES (no Dock icon) | ✅ |
| NSStatusItem + NSPopover | ✅ |
| Dynamic NSWorkspace icons | ✅ |

## Info.plist - Important Keys

```xml
<key>LSUIElement</key>
<true/>
```
This key hides the app from the Dock and "Running Applications" list.

## Interactions

- **Click**: opens menu
- **Hover** on app: shows quit/ignore buttons
- **Click** xmark button: normal quit
- **⌥ + Click** xmark button: force quit
- **Quit All**: closes all listed apps
- **Force**: force quits all

## Notes

- Potential fix for AppRowView: if Option+click doesn't work, replace `.keyboardShortcut` with `.onKeyPress` or use `NSEvent` modifier flags check
