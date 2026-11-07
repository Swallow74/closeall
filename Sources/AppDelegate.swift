import AppKit
import SwiftUI
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let shortcutManager = KeyboardShortcutManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        if (Bundle.main.infoDictionary?["LSUIElement"] as? Bool) != true {
            NSApp.setActivationPolicy(.accessory)
        }

        statusBarController = StatusBarController()
        syncShortcuts()
        UpdateChecker.shared.checkForUpdates()

        if #available(macOS 13.0, *) {
            UserDefaults.standard.set(LoginItemsManager.isRegistered, forKey: AppConstants.UserDefaultsKeys.launchAtLogin)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager.unregisterAll()
        statusBarController = nil
    }

    /// Relaunching the app (Spotlight, Finder) opens the popover: the way back in when the icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.revealPopover()
        return false
    }

    private func syncShortcuts() {
        guard AppSettings.shared.keyboardShortcutsEnabled else {
            shortcutManager.unregisterAll()
            return
        }
        let mods = UInt32(controlKey | optionKey | cmdKey)
        shortcutManager.register("quitAll", keyCode: UInt32(kVK_ANSI_Q), carbonModifiers: mods) {
            QuitAllCoordinator.requestQuitAll()
        }
        shortcutManager.register("minimizeAll", keyCode: UInt32(kVK_ANSI_M), carbonModifiers: mods) {
            ProcessManager.shared.minimizeAllApps()
        }
    }

    @objc private func handleSettingsChanged() {
        syncShortcuts()
        statusBarController?.updateVisibility()
    }
}

/// Single entry point for "Quit All" (button, menu, hotkey): honours the confirmation setting.
enum QuitAllCoordinator {
    static func requestQuitAll() {
        let pm = ProcessManager.shared
        guard !pm.runningApps.isEmpty else { return }
        guard AppSettings.shared.requireQuitConfirmation else {
            pm.quitAllApps()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L.quitAll
        alert.informativeText = String(format: L.quitAllMessage, pm.runningApps.count)
        alert.addButton(withTitle: L.quitAll)
        alert.addButton(withTitle: L.cancel)
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            pm.quitAllApps()
        }
    }
}
