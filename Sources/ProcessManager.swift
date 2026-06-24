import Foundation
import AppKit
import Combine

final class ProcessManager: ObservableObject {
    static let shared = ProcessManager()

    @Published private(set) var runningApps: [AppInfo] = []
    @Published private(set) var quittingAppIds: Set<String> = []
    @Published var ignoredBundleIdentifiers: Set<String> = []
    @Published var selectedAppIds: Set<String> = []

    private var workspaceObservers: [NSObjectProtocol] = []
    private var refreshWorkItem: DispatchWorkItem?

    private init() {
        loadIgnoredApps()
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

        quittingAppIds.removeAll()
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

    @discardableResult
    func quitSelectedApps(force: Bool = false) -> [QuitError] {
        var errors: [QuitError] = []

        for appInfo in selectedApps {
            if let error = quitApp(appInfo, force: force) {
                errors.append(error)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.batchQuitRefreshDelay) { [weak self] in
            self?.refreshRunningApps()
        }

        return errors
    }

    @discardableResult
    func quitApp(_ appInfo: AppInfo, force: Bool = false) -> QuitError? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == appInfo.bundleIdentifier && $0.responds(to: #selector(NSRunningApplication.terminate))
        }) else { return nil }

 quittingAppIds.insert(appInfo.id)

        var quitSucceeded = false
        let expectation = DispatchSemaphore(value: 0)

        let observer = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let terminated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               terminated.processIdentifier == app.processIdentifier {
                quitSucceeded = true
                expectation.signal()
            }
        }

        if force {
            app.forceTerminate()
        } else {
            app.terminate()
        }

        let timeout = expectation.wait(timeout: .now() + 2.0)
        NotificationCenter.default.removeObserver(observer)

        quittingAppIds.remove(appInfo.id)

        if timeout == .timedOut && !quitSucceeded {
            return QuitError(appName: appInfo.name, wasForce: force)
        }

        return nil
    }

    func quitAllApps() -> [QuitError] {
        var errors: [QuitError] = []
        let snapshot = runningApps

        for appInfo in snapshot {
            if let error = quitApp(appInfo, force: false) {
                errors.append(error)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.batchQuitRefreshDelay) { [weak self] in
            self?.refreshRunningApps()
        }

        return errors
    }

    func forceQuitAllApps() -> [QuitError] {
        var errors: [QuitError] = []
        let snapshot = runningApps

        for appInfo in snapshot {
            if let error = quitApp(appInfo, force: true) {
                errors.append(error)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.batchQuitRefreshDelay) { [weak self] in
            self?.refreshRunningApps()
        }

        return errors
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
            if let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == appInfo.bundleIdentifier
            }) {
                app.hide()
            }
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

struct QuitError: Identifiable {
    let id = UUID()
    let appName: String
    let wasForce: Bool

    var message: String {
        if wasForce {
            return "Failed to force quit \(appName)"
        } else {
            return "Failed to quit \(appName) — try force quit"
        }
    }
}
