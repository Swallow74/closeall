import Foundation
import AppKit
import ServiceManagement

/// Launch at login through SMAppService (macOS 13+); older systems open the Login Items pane.
enum LoginItemsManager {
    static var isRegistered: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.launchAtLogin)
    }

    /// Returns the state actually applied.
    @discardableResult
    static func setRegistered(_ registered: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if registered { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("CloseAll: login item error: \(error.localizedDescription)")
            }
            let actual = isRegistered
            UserDefaults.standard.set(actual, forKey: AppConstants.UserDefaultsKeys.launchAtLogin)
            return actual
        }
        UserDefaults.standard.set(registered, forKey: AppConstants.UserDefaultsKeys.launchAtLogin)
        if registered, let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        return registered
    }
}
