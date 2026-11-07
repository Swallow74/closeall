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
  - `KeyboardShortcutManager.swift` — global hotkeys via Carbon `RegisterEventHotKey` (no Accessibility permission)
  - `ProcessScanner.swift` — libproc scan of all processes (resident memory, CPU time, parent); no `task_for_pid`
  - `LoginItemsManager.swift` — launch at login via `SMAppService` (macOS 13+), fallback opens Login Items pane
  - `Views/SettingsView.swift`, `Views/Components.swift` — settings page, shared chips/badges/tooltips
  - `AppConstants.swift` — all string keys, dimensions, UserDefaults keys, key combos

## Settings (UserDefaults)
- `CloseAllKeyboardShortcutsEnabled` — toggle global shortcuts on/off
- `CloseAllRequireQuitConfirmation` — require dialog before "Quit All"
- `CloseAllHideMenuBarIcon` — hide status bar icon (shortcuts still work)
- `CloseAllIgnoredApps` — persisted array of bundle identifiers (Finder always included)

## Keyboard Shortcuts
- `^⌥⌘Q` — Quit All Apps (global, registered via NSEvent global monitor)
- `^⌥⌘M` — Minimize All Apps (global)
- Handled by `KeyboardShortcutManager` in `AppDelegate` (key codes: Q = 0x0C, M = 0x2E); disabled when settings toggle is off
- Re-launching the app (Spotlight/Finder) opens the popover: way back in when the icon is hidden

## Right-Click Context Menu
- Status bar button right-click shows: Minimize All / Quit All / Settings (opens popover)

## Release
1. Bump `MARKETING_VERSION` in `project.yml`
2. Build: `xcodebuild -project CloseAll.xcodeproj -scheme CloseAll -destination 'platform=macOS,arch=arm64' build`
3. Create DMG:
   ```bash
   APP=~/Library/Developer/Xcode/DerivedData/CloseAll-*/Build/Products/Debug/CloseAll.app
   TMP=$(mktemp -d)/CloseAll
   mkdir -p "$TMP"
   cp -R $APP "$TMP/"
   ln -s /Applications "$TMP/Applications"
   hdiutil create -volname "CloseAll" -srcfolder "$TMP" -ov -format UDZO /tmp/CloseAll.dmg
   ```
4. Tag and push: `git tag v<version> && git push origin v<version>`
5. Create release with DMG:
   ```bash
   export GH_TOKEN=$(cat ~/.config/opencode/.github-token)
   gh release create v<version> --title "v<version>: ..." --notes "..."
   gh release upload v<version> /tmp/CloseAll.dmg --clobber
   ```
6. Always include the DMG in the release assets (not just source zip)

## Screenshot (README)
- File: `screenshot-v3.png` (riferito in README.md come `![CloseAll Screenshot](screenshot-v3.png)`)
- **Attenzione**: gli screenshot di macOS sono in formato HEIF/HEIC anche se l'estensione è `.png`. Vanno convertiti in vero PNG con `sips -s format png <input> --out <output>` prima di committarli.
- Se il CDN di GitHub continua a servire la vecchia versione, rinominare il file (es. `screenshot-v3.png`) e aggiornare il README per forzare il refresh.

## Localization
- Strings: `AppConstants.Localizable` (alias `L`) wraps `loc()` = `NSLocalizedString`; key = English text. Italian in `Resources/it.lproj/Localizable.strings`. New string: add to `Localizable` + the `.strings` file.
- XcodeGen: `Resources/` must be a `sources` entry with `buildPhase: resources` (a `resources:` key is ignored and ships nothing, not even the icon).

## Quirks
- `NSStatusBarItem.button` is read-only — cannot replace with custom button subclass; use gesture recognizers or `button.menu` property
- Minimize uses `NSRunningApplication.hide()` (not AppleScript)
- Quit is non-blocking: `terminate()` on all targets, poll `isTerminated` on main; apps that don't quit within 5s land in `ProcessManager.failedApps` (banner with Force Quit). Never block main with a semaphore: termination notifications arrive on main
- Settings live in `AppSettings` (observes `UserDefaults.didChangeNotification`); views bind to it, not `@AppStorage`, for monitor toggles
- Per-process data scans only while the popover is open (`MemoryPressureManager.setDetailedScan`)
- Verify without touching /Applications: `xcodebuild ... -configuration Release -derivedDataPath <tmp>` (post-build copy runs only for Debug)
- All LSP "cannot find X" errors are false positives — single target, no modules. Trust `xcodebuild` output only
- Popover is 340×540pt
