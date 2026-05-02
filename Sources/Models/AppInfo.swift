import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let icon: NSImage
    let isActive: Bool
    let bundleURL: URL?

    init(from runningApp: NSRunningApplication) {
        self.id = runningApp.bundleIdentifier ?? UUID().uuidString
        self.name = runningApp.localizedName ?? "Unknown"
        self.bundleIdentifier = runningApp.bundleIdentifier ?? ""

        let iconPath = runningApp.bundleURL?.path ?? ""
        self.icon = NSWorkspace.shared.icon(forFile: iconPath)
        self.icon.size = NSSize(width: 24, height: 24)

        self.isActive = runningApp.isActive
        self.bundleURL = runningApp.bundleURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
    }
}
