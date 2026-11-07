import Foundation
import AppKit
import UserNotifications
import Combine

final class MemoryPressureManager: ObservableObject {
    static let shared = MemoryPressureManager()

    @Published private(set) var freeMemoryPercentage: Double = 1.0
    @Published private(set) var isWarningActive = false
    @Published private(set) var isCritical = false
    @Published private(set) var freeMemoryGB: Double = 0.0
    @Published private(set) var totalMemoryGB: Double = 0.0
    @Published private(set) var appMemoryUsage: [String: UInt64] = [:]
    @Published private(set) var processMemoryUsage: [pid_t: UInt64] = [:]
    @Published private(set) var processNames: [pid_t: String] = [:]
    @Published private(set) var processIsSystem: [pid_t: Bool] = [:]
    @Published private(set) var processParentPID: [pid_t: pid_t] = [:]

    var usedMemoryGB: Double {
        totalMemoryGB - freeMemoryGB
    }

    private var timer: Timer?
    private var hasPostedWarning = false
    private var hasAutoFreed = false
    private var detailedScan = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        AppSettings.shared.$memoryPressureMonitoringEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        AppSettings.shared.$autoFreeMemoryEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if !enabled {
                    self?.hasAutoFreed = false
                }
            }
            .store(in: &cancellables)

        if AppSettings.shared.memoryPressureMonitoringEnabled {
            startMonitoring()
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            self.freeMemoryPercentage = 1.0
            self.isWarningActive = false
            self.isCritical = false
            self.hasPostedWarning = false
        }
    }

    private let queue = DispatchQueue(label: "closeall.memory", qos: .utility)

    /// Per-process data (names, memory, parents) is only scanned while the popover is open.
    func setDetailedScan(_ enabled: Bool) {
        detailedScan = enabled && AppSettings.shared.memoryPressureMonitoringEnabled
        if detailedScan { refresh() }
    }

    private func refresh() {
        let detailed = detailedScan
        var bundleByPID: [pid_t: String] = [:]
        if detailed {
            for app in NSWorkspace.shared.runningApplications {
                if let id = app.bundleIdentifier { bundleByPID[app.processIdentifier] = id }
            }
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            let (free, freeGB, totalGB) = self.freeMemoryInfo()
            var names: [pid_t: String] = [:]
            var system: [pid_t: Bool] = [:]
            var ppid: [pid_t: pid_t] = [:]
            var perPID: [pid_t: UInt64] = [:]
            var perApp: [String: UInt64] = [:]
            if detailed {
                for s in ProcessScanner.scan(withNames: true) {
                    if !s.name.isEmpty { names[s.pid] = s.name }
                    system[s.pid] = s.isSystem
                    ppid[s.pid] = s.ppid
                    perPID[s.pid] = s.resident
                }
                for (pid, id) in bundleByPID { if let m = perPID[pid] { perApp[id] = m } }
            }
            DispatchQueue.main.async {
                if detailed {
                    self.appMemoryUsage = perApp
                    self.processMemoryUsage = perPID
                    self.processNames = names
                    self.processIsSystem = system
                    self.processParentPID = ppid
                }
                self.publish(free: free, freeGB: freeGB, totalGB: totalGB)
            }
        }
    }

    private func publish(free: Double, freeGB: Double, totalGB: Double) {
        freeMemoryPercentage = free
        freeMemoryGB = freeGB
        totalMemoryGB = totalGB

        let threshold = AppSettings.shared.memoryPressureThreshold
        let wasWarning = isWarningActive
        isWarningActive = free < threshold
        isCritical = free < 0.1

        if isWarningActive && !wasWarning && !hasPostedWarning {
            hasPostedWarning = true
            postWarningNotification()
            if AppSettings.shared.autoFreeMemoryEnabled && !hasAutoFreed {
                hasAutoFreed = true
                performAutoFree()
            }
        }
        if !isWarningActive {
            hasPostedWarning = false
            hasAutoFreed = false
        }
    }

    private func freeMemoryInfo() -> (percentage: Double, freeGB: Double, totalGB: Double) {
        let pageSize = Double(vm_page_size)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (1.0, 0, 0)
        }

        let totalPages = Double(vmStats.active_count + vmStats.inactive_count + vmStats.wire_count + vmStats.free_count + vmStats.compressor_page_count)
        let availablePages = Double(vmStats.free_count + vmStats.inactive_count + vmStats.purgeable_count)

        let totalBytes = totalPages * pageSize
        let freeBytes = availablePages * pageSize

        let percentage = totalPages > 0 ? availablePages / totalPages : 1.0
        let freeGB = freeBytes / 1_073_741_824
        let totalGB = totalBytes / 1_073_741_824

        return (min(percentage, 1.0), freeGB, totalGB)
    }

    func memoryForBundleID(_ bundleID: String) -> UInt64 {
        appMemoryUsage[bundleID] ?? 0
    }

    func memoryForPID(_ pid: pid_t) -> UInt64 {
        processMemoryUsage[pid] ?? 0
    }

    private func postWarningNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = loc("Low Memory Warning")
            content.body = String(
                format: loc("Free memory is at %.0f%% (%.1f GB / %.1f GB)"),
                self.freeMemoryPercentage * 100,
                self.freeMemoryGB,
                self.totalMemoryGB
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "memory-pressure-warning",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    private func performAutoFree() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        var freedCount = 0
        var freedBytes: UInt64 = 0

        let pm = ProcessManager.shared
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  bundleID != ownBundleID,
                  bundleID != AppConstants.BundleIdentifiers.finder,
                  bundleID != frontApp?.bundleIdentifier,
                  !pm.ignoredBundleIdentifiers.contains(bundleID),
                  !pm.autoQuitProtectedBundleIdentifiers.contains(bundleID)
            else { continue }

            freedBytes += ProcessScanner.residentSize(of: app.processIdentifier)

            app.terminate()
            freedCount += 1
        }

        if freedCount > 0 {
            let freedMB = Double(freedBytes) / 1_048_576
            postAutoFreeNotification(count: freedCount, freedMB: freedMB)
        }
    }

    private func postAutoFreeNotification(count: Int, freedMB: Double) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = loc("Memory Auto-Freed")
            content.body = String(
                format: loc("Quit %d app(s), freed %.0f MB of memory"),
                count, freedMB
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "auto-free-memory",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
