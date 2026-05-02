# CloseAll - Agent Instructions

## Build & Run
- **Generate project**: `xcodegen generate --spec project.yml` (always run before building)
- **Build**: `xcodebuild -project CloseAll.xcodeproj -scheme CloseAll -destination 'platform=macOS,arch=arm64' build`
- **Xcode only**: no CLI test/lint/run commands exist — use Xcode or `open` the built `.app`
- **Deployment target**: macOS 12.0+, arm64 only, Swift 5.9

## Architecture
- **Menu bar app** (`LSUIElement = YES`), no Dock icon, no main window
- **Entry point**: `Sources/main.swift` → `AppDelegate` → `StatusBarController` → popover with SwiftUI
- **MVVM**: `ProcessManager` (singleton, @Published) drives all UI via Combine
- **Key files**:
  - `AppDelegate.swift` — keyboard shortcut registration, settings change observer
  - `ProcessManager.swift` — running apps list, quit/minimize logic, ignored apps persistence
  - `StatusBarController.swift` — status bar button, popover lifecycle, right-click context menu
  - `PopoverContentView.swift` — main UI: app list, settings toggles, footer actions
  - `AppSettings.swift` — UserDefaults-backed settings (keyboard shortcuts, confirmation, hide icon)
  - `KeyboardShortcutManager.swift` — global hotkeys via `NSEvent.addGlobalMonitorForEvents`
  - `AppConstants.swift` — all string keys, dimensions, UserDefaults keys, key combos

## Settings (UserDefaults)
- `CloseAllKeyboardShortcutsEnabled` — toggle global shortcuts on/off
- `CloseAllRequireQuitConfirmation` — require dialog before "Quit All"
- `CloseAllHideMenuBarIcon` — hide status bar icon (shortcuts still work)
- `CloseAllIgnoredApps` — persisted array of bundle identifiers (Finder always included)

## Keyboard Shortcuts
- `^⌥⌘Q` — Quit All Apps (global, registered via NSEvent global monitor)
- `^⌥⌘M` — Minimize All Apps (global)
- Handled by `KeyboardShortcutManager` in `AppDelegate`; disabled when settings toggle is off

## Right-Click Context Menu
- Status bar button right-click shows: Minimize All / Quit All / Settings (opens popover)

## Quirks
- `NSStatusBarItem.button` is read-only — cannot replace with custom button subclass; use gesture recognizers or `button.menu` property
- Minimize uses AppleScript (`tell app "X" to hide`) because `NSRunningApplication.hide()` API is unreliable in modern SDKs
- All LSP "cannot find X" errors are false positives — single target, no modules. Trust `xcodebuild` output only
- Popover height is 450pt (includes settings section)
