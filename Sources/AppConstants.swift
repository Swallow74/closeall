import SwiftUI

enum AppConstants {
    static let popoverWidth: CGFloat     = 320
    static let popoverHeight: CGFloat    = 500
    static let headerPaddingH: CGFloat   = 16
    static let headerPaddingV: CGFloat   = 12
    static let footerPaddingH: CGFloat   = 16
    static let footerPaddingV: CGFloat   = 12
    static let rowPaddingH: CGFloat      = 12
    static let rowPaddingV: CGFloat      = 6
    static let listPaddingH: CGFloat     = 8
    static let listPaddingV: CGFloat     = 8
    static let iconSize: CGFloat         = 24
    static let cornerRadius: CGFloat     = 6
    static let quitRefreshDelay: Double   = 0.5
    static let batchQuitRefreshDelay: Double = 1.5

    enum UserDefaultsKeys {
        static let ignoredApps           = "CloseAllIgnoredApps"
        static let launchAtLogin         = "CloseAllLaunchAtLogin"
        static let keyboardShortcuts     = "CloseAllKeyboardShortcutsEnabled"
        static let requireConfirmation   = "CloseAllRequireQuitConfirmation"
        static let hideMenuBarIcon       = "CloseAllHideMenuBarIcon"
        static let memoryPressure       = "CloseAllMemoryPressureMonitoringEnabled"
        static let memoryPressureThreshold = "CloseAllMemoryPressureThreshold"
        static let thermalState         = "CloseAllThermalStateMonitoringEnabled"
        static let diskSpace            = "CloseAllDiskSpaceMonitoringEnabled"
        static let diskSpaceThreshold   = "CloseAllDiskSpaceThreshold"
        static let cpuMonitoring        = "CloseAllCPUMonitoringEnabled"
        static let autoFreeMemory       = "CloseAllAutoFreeMemoryEnabled"
    }

    enum BundleIdentifiers {
        static let finder = "com.apple.finder"
    }

    enum AlertMessages {
        static let quitSelectedTitle       = "Quit Selected Apps"
        static let quitSelectedMessage     = "Are you sure you want to quit %d selected apps?"
        static let forceQuitSelectedTitle  = "Force Quit Selected Apps"
        static let forceQuitSelectedMessage = "Force quit %d apps? Data may be lost."
        static let quitAllTitle            = "Quit All Apps"
        static let quitAllMessage          = "Are you sure you want to quit all %d running apps?"
    }

    enum Localizable {
        static let appName                = "CloseAll"
        static let statusBarSymbol        = "power.circle.fill"
        static let appsLabel              = "apps"
        static let selectedLabel          = "selected"
        static let selectAll              = "Select All"
        static let deselectAll            = "Deselect All"
        static let quitSelected           = "Quit Selected"
        static let force                  = "Force"
        static let searchPlaceholder      = "Search apps..."
        static let launchAtLogin          = "Launch at login"
        static let quitCloseAll           = "Quit CloseAll"
        static let ignoreApp              = "Ignore app"
        static let unignoreApp            = "Unignore app"
        static let quit                   = "Quit"
        static let forceQuit              = "Force Quit"
        static let quitAll                = "Quit All Apps"
        static let minimizeAll            = "Minimize All Apps"
        static let settings               = "Settings"
        static let keyboardShortcuts      = "Keyboard shortcuts"
        static let requireConfirmation    = "Require confirmation for Quit All"
        static let hideIcon               = "Hide menu bar icon"
        static let memoryWarning          = "Memory Warning"
        static let memoryWarningMessage   = "Free memory: %.0f%% (%.1f GB / %.1f GB)"
        static let memoryMonitoring       = "Memory pressure monitoring"
        static let memoryPressureGood     = "Memory: %.0f%% free"
        static let memoryPressureBad      = "⚠ Memory: %.0f%% free"
        static let manageIgnored          = "Manage ignored apps..."
        static let noIgnoredApps          = "No ignored apps"
        static let unignore               = "Unignore"
        static let thermalMonitoring       = "Thermal state monitoring"
        static let diskMonitoring          = "Disk space monitoring"
        static let cpuMonitoring           = "CPU monitoring"
        static let autoFreeMemory          = "Auto-free memory when low"
        static let diskWarningMessage      = "Low disk space: %.1f GB (%.0f%% of %.0f GB)"
        static let thermalWarningMessage   = "System thermal state: %@"
        static let cpuWarningMessage       = "High CPU usage: %.0f%%"
        static let thermalStateNominal     = "Normal"
        static let thermalStateFair        = "Fair"
        static let thermalStateSerious     = "Serious"
        static let thermalStateCritical    = "Critical"
        static let diskPressureGood        = "Disk: %.0f%% free"
        static let diskPressureBad         = "⚠ Disk: %.0f%% free"
        static let thermalGood             = "Thermal: %@"
        static let thermalBad              = "⚠ Thermal: %@"
        static let cpuPressureGood         = "CPU: %.0f%%"
        static let cpuPressureBad          = "⚠ CPU: %.0f%%"
    }

    static let memoryPressureCheckInterval: TimeInterval = 5.0
    static let defaultMemoryPressureThreshold: Double = 0.20
    static let diskSpaceCheckInterval: TimeInterval = 60.0
    static let defaultDiskSpaceThreshold: Double = 10.0
    static let cpuCheckInterval: TimeInterval = 3.0

    struct Shortcuts {
        static let quitAll = KeyCombo(key: 0x0A, modifierFlags: [.control, .option, .command])
        static let minimizeAll = KeyCombo(key: 0x3E, modifierFlags: [.control, .option, .command])
    }

    struct KeyCombo {
        let key: UInt32
        let modifierFlags: NSEvent.ModifierFlags

        var carbonFlags: UInt32 {
            var flags: UInt32 = 0
            if modifierFlags.contains(.command) { flags |= 0x00000080 }
            if modifierFlags.contains(.option) { flags |= 0x00000010 }
            if modifierFlags.contains(.control) { flags |= 0x00000004 }
            if modifierFlags.contains(.shift) { flags |= 0x00000020 }
            return flags
        }

        static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
            lhs.key == rhs.key && lhs.modifierFlags == rhs.modifierFlags
        }
    }
}
