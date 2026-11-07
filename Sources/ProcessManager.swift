import Foundation
import AppKit
import Combine

final class ProcessManager: ObservableObject {
    static let shared = ProcessManager()

    @Published private(set) var runningApps: [AppInfo] = []
    @Published private(set) var quittingAppIds: Set<String> = []
    @Published var ignoredBundleIdentifiers: Set<String> = []
    @Published var autoQuitProtectedBundleIdentifiers: Set<String> = []
    @Published var selectedAppIds: Set<String> = []
    @Published private(set) var failedApps: [AppInfo] = []

    private var workspaceObservers: [NSObjectProtocol] = []
    private var refreshWorkItem: DispatchWorkItem?

    private init() {
        loadIgnoredApps()
        loadAutoQuitProtected()
        refreshRunningApps()
        setupWorkspaceObservers()
    }

    deinit {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        refreshWorkItem?.cancel()
    }

    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter

        let launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.debounceRefresh()
        }

        let terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.debounceRefresh()
        }

        workspaceObservers.append(launchObserver)
        workspaceObservers.append(terminateObserver)
    }

    private func debounceRefresh() {
        refreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshRunningApps()
        }
        refreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func refreshRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
        let ownBundleId = Bundle.main.bundleIdentifier ?? ""

        runningApps = apps
            .filter { app in
                app.activationPolicy == .regular &&
                app.bundleIdentifier != ownBundleId &&
                !ignoredBundleIdentifiers.contains(app.bundleIdentifier ?? "")
            }
            .map { AppInfo(from: $0) }
            .sorted {
                if $0.isActive != $1.isActive {
                    return $0.isActive && !$1.isActive
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        selectedAppIds = selectedAppIds.filter { id in
            runningApps.contains { $0.id == id }
        }

        let liveIDs = Set(runningApps.map { $0.id })
        quittingAppIds = quittingAppIds.intersection(liveIDs)
        failedApps = failedApps.filter { f in runningApps.contains { $0.id == f.id && $0.pid == f.pid } }
    }

    var selectedApps: [AppInfo] {
        runningApps.filter { selectedAppIds.contains($0.id) }
    }

    var allSelected: Bool {
        !runningApps.isEmpty && selectedAppIds.count == runningApps.count
    }

    func toggleSelection(_ appId: String) {
        if selectedAppIds.contains(appId) {
            selectedAppIds.remove(appId)
        } else {
            selectedAppIds.insert(appId)
        }
    }

    func selectAll() {
        selectedAppIds = Set(runningApps.map { $0.id })
    }

    func deselectAll() {
        selectedAppIds.removeAll()
    }

    // MARK: - Quit

    func quitSelectedApps(force: Bool = false) {
        quit(selectedApps, force: force)
    }

    func quitApp(_ appInfo: AppInfo, force: Bool = false) {
        quit([appInfo], force: force)
    }

    func quitAllApps(force: Bool = false) {
        quit(runningApps, force: force)
    }

    func retryFailedWithForce() {
        let apps = failedApps
        failedApps = []
        quit(apps, force: true)
    }

    func dismissFailures() {
        failedApps = []
    }

    /// Non-blocking: asks all apps to quit at once, then polls until they are gone or time runs out.
    private func quit(_ infos: [AppInfo], force: Bool) {
        let targets: [(AppInfo, NSRunningApplication)] = infos.compactMap { info in
            guard let app = NSRunningApplication(processIdentifier: info.pid), !app.isTerminated else { return nil }
            return (info, app)
        }
        guard !targets.isEmpty else { return }

        failedApps.removeAll { f in targets.contains { $0.0.id == f.id } }
        for (info, app) in targets {
            quittingAppIds.insert(info.id)
            if force { app.forceTerminate() } else { app.terminate() }
        }

        let deadline = Date().addingTimeInterval(force ? 3 : AppConstants.quitTimeout)
        func poll() {
            let pending = targets.filter { !$0.1.isTerminated }
            if pending.isEmpty || Date() >= deadline {
                for (info, _) in targets { quittingAppIds.remove(info.id) }
                for (info, _) in pending where !failedApps.contains(where: { $0.id == info.id }) {
                    failedApps.append(info)
                }
                refreshRunningApps()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: poll)
        }
        poll()
    }

    // MARK: - Per-app actions

    func activate(_ appInfo: AppInfo) {
        NSRunningApplication(processIdentifier: appInfo.pid)?.activate(options: [.activateIgnoringOtherApps])
    }

    func toggleHidden(_ appInfo: AppInfo) {
        guard let app = NSRunningApplication(processIdentifier: appInfo.pid) else { return }
        if app.isHidden { app.unhide() } else { app.hide() }
        refreshRunningApps()
    }

    func revealInFinder(_ appInfo: AppInfo) {
        guard let url = appInfo.bundleURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func minimizeAllApps() {
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular &&
               app.bundleIdentifier != (Bundle.main.bundleIdentifier ?? "") &&
               !ignoredBundleIdentifiers.contains(app.bundleIdentifier ?? "") {
                app.hide()
            }
        }
    }

    func minimizeSelectedApps() {
        for appInfo in selectedApps {
            NSRunningApplication(processIdentifier: appInfo.pid)?.hide()
        }
    }

    func addToIgnored(_ bundleIdentifier: String) {
        ignoredBundleIdentifiers.insert(bundleIdentifier)
        saveIgnoredApps()
        refreshRunningApps()
    }

    func removeFromIgnored(_ bundleIdentifier: String) {
        ignoredBundleIdentifiers.remove(bundleIdentifier)
        saveIgnoredApps()
        refreshRunningApps()
    }

    func toggleIgnored(_ bundleIdentifier: String) {
        if ignoredBundleIdentifiers.contains(bundleIdentifier) {
            removeFromIgnored(bundleIdentifier)
        } else {
            addToIgnored(bundleIdentifier)
        }
    }

    func isQuitting(_ appId: String) -> Bool {
        quittingAppIds.contains(appId)
    }

    private func loadIgnoredApps() {
        if let saved = UserDefaults.standard.stringArray(forKey: AppConstants.UserDefaultsKeys.ignoredApps) {
            ignoredBundleIdentifiers = Set(saved)
        }
        ignoredBundleIdentifiers.insert(AppConstants.BundleIdentifiers.finder)
    }

    private func saveIgnoredApps() {
        UserDefaults.standard.set(Array(ignoredBundleIdentifiers), forKey: AppConstants.UserDefaultsKeys.ignoredApps)
    }

    func toggleAutoQuitProtection(_ bundleIdentifier: String) {
        if autoQuitProtectedBundleIdentifiers.contains(bundleIdentifier) {
            autoQuitProtectedBundleIdentifiers.remove(bundleIdentifier)
        } else {
            autoQuitProtectedBundleIdentifiers.insert(bundleIdentifier)
        }
        saveAutoQuitProtected()
    }

    func isAutoQuitProtected(_ bundleIdentifier: String) -> Bool {
        autoQuitProtectedBundleIdentifiers.contains(bundleIdentifier)
    }

    private func loadAutoQuitProtected() {
        if let saved = UserDefaults.standard.stringArray(forKey: AppConstants.UserDefaultsKeys.autoQuitProtected) {
            autoQuitProtectedBundleIdentifiers = Set(saved)
        }
    }

    private func saveAutoQuitProtected() {
        UserDefaults.standard.set(Array(autoQuitProtectedBundleIdentifiers), forKey: AppConstants.UserDefaultsKeys.autoQuitProtected)
    }

    func ignoredAppNames() -> [(bundleID: String, name: String)] {
        ignoredBundleIdentifiers
            .filter { $0 != AppConstants.BundleIdentifiers.finder }
            .compactMap { bundleID in
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    let name = FileManager.default.displayName(atPath: url.path)
                    return (bundleID, (name as NSString).deletingPathExtension)
                }
                return (bundleID, bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
