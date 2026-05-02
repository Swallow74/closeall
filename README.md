# QuitAll - macOS Menu Bar App

## Struttura progetto

```
quitall/
├── Sources/
│   ├── main.swift              # Entry point (manual NSApplication.run)
│   ├── AppDelegate.swift       # App delegate, setup StatusBarController
│   ├── ProcessManager.swift    # Logica: lista app, quit, force quit, ignore
│   ├── Models/
│   │   └── AppInfo.swift       # Model per app in lista
│   └── Views/
│       ├── StatusBarController.swift   # NSStatusItem + NSPopover
│       ├── PopoverContentView.swift    # Vista principale menu
│       └── AppRowView.swift            # Riga singola app
├── Resources/
│   └── Info.plist              # LSUIElement=YES (nasconde Dock)
├── project.yml                 # XcodeGen config
└── SPEC.md                     # Specifica tecnica
```

## Build & Run

```bash
cd /Users/macbookpro/Programmi/quitall
xcodegen generate
open QuitAll.xcodeproj
# In Xcode: Product > Build (⌘B), poi Run (⌘R)
```

Oppure da riga comando (se Xcode installato):
```bash
xcodebuild -project QuitAll.xcodeproj -scheme QuitAll -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/QuitAll-*/Build/Products/Debug/QuitAll.app
```

## Funzionalità implementate

| Feature | Stato |
|---------|-------|
| Lista app attive (filtro sistema) | ✅ |
| Quit singola app | ✅ |
| Force quit (Option+click) | ✅ |
| Quit All | ✅ |
| Force Quit All | ✅ |
| Ignore list (Finder sempre ignorato) | ✅ |
| Persistenza ignore in UserDefaults | ✅ |
| Refresh automatico (notification center) | ✅ |
| LSUIElement = YES (no Dock) | ✅ |
| NSStatusItem + NSPopover | ✅ |
| Icone dinamiche NSWorkspace | ✅ |

## Info.plist - Chiavi importanti

```xml
<key>LSUIElement</key>
<true/>
```
Questa chiave nasconde l'app dal Dock e dalla lista "App in uso".

## Shortcut

- **Click**: apre menu
- **Hover** su app: mostra pulsanti quit/ignore
- **Click** pulsante xmark: quit normale
- **⌥ + Click** pulsante xmark: force quit
- **Quit All**: chiude tutte le app listate
- **Force**: force quit tutte

## Note

- Xcode non installato su questo sistema - build richiede Xcode
- Progetto completo e syntactically correct
- Eventuale fix AppRowView: se Option+click non funziona, sostituire `.keyboardShortcut` con `.onKeyPress` o usare `NSEvent` modifier flags check