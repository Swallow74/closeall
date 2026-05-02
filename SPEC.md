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

**P0 - Must Have**
1. Leggi runningApplications da NSWorkspace
2. Filtra sistema e app stessa
3. Quit singola app via NSRunningApplication.terminate()
4. Quit All con conferma implicita
5. Force Quit via NSRunningApplication.forceTerminate()
6. Ignored Apps (Finder sempre + lista custom)

**P1 - Should Have**
1. Persistenza lista app ignorate in UserDefaults
2. Refresh list on app launch/termination
3. Opzionale: launch at login

**User Interactions**
- Click StatusBar → apri popover
- Click fuori → chiudi popover
- Click quit button → Termina app
- Option+Click quit → Force Terminate
- Click "Quit All" → Termina tutte (no conferma)

### Data Handling
- **Local Storage**: UserDefaults per ignored apps list
- **No API/Network**

### Architecture Pattern
- **MVVM**: ProcessManager (Model+ViewModel) + SwiftUI Views
- ProcessManager: singleton per gestione processi
- @Published properties per reactive UI updates

### Edge Cases
- App che non risponde → forza con forceTerminate()
- Finder ignorato sempre
- App che terminano durante iterazione → skip gracefully
- Popover già aperto → toggle chiusura

## 4. Technical Specification

### Dependencies
- **None** - Solo native frameworks

### Frameworks
- SwiftUI (UI)
- AppKit (NSStatusItem, NSWorkspace)
- Combine (reactive updates)

### Asset Requirements
- App Icon: 1024x1024 (generico xmark.circle.fill style)
- No other assets - tutto SF Symbols

### Info.plist Keys
```xml
LSUIElement: YES (nascondi da Dock)
NSHighResolutionCapable: YES
```

### File Structure
```
QuitAll/
├── Sources/
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── ProcessManager.swift
│   ├── Models/
│   │   └── AppInfo.swift
│   └── Views/
│       ├── StatusBarController.swift
│       ├── PopoverContentView.swift
│       └── AppRowView.swift
├── Resources/
│   └── Info.plist
└── project.yml
```

## 5. Implementation Notes

- Usare `NSWorkspace.shared.runningApplications` per lista
- Filtrare: `activationPolicy != .regular` = sistema
- Escludere `BundleIdentifier` stesso
- `NSRunningApplication.terminate()` gracefully
- `NSRunningApplication.forceTerminate()` per force quit
- Icone: `NSWorkspace.shared.icon(forFile: app.bundleURL)`
- UserDefaults per ignored apps array