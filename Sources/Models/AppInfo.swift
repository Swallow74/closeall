import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let pid: pid_t
    let icon: NSImage
    let isActive: Bool
    let isHidden: Bool
    let bundleURL: URL?

    init(from runningApp: NSRunningApplication) {
        self.pid = runningApp.processIdentifier
        self.id = runningApp.bundleIdentifier ?? "pid-\(runningApp.processIdentifier)"
        self.name = runningApp.localizedName ?? "Unknown"
        self.bundleIdentifier = runningApp.bundleIdentifier ?? ""
        self.icon = runningApp.icon ?? NSWorkspace.shared.icon(forFile: runningApp.bundleURL?.path ?? "")
        self.isActive = runningApp.isActive
        self.isHidden = runningApp.isHidden
        self.bundleURL = runningApp.bundleURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id && lhs.pid == rhs.pid
    }
}
