import SwiftUI

func loc(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

typealias L = AppConstants.Localizable

enum AppConstants {
    static let popoverWidth: CGFloat     = 340
    static let popoverHeight: CGFloat    = 540
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
    static let quitTimeout: TimeInterval = 5

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
        static let gpuMonitoring        = "CloseAllGPUMonitoringEnabled"
        static let autoFreeMemory       = "CloseAllAutoFreeMemoryEnabled"
        static let autoQuitProtected    = "CloseAllAutoQuitProtected"
    }

    enum BundleIdentifiers {
        static let finder = "com.apple.finder"
    }

    enum Localizable {
        static let appName                = loc("CloseAll")
        static let statusBarSymbol        = "power.circle.fill"
        static let appsLabel              = loc("apps")
        static let selectedLabel          = loc("selected")
        static let selectAll              = loc("Select All")
        static let deselectAll            = loc("Deselect All")
        static let quitSelected           = loc("Quit Selected")
        static let force                  = loc("Force")
        static let searchPlaceholder      = loc("Search apps & processes")
        static let launchAtLogin          = loc("Launch at login")
        static let quitCloseAll           = loc("Quit CloseAll")
        static let ignoreApp              = loc("Ignore app")
        static let unignoreApp            = loc("Unignore app")
        static let quit                   = loc("Quit")
        static let forceQuit              = loc("Force Quit")
        static let quitAll                = loc("Quit All Apps")
        static let minimizeAll            = loc("Minimize All Apps")
        static let settings               = loc("Settings")
        static let keyboardShortcuts      = loc("Keyboard shortcuts")
        static let requireConfirmation    = loc("Require confirmation for Quit All")
        static let hideIcon               = loc("Hide menu bar icon")
        static let memoryWarning          = loc("Memory Warning")
        static let memoryWarningMessage   = loc("Free memory: %.0f%% (%.1f GB / %.1f GB)")
        static let memoryMonitoring       = loc("Memory pressure monitoring")
        static let memoryPressureGood     = loc("Memory: %.0f%% free")
        static let memoryPressureBad      = loc("⚠ Memory: %.0f%% free")
        static let manageIgnored          = loc("Manage ignored apps...")
        static let noIgnoredApps          = loc("No ignored apps")
        static let unignore               = loc("Unignore")
        static let thermalMonitoring       = loc("Thermal state monitoring")
        static let diskMonitoring          = loc("Disk space monitoring")
        static let cpuMonitoring           = loc("CPU monitoring")
        static let autoFreeMemory          = loc("Auto-free memory when low")
        static let diskWarningMessage      = loc("Low disk space: %.1f GB (%.0f%% of %.0f GB)")
        static let thermalWarningMessage   = loc("System thermal state: %@")
        static let cpuWarningMessage       = loc("High CPU usage: %.0f%%")
        static let thermalStateNominal     = loc("Normal")
        static let thermalStateFair        = loc("Fair")
        static let thermalStateSerious     = loc("Serious")
        static let thermalStateCritical    = loc("Critical")
        static let diskPressureGood        = loc("Disk: %.0f%% free")
        static let diskPressureBad         = loc("⚠ Disk: %.0f%% free")
        static let thermalGood             = loc("Thermal: %@")
        static let thermalBad              = loc("⚠ Thermal: %@")
        static let cpuPressureGood         = loc("CPU: %.0f%%")
        static let cpuPressureBad         = loc("⚠ CPU: %.0f%%")
        static let gpuPressureGood         = loc("GPU: %.0f%%")
        static let gpuPressureBad         = loc("⚠ GPU: %.0f%%")
        static let gpuMonitoring           = loc("GPU monitoring")
        static let gpuWarningMessage       = loc("High GPU usage: %.0f%%")
        static let protectFromAutoQuit    = loc("Protect from auto-quit")
        static let unprotectFromAutoQuit  = loc("Remove protection")
        static let settingsGeneral        = loc("General")
        static let settingsMonitors       = loc("Monitors")
        static let settingsAutoFree       = loc("Auto-Free")
        static let cancel                 = loc("Cancel")
        static let back                   = loc("Back")
        static let quitAllMessage         = loc("Quit all %d running apps?")
        static let quitSelectedTitle      = loc("Quit Selected Apps")
        static let quitSelectedMessage    = loc("Quit %d selected apps?")
        static let forceQuitSelectedTitle = loc("Force Quit Selected Apps")
        static let forceQuitSelectedMessage = loc("Force quit %d apps? Unsaved data may be lost.")
        static let forceQuitFailedMessage = loc("Force quit: %@? Unsaved data may be lost.")
        static let failedToQuit           = loc("%d app(s) didn't quit")
        static let dismiss                = loc("Dismiss")
        static let updateAvailable        = loc("v%@ available")
        static let installing             = loc("Installing…")
        static let installAndRestart      = loc("Install & Restart")
        static let download               = loc("Download")
        static let clearSearch            = loc("Clear search")
        static let backgroundProcesses    = loc("Background processes")
        static let nothingToQuit          = loc("Nothing to quit")
        static let noMatch                = loc("No apps matching \"%@\"")
        static let quitting               = loc("Quitting…")
        static let protectedLabel         = loc("Protected from auto-quit")
        static let ignoredLabel           = loc("Ignored")
        static let moreActions            = loc("More actions")
        static let showApp                = loc("Show")
        static let hide                   = loc("Hide")
        static let unhide                 = loc("Unhide")
        static let revealInFinder         = loc("Show in Finder")
        static let expandProcesses        = loc("Show processes")
        static let collapseProcesses      = loc("Hide processes")
        static let terminate              = loc("Terminate")
        static let forceKill              = loc("Force Kill")
        static let memoryDetail           = loc("Memory: %.0f%% free\n%.1f GB free of %.1f GB — used %.1f GB")
        static let diskDetail             = loc("Disk: %.1f GB free of %.1f GB")
        static let hideIconHint           = loc("Reopen CloseAll from Spotlight or Finder to show it again")
        static let memoryThreshold        = loc("Warn when free memory is")
        static let diskThreshold          = loc("Warn when free space is")
        static let autoFreeHint           = loc("Quits background apps on low memory (not protected ones)")
        static let about                  = loc("About")
        static let checkForUpdates        = loc("Check for updates")
        static let checking               = loc("Checking…")
        static let upToDate               = loc("You're up to date")
        static let updateCheckFailed      = loc("Couldn't check for updates")
    }

    static let memoryPressureCheckInterval: TimeInterval = 5.0
    static let defaultMemoryPressureThreshold: Double = 0.20
    static let diskSpaceCheckInterval: TimeInterval = 60.0
    static let defaultDiskSpaceThreshold: Double = 10.0
    static let cpuCheckInterval: TimeInterval = 3.0
    static let gpuCheckInterval: TimeInterval = 3.0
}
