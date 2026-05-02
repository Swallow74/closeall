import SwiftUI

enum AppConstants {
    static let popoverWidth: CGFloat     = 320
    static let popoverHeight: CGFloat    = 400
    static let headerPaddingH: CGFloat   = 16
    static let headerPaddingV: CGFloat   = 12
    static let footerPaddingH: CGFloat   = 16
    static let footerPaddingV: CGFloat   = 12
    static let rowPaddingH: CGFloat      = 12
    static let rowPaddingV: CGFloat      = 6
    static let listPaddingH: CGFloat     = 8
    static let listPaddingV: CGFloat     = 4
    static let iconSize: CGFloat         = 24
    static let cornerRadius: CGFloat     = 6
    static let quitRefreshDelay: Double   = 0.5
    static let batchQuitRefreshDelay: Double = 1.5

    enum UserDefaultsKeys {
        static let ignoredApps      = "CloseAllIgnoredApps"
        static let launchAtLogin    = "CloseAllLaunchAtLogin"
    }

    enum BundleIdentifiers {
        static let finder = "com.apple.finder"
    }

    enum AlertMessages {
        static let quitSelectedTitle       = "Quit Selected Apps"
        static let quitSelectedMessage     = "Are you sure you want to quit %d selected apps?"
        static let forceQuitSelectedTitle  = "Force Quit Selected Apps"
        static let forceQuitSelectedMessage = "Force quit %d apps? Data may be lost."
    }

    enum Localizable {
        static let appName            = "CloseAll"
        static let statusBarSymbol    = "power.circle.fill"
        static let appsLabel          = "apps"
        static let apps               = "apps"
        static let selectedLabel      = "selezionate"
        static let selectAll          = "Select All"
        static let deselectAll        = "Deselect All"
        static let quitSelected       = "Quit Selected"
        static let force              = "Force"
        static let searchPlaceholder  = "Search apps..."
        static let launchAtLogin      = "Launch at login"
        static let quitCloseAll        = "Quit CloseAll"
        static let ignoreApp          = "Ignore app"
        static let unignoreApp        = "Unignore app"
        static let quit               = "Quit"
        static let forceQuit          = "Force Quit"
    }
}
