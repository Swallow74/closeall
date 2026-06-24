import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let shortcutManager = KeyboardShortcutManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        if (Bundle.main.infoDictionary?["LSUIElement"] as? Bool) != true {
            NSApp.setActivationPolicy(.accessory)
        }

        if let bundleURL = Bundle.main.bundleURL as CFURL? {
            LSRegisterURL(bundleURL, true)
        }

        statusBarController = StatusBarController()
        registerShortcuts()
        UpdateChecker.shared.checkForUpdates()

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

    private func registerShortcuts() {
        let quitAllKey: UInt16 = 0x0A
        let minimizeAllKey: UInt16 = 0x3E
        let modifiers: NSEvent.ModifierFlags = [.control, .option, .command]

        shortcutManager.register("quitAll", keyCode: quitAllKey, modifiers: modifiers)
        shortcutManager.setAction("quitAll") { [weak self] in
            _ = self?.performQuitAll()
        }

        shortcutManager.register("minimizeAll", keyCode: minimizeAllKey, modifiers: modifiers)
        shortcutManager.setAction("minimizeAll") { [weak self] in
            ProcessManager.shared.minimizeAllApps()
        }

        if !AppSettings.shared.keyboardShortcutsEnabled {
            shortcutManager.disableAll()
        }
    }

    private func performQuitAll() {
        let settings = AppSettings.shared
        if settings.requireQuitConfirmation {
            showQuitAllConfirmation()
        } else {
            ProcessManager.shared.quitAllApps()
        }
    }

    private func showQuitAllConfirmation() {
        let alert = NSAlert()
        alert.messageText = AppConstants.Localizable.quitAll
        alert.informativeText = String(format: AppConstants.AlertMessages.quitAllMessage, ProcessManager.shared.runningApps.count)
        alert.addButton(withTitle: AppConstants.Localizable.quitAll)
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ProcessManager.shared.quitAllApps()
        }
    }

    @objc private func handleSettingsChanged() {
        let enabled = AppSettings.shared.keyboardShortcutsEnabled
        if enabled {
            registerShortcuts()
        } else {
            shortcutManager.disableAll()
        }

        statusBarController?.updateVisibility()
    }
}
