# QuitAll - Specifica Tecnica

## 1. Projektübersicht

- **Projektname**: QuitAll
- **Bundle Identifier**: com.quitall.app
- **Typ**: macOS Menu Bar App (StatusBar)
- **Core-Funktionalität**: Menu Bar App zum Beenden aller aktiven Anwendungen mit UI-Interface
- **Zielgruppe**: macOS Power User
- **macOS Version**: macOS 12.0 (Monterey)+

## 2. UI/UX Spezifikation

### Window Structure
- Kein Hauptfenster
- NSStatusItem in Menu Bar
- Popover als Dropdown-Menu (350x400pt max)
- Kein Dock-Eintrag (LSUIElement = YES)

### Visuelles Design

**Farbpalette**
- Primary: System Blue (#007AFF)
- Background: System Material (Vibrancy)
- Text Primary: labelColor (system)
- Text Secondary: secondaryLabelColor (system)
- Separator: #E5E5EA (15% opacity)
- Destructive: System Red (#FF3B30)
- Force Quit: System Orange (#FF9500)

**Typografie**
- App Name: SF Pro Text, 13pt, semibold
- Section Header: SF Pro Text, 11pt, medium, uppercase, secondaryLabelColor
- Button Text: SF Pro Text, 13pt, regular

**Spacing System (8pt grid)**
- Popover Padding: 16pt
- Item Spacing: 8pt
- Icon Size: 24x24pt
- Row Height: 36pt

### Views & Components

**StatusBarButton**
- Icon: system "xmark.circle.fill"
- tooltip: "QuitAll"

**PopoverContentView**
- Header: "QuitAll" title + settings gear icon
- ScrollView con lista applicazioni
- Footer: "Quit All" button (destructive red)

**AppRowView**
- App icon (24x24 via NSWorkspace)
- App name (truncated if > 200pt)
- Quit button (minimal, SF Symbol "xmark.circle")
- Force quit su Option+Click (visual hint: "hold ⌥")

**States**
- Default: normale opacità
- Hover: sfondo highlight
- Quitting: spinner + "Quitting..."

## 3. Funktionalità Spezifikation

### Core Features

**P0 - Must Have (all implemented)**
1. ✅ Leggi runningApplications da NSWorkspace
2. ✅ Filtra sistema e app stessa
3. ✅ Quit singola app via NSRunningApplication.terminate()
4. ✅ Quit All con opzione conferma (toggle in Settings)
5. ✅ Force Quit su Option+Click / button dedicato
6. ✅ Ignored Apps (Finder sempre + lista custom, persistita)
7. ✅ Minimize All Apps via AppleScript (`tell app "X" to hide`)
8. ✅ Keyboard Shortcuts globali: `^⌥⌘Q` (Quit All), `^⌥⌘M` (Minimize All)
9. ✅ Right-click context menu: Minimize All / Quit All / Settings

**P1 - Should Have (all implemented)**
1. ✅ Persistenza lista app ignorate in UserDefaults
2. ✅ Refresh list on app launch/termination (NSWorkspace notifications)
3. ✅ Launch at login toggle
4. ✅ Settings panel: Keyboard shortcuts on/off, Require confirmation, Hide menu bar icon

**User Interactions**
- Click StatusBar → apri/chiudi popover (toggle)
- Right-click StatusBar → context menu: Minimize All / Quit All / Settings
- Click fuori popover → chiudi popover
- Click quit button per app → Termina app (gentle)
- Click force quit button → Force Terminate
- `^⌥⌘Q` global shortcut → Quit All (conferma se abilitata)
- `^⌥⌘M` global shortcut → Minimize All
- "Quit All" button in popover → Quit tutte (conferma se abilitata)

### Data Handling
- **Local Storage**: UserDefaults per ignored apps, settings
- **No API/Network**

### Architecture Pattern
- **MVVM**: ProcessManager (Model+ViewModel) + AppSettings + SwiftUI Views
- ProcessManager: singleton per gestione processi (@Published, Combine)
- AppSettings: singleton UserDefaults-backed settings (@Published, Combine)
- KeyboardShortcutManager: singleton per global hotkeys (`NSEvent.addGlobalMonitorForEvents`)

### Edge Cases
- App che non risponde → forza con forceTerminate()
- Finder ignorato sempre (hardcoded in ProcessManager)
- App che terminano durante iterazione → skip gracefully
- Popover già aperto → toggle chiusura
- Icon hidden → shortcuts still work; no visual access except via keyboard

## 4. Technical Specification

### Dependencies
- **None** - Solo native frameworks (SwiftUI, AppKit, Combine, Carbon)

### Frameworks
- SwiftUI (UI)
- AppKit (NSStatusItem, NSWorkspace, NSAppleScript)
- Combine (reactive updates via @Published)
- Carbon (keyCode constants for keyboard shortcuts)

### Asset Requirements
- App Icon: 1024x1024 (power.circle.fill style, red/white palette)
- No other assets - tutto SF Symbols

### Info.plist Keys
```xml
LSUIElement: YES (nascondi da Dock)
NSHighResolutionCapable: YES
```

### File Structure
```
CloseAll/
├── Sources/
│   ├── main.swift                    # Entry point → AppDelegate
│   ├── AppDelegate.swift             # Shortcut registration, settings observer
│   ├── AppSettings.swift             # UserDefaults-backed singleton (ObservableObject)
│   ├── ProcessManager.swift          # Running apps, quit/minimize logic, ignored apps
│   ├── KeyboardShortcutManager.swift # Global hotkeys via NSEvent.addGlobalMonitorForEvents
│   ├── AppConstants.swift            # String keys, dimensions, UserDefaults keys, key combos
│   ├── Models/
│   │   └── AppInfo.swift             # Running app model (Identifiable, Hashable)
│   └── Views/
│       ├── StatusBarController.swift # Menu bar button, popover, right-click context menu
│       ├── PopoverContentView.swift  # Main UI: app list, settings toggles, footer buttons
│       └── AppRowView.swift          # Per-app row: icon, name, select/quit/ignore buttons
├── Resources/
│   ├── Info.plist                    # LSUIElement=YES, NSHighResolutionCapable=YES
│   └── AppIcon.icns                  # 1024x1024 app icon
├── project.yml                       # XcodeGen spec (arm64, macOS 12.0+, Swift 5.9)
└── CloseAll.xcodeproj/               # Generated by xcodegen (do not edit manually)
```

## 5. Implementation Notes

### Build & Run
1. `xcodegen generate --spec project.yml` — rigenera progetto Xcode (sempre prima di buildare)
2. `xcodebuild -project CloseAll.xcodeproj -scheme CloseAll -destination 'platform=macOS,arch=arm64' build`
3. LSP errors sono false positive — single target, no modules. Fidati solo di `xcodebuild`

### Core APIs
- `NSWorkspace.shared.runningApplications` per lista app attive
- Filtrare: `activationPolicy == .regular` (esclude system apps)
- Escludere bundle identifier dell'app stessa (`com.closeall.app`)
- `NSRunningApplication.terminate()` per gentle quit (rispetta unsaved changes)
- `NSRunningApplication.forceTerminate()` per force quit
- AppleScript (`tell app "X" to hide`) per minimize — `NSRunningApplication.hide()` non affidabile
- Icone: `NSWorkspace.shared.icon(forFile: app.bundleURL?.path)`

### Keyboard Shortcuts
- Implementati via `NSEvent.addGlobalMonitorForEvents(matching:.keyDown)` — works globally
- KeyCode 'q' = 0x0A, KeyCode 'm' = 0x3E
- Modifier flags: `.control + .option + .command`
- Disabilitabili da Settings (toggle `CloseAllKeyboardShortcutsEnabled`)

### UserDefaults Keys
- `CloseAllIgnoredApps` — [String] bundle identifiers ignorati (Finder sempre incluso)
- `CloseAllLaunchAtLogin` — Bool, apre System Preferences se abilitato
- `CloseAllKeyboardShortcutsEnabled` — Bool, default true
- `CloseAllRequireQuitConfirmation` — Bool, default false (1-click quit)
- `CloseAllHideMenuBarIcon` — Bool, default false

### Notification System
- `Notification.Name.settingsChanged` — emesso da AppSettings quando un setting cambia
- Ascoltato da AppDelegate (re-register shortcuts) e StatusBarController (aggiorna visibilità icona)

### Quirks
- `NSStatusBarItem.button` è read-only — non si può sostituire con custom subclass
- Right-click su status bar button: usare `button.menu = contextMenu` (built-in macOS behavior)
- Minimize usa AppleScript perché `NSRunningApplication.hide()` è inaffidabile su macOS moderno
- Popover height 450pt (include settings section)
